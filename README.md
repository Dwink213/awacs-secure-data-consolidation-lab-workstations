# AWACS Secure Data Consolidation — Lab Workstations

A turnkey, deployable solution for backing up files from shared lab workstations to immutable Azure storage, with built-in compliance and governance.

**Status:** Deployed and running in production since 2026-04-30. 97+ blobs pushed and counting. See `docs/deployment-timeline.md` for the forensic deployment record (git + Azure Activity Log + push ledger). Built using AWACS multi-agent methodology (🏗️ Architect, 🛡️ Security Engineer, 🔧 Operator, 📚 Documentarian). See `CLAUDE.md` for the methodology.

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

## Limitations honestly named

This is a v1 design. The Operator and Security Engineer agents flagged the following gaps for v2:

1. **SAS rotation is automated** via Azure Automation Account (component 08). The Automation Account's MSI rotates `current-write-sas` every 6 days — 1 day before the Azure-enforced 7-day cap. No operator action required under normal operation. Manual fallback documented in `RUNBOOK.md`.
2. **Mode B cert distribution (external PKI) is documented but not coded.** Deploy.ps1 currently implements Mode A only.
3. **Network egress hardening optional.** Default deploy leaves storage + KV public-network-accessible. Private Endpoint is documented in component READMEs as a future hardening.
4. **Single-region.** No geo-redundant active-active. `Standard_GRS` provides Microsoft-side replication for Storage; KV soft-delete + purge protection covers KV recovery.
5. **No Linux lab workstation support.** PowerShell-only push (ADR-002). Adding a `push-files.py` parallel to the .ps1 would not change the cloud side.
6. **Executable test coverage is partial.** 20 of the ~52 tests in the battery have runnable PowerShell counterparts in `tests/scripts/`. High-value missing scripts: end-to-end push test (`I3_1`), staleness alert check (`F4_1`), and workstation bootstrap tests (`W7_*`). See `tests/scripts/README.md` for the honest gap list.

The initial v1 deploy seeded a 24-hour SAS token but did not include automated rotation. The token expired on 2026-05-01 and pushes silently failed for 6 days 17 hours before rotation was performed manually on 2026-05-08. A subsequent autonomous Claude Code session deployed an Azure Automation Account with a scheduled PowerShell runbook; the first scheduled rotation fired on 2026-05-09 without intervention. See ADR-008 and `docs/deployment-timeline.md` Phase 6.

This is a v1 implementation for a specific scenario. Not designed as a general-purpose backup product. Forks welcome.

---

## How this was built

This repo was built using the AWACS multi-agent methodology — four named agents (Architect, Security Engineer, Operator, Documentarian) review every significant decision, with disagreements surfaced explicitly rather than flattened into consensus. See `CLAUDE.md` for the methodology. Per-session notes in `docs/session-notes/` show the agents working in real time.

The system is live: `docs/deployment-timeline.md` is a forensic record of the deployment — every Azure Activity Log event, every git commit, and every workstation push from repository creation to production operation, with real timestamps sourced directly from git history and Azure. The repo was created on 2026-04-29; the first production blob was pushed ~31 hours later.

---

## License

See `LICENSE`.
