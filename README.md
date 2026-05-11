# AWACS Secure Data Consolidation — Lab Workstations

This repo is an end-to-end AI-assisted infrastructure project demonstrating structured multi-agent design, test-first IaC discipline, and real Azure production deployment — with honest incident documentation of what broke and how it was fixed. The technical artifact is a secure backup system for shared lab workstations. The engineering story is how a multi-agent AI workflow designed, built, deployed, and operated it.

**Status:** Live in production since 2026-04-30. A lab workstation pushes files every 30 minutes. SAS token rotates automatically every 6 days via Azure Automation Account — running without manual intervention since 2026-05-09. 97+ blobs in immutable storage and counting. See `docs/deployment-timeline.md` for the forensic record (Azure Activity Log + git + push ledger).

**Evaluating fit for an AI engineering role?** See [`docs/evaluator-guide.md`](./docs/evaluator-guide.md) — a structured prompt and reading path that gets you a substantive answer in 5 minutes.

---

## How this was built

### The methodology

The AWACS multi-agent methodology uses four defined agent roles — 🏗️ Architect, 🛡️ Security Engineer, 🔧 Operator, 📚 Documentarian — each reviewing design decisions from their domain. Claude Code sessions operate with a structured system prompt that activates all four voices. Disagreements are surfaced explicitly and captured in `docs/cross-agent-reviews/` rather than resolved into consensus prose. Every non-obvious architectural choice has a decision record in `docs/decisions/` with alternatives considered, trade-offs accepted, and agents who signed off. See `CLAUDE.md` for the full methodology specification.

### The 31-hour autonomous build

Stages 1–5 (threat model → architecture → test battery → 8-component IaC → deploy/verify/teardown scripts + workstation bootstrap) ran autonomously over 31+ hours in a single Claude Code session on 2026-04-30. No stage gate was skipped without explicit user authorization.

One concrete example of how agent disagreement shaped the design: when the SAS rotation component (component 08) was planned, the Architect proposed Azure Functions (Consumption plan) as the runtime. The Security Engineer reviewed the MSI trust model; the Operator flagged the quota dependency. At deploy time, the Consumption plan hit a Dynamic VM quota of 0 on a personal Azure subscription — the runtime container provisioned but could not start. The pivot to Azure Automation Account (same MSI model, no quota requirement, Free SKU at $0/month) happened in the same session. ADR-008 captures both the quota failure and the rationale for the pivot, with all four agent positions documented. See `docs/decisions/ADR-008-sas-rotation-automation.md`.

### Where human judgment was required

Three moments where human intervention corrected the AI system — each documented in real time in `daily-captures/`:

1. **SAS expiry (2026-05-01):** The automated system had no alerting for token expiry. The push script exited 0 even when all blob writes returned HTTP 403. The failure was undetectable from Task Scheduler's "Last Run Result" field. Human operator detected it 6 days 17 hours later via session memory, not monitoring. This failure motivated component 08.

2. **Norton TLS interception (2026-05-08):** Azure CLI was failing with SSL certificate errors. The AI correctly diagnosed two separate trust stores (Windows Certificate Store vs. Python's certifi bundle) — but resolving it required a human operator to navigate the antivirus UI and add Azure domains to the SSL scanning exclusion list. The diagnostic commands are preserved in `workstation/troubleshooting.md §10`.

3. **IaC-Reality Inversion (2026-05-09):** A brutal critic audit found ADR-008 had its Decision and Alternatives sections inverted — it documented Azure Functions as chosen and Automation Account as rejected, the exact inverse of what was deployed. The AI had documented the plan, not the pivot. Human review caught and corrected it. The pattern is now a named anti-pattern in `daily-captures/AWACS_daily-capture_2026-05-09_iac-reality-inversion-pattern.md`.

### Deployment evidence

`docs/deployment-timeline.md` is sourced from Azure Activity Log events, git commit timestamps, and the workstation push ledger — independently verifiable, not self-reported. It shows three full deploy/teardown/redeploy cycles, the 2026-05-01 SAS expiry incident, and the Automation Account deployment that automated rotation. The first scheduled rotation fired 2026-05-09; the system has operated without manual intervention since.

---

## What this is

Shared lab workstations have generic logins, are not domain-joined, and are assumed hostile (anything on disk is lift-able). Traditional backup products don't fit. This repo is the design and implementation of a **push-from-workstation, immutable-at-destination, write-only-credential** alternative.

The solution:

1. Lab PC pushes files on a 30-minute schedule
2. Files land in Azure Blob Storage with time-based immutability (90 days default)
3. Authentication is layered: cert-based Service Principal → Key Vault → automatically rotated SAS → write-only RBAC
4. Consumers (analysts) read from their own desks via separate RBAC, never touching the lab PC

A 30-second story: ["The cleverest part of this design is that it doesn't use a backup product at all."](./AWACS_design_air-gapped-lab-backup_2026-04-28.md)

---

## Quick start

### Prerequisites

- Azure subscription (Owner or Contributor + User Access Administrator)
- Azure CLI ≥2.50.0 with Bicep ≥0.20.0
- PowerShell 5.1+
- An Entra ID security group whose members will read backups (capture the group's Object ID)

### Deploy

**Command:**
```
./deploy/Deploy.ps1 -SubscriptionId <sub> -Region eastus2 -Prefix awacslab -ConsumerGroupObjectId <group-oid> -AlertEmail ops@example.com
```
**What it does:** preflight → create RG → create SP+cert → deploy Bicep (storage, KV, LA, immutability, RBAC, Automation Account) → upload runbook + link schedule → seed initial SAS → emit workstation config + cert.
**Expected output:** "DEPLOY COMPLETE" banner with paths to `./out/<prefix>-sp-cert-*.pem` and `./out/<prefix>-workstation-config.json` and a clickable Azure portal URL.

### Bootstrap each lab PC

On each lab PC, signed in as the dedicated service account:

**Command:**
```
./workstation/bootstrap.ps1 -ConfigPath ./awacslab-workstation-config.json -CertPath ./awacslab-sp-cert.pfx -CertPassword (Read-Host -AsSecureString)
```
**What it does:** installs pinned Az modules, imports cert non-exportably, copies push-files.ps1, registers the scheduled task.
**Expected output:** "Bootstrap complete." Test with `powershell.exe -File C:\ProgramData\AwacsBackup\push-files.ps1`.

### Verify

**Command:** `./deploy/verify.ps1 -ResourceGroup awacslab-rg -Prefix awacslab`
**What it does:** runs the executable test battery against the live deployment.
**Expected output:** all tests PASS.

### Teardown

**Command:** `./deploy/teardown.ps1 -SubscriptionId <sub> -Prefix awacslab`
**What it does:** removes RBAC, SP, locks, RG (refuses if immutability is locked).
**Expected output:** "Teardown complete."

---

## Repository map

```
.
├── README.md                  ← this file
├── CLAUDE.md                  ← AWACS methodology (read for context)
├── GLOSSARY.md                ← project-specific terms
├── RUNBOOK.md                 ← day-2 operations
├── threat-model.md            ← Stage 1 artifact; read first
├── architecture/              ← Stage 2: 5 mermaid diagrams + README
├── components/                ← Stage 4: the 8 Atomic Legos
│   ├── 01-storage-account/
│   ├── 02-key-vault/
│   ├── 03-service-principal-auth/
│   ├── 04-immutability-policy/
│   ├── 05-log-analytics/
│   ├── 06-rbac-consumer-access/
│   ├── 07-workstation-push-script/
│   └── 08-sas-rotator/
├── workstation/               ← workstation-side scripts + docs
├── deploy/                    ← preflight, deploy, verify, teardown
├── tests/                     ← Stage 3: test battery (specs + scripts)
├── daily-captures/            ← session-by-session methodology and content captures
│                                 showing real-time decisions, failure modes, and reasoning
│                                 as the system was built. Evidence of the process, not just
│                                 the output.
└── docs/
    ├── deployment-timeline.md ← forensic record: git + Azure Activity Log + push ledger
    ├── evaluator-guide.md     ← structured evaluation prompt for AI engineering role fit
    ├── decisions/             ← ADRs
    ├── cross-agent-reviews/   ← CAR-001 final Stage 5 sign-off; capture future disagreements here
    └── session-notes/         ← per-Claude-Code-session notes
```

---

## Threat model summary

The full threat model is in `threat-model.md`. Six actors are modeled:

| Actor | Defense |
|-------|---------|
| T1 Insider analyst | Cert in service-account profile, write-only RBAC |
| T2 Lifted credential | SAS rotates every 6 days (automated), write-only, immutable destination |
| T3 Compromised workstation | Audit trail in separate trust zone, can't tamper |
| T4 Rogue local admin | Detection: 25h staleness alert from cloud side |
| T5 Network MITM | TLS 1.2+ enforced, cert-based assertion (no plaintext secret) |
| T6 Curious consumer | Read-only RBAC, immutable retention |

---

## Compliance posture

Default deployment satisfies CIS Azure Foundations Benchmark v5.0 controls 3.1, 3.7, 3.13, 3.14, 5.1, and 7.1. See `tests/05-compliance.md` for tests; ADR-000 for upgrade path to GxP / 21 CFR Part 11.

---

## Cost ownership

The resource group lives in the deployer's subscription. Storage costs scale with data volume × retention × replication. Default sku is `Standard_GRS`; downgrade to `Standard_LRS` for cost-sensitive deploys (see component 01 README).

---

## Known gaps (v2 backlog)

This is a v1 design for a specific scenario. The following are acknowledged gaps, not blockers — the system is in production and operating correctly without them.

1. **Mode B cert distribution (external PKI) is documented but not coded.** Deploy.ps1 implements Mode A (self-signed cert generated at deploy time). Mode B (operator-supplied cert from internal PKI) is the hardened path documented in ADR-003.
2. **Network egress hardening optional.** Default deploy leaves storage + KV public-network-accessible. Private Endpoint is documented in component READMEs as a future hardening step.
3. **Single-region.** No geo-redundant active-active. `Standard_GRS` provides Microsoft-side replication for Storage; KV soft-delete + purge protection covers KV recovery.
4. **No Linux lab workstation support.** PowerShell-only push (ADR-002). Adding a `push-files.py` parallel to the .ps1 would not change the cloud side.
5. **Executable test coverage is partial.** 20 of the ~52 tests in the battery have runnable PowerShell counterparts in `tests/scripts/`. The full battery is specified; high-value missing scripts include end-to-end push (`I3_1`), staleness alert (`F4_1`), and workstation bootstrap (`W7_*`). See `tests/scripts/README.md`.

The initial v1 deploy used a short-lived SAS token and did not include automated rotation. The token expired on 2026-05-01 and pushes silently failed for 6 days 17 hours — diagnosed via session memory, not monitoring. On 2026-05-08 an Azure Automation Account was deployed with a scheduled PowerShell runbook (component 08). The first automated rotation fired 2026-05-09. The system has run without manual SAS intervention since. See ADR-008 and `docs/deployment-timeline.md` Phase 6.

Not designed as a general-purpose backup product. Forks welcome.

---

## License

See `LICENSE`.
