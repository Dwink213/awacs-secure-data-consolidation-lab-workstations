# STATUS.md — AWACS Secure Lab Backup
**Last updated:** 2026-05-10
**Updated by:** 2026-05-10 finalization session (Stage 5 closure)

---

## System State: LIVE ✅ — Rotation Automated

SAS token rotated by Automation Account `awdust-auto-ybmh` on 2026-05-08T21:41:03Z. Expiry: **2026-05-15T21:41:03Z**. Next automatic rotation: ~2026-05-14 (noon UTC). Manual rotation is now a fallback procedure only — see RUNBOOK.md.

---

## What Works Today

| Component | Status | Evidence |
|-----------|--------|----------|
| IaC deploy (`deploy/Deploy.ps1`) | ✅ Working | 3 deploy iterations; RG `awdust-rg` exists |
| Storage account (`awdustsaybmh`) | ✅ Working | WORM immutability enabled; 79 blobs present |
| Key Vault (`awdust-kv-ybmh`) | ✅ Working | RBAC mode; `current-write-sas` secret present |
| Log Analytics (`awdust-la-ybmh`) | ✅ Working | Diag settings forwarding from SA and KV |
| Service principal (`awdust-lab-sp`) | ✅ Working | Cert `BC9BE61910E9D83061AFBA8D06DBA03380B0876B`; cert-only auth |
| Workstation bootstrap (`workstation/bootstrap.ps1`) | ✅ Working | DESKTOP-0DBOTVV: all 6 steps green |
| Scheduled task (`AwacsBackupPush`) | ✅ Working | Every 30 min, Interactive logon, DESKTOP-0DBOTVV |
| Push script (`workstation/push-files.ps1`) | ✅ Working | SAS rotated; HTTP 403 resolved |
| SAS rotation automation (`awdust-auto-ybmh`) | ✅ Working | Job 45bb7628 succeeded; next run ~2026-05-14 noon UTC |
| Test battery (20/20 executable scripts) | ✅ Passing | Storage hardening, KV hardening, immutability, diag, consumer RBAC, C8 rotation checks |
| End-to-end cert → SAS → blob flow | ✅ Verified | REST PUT 201; 97 blobs confirmed in container |

---

## What's Scaffolded (Not Functional)

| Item | Status | Notes |
|------|--------|-------|
| Test specs 12–52 | ⚠️ Spec-only | 38 of 52 test specs have no executable script; runnable subset covers most load-bearing checks |
| Multi-workstation isolation | ⚠️ One workstation tested | DESKTOP-0DBOTVV only; second workstation bootstrap not yet run |
| `deploy/preflight.sh` / `verify.sh` / `teardown.sh` | ⚠️ Not present | Deploy toolchain is Windows-primary; `.ps1` versions are the authoritative path. `.sh` wrappers are a v2 item. |

---

## What's Blocked

| Item | Blocker | Next Step |
|------|---------|-----------|
| Deploy.ps1 auto-assigns `Storage Blob Data Contributor` | Not yet implemented | Dustin's call: add to `deploy/Deploy.ps1` so next fresh deploy doesn't require manual RBAC step |
| GitHub publish | Pending scope decision | Dustin to confirm public vs. private; sanitize file names from logs if going public |
| Mode B cert distribution (external PKI) | Design only | `deploy/Deploy.ps1` implements Mode A only; Mode B documented but not coded |

---

## Azure Resources (Keep)

| Resource | Name | Region | Notes |
|----------|------|--------|-------|
| Resource Group | `awdust-rg` | eastus2 | Owns all other resources |
| Storage Account | `awdustsaybmh` | eastus2 | WORM; 79 blobs as of 2026-04-30 |
| Key Vault | `awdust-kv-ybmh` | eastus2 | RBAC mode; holds `current-write-sas` |
| Log Analytics | `awdust-la-ybmh` | eastus2 | Receives diag from SA and KV |
| Automation Account | `awdust-auto-ybmh` | eastus2 | Free SKU; MSI `41ca010b-76bc-434a-a052-8112c3ef69fc`; runbook `rotate-sas` |
| SP App Registration | `awdust-lab-sp` | global | App ID `a35642f9-8f24-429a-ae4a-2c3d22c1f636` |

**Subscription:** `49521d08-4a34-4355-a069-919af69ad956`
**Monthly cost estimate:** ~$2–5/month (storage + KV operations + LA ingestion at this volume)

---

## Workstation State (DESKTOP-0DBOTVV)

| Item | Value |
|------|-------|
| Bootstrap date | 2026-04-30 |
| Config path | `C:\ProgramData\AwacsBackup\config.json` |
| Push script path | `C:\ProgramData\AwacsBackup\push-files.ps1` |
| Ledger path | `C:\ProgramData\AwacsBackup\pushed.json` (78 entries) |
| Watch directory | `C:\Users\Dustin\Downloads\` |
| Scheduled task | `AwacsBackupPush` — every 30 min, Interactive |
| Cert thumbprint | `BC9BE61910E9D83061AFBA8D06DBA03380B0876B` |
| Cert store | `CurrentUser\My` |

---

## SAS Token State

| Item | Value |
|------|-------|
| KV secret name | `current-write-sas` |
| Length | ~264–270 chars |
| **Status** | **LIVE** — rotated by Automation Account 2026-05-08T21:41:03Z, expires 2026-05-15T21:41:03Z |
| Permissions | `acw` (add/create/write) |
| Rotation method | **Automated** — Azure Automation Account `awdust-auto-ybmh`, schedule `every-6-days`, noon UTC |

Manual rotation is a fallback procedure only. If the Automation job fails, see `RUNBOOK.md`.

---

## Known Gotchas (Hard-Won)

1. **SAS tokens contain `&` — never use `--value`** — use `--file` with BOM-free UTF-8 write
2. **PowerShell 5.1 `Out-File -Encoding utf8` adds 3-byte BOM** — use `System.Text.UTF8Encoding($false)`
3. **User-delegation SAS needs TWO roles:** `Storage Blob Delegator` (key generation) AND `Storage Blob Data Contributor` (data-plane permissions)
4. **RBAC propagation: 2–5 min** — regenerate SAS AFTER propagation, not before
5. **`Install-Module` hangs non-interactively** — pre-install NuGet provider first
6. **`TimeSpan.MaxValue` overflows Task Scheduler XML** — omit `-RepetitionDuration` for indefinite repeat
7. **`LogonType S4U` requires admin** — use `Interactive` for always-logged-in workstations
8. **Norton Web Shield re-signs Azure CLI TLS** — Python certifi doesn't trust Norton's CA; disable SSL scanning in Norton or add Azure domains as exclusions (login.microsoftonline.com, management.azure.com, vault.azure.net, blob.core.windows.net)
9. **`az automation runbook replace-content` and `az automation jobSchedules create` are missing** — upload runbook content and link schedules via REST API with `Invoke-RestMethod` + Bearer token
10. **Automation Variable values must be JSON-encoded** — strings need extra double-quote layer: `'"${myVar}"'` not `'${myVar}'`

---

## V2 Backlog (from SESSION_2026-04-30.md)

- [ ] Auto-assign `Storage Blob Data Contributor` in `deploy/Deploy.ps1`
- [x] SAS rotation automation — done: Azure Automation Account `awdust-auto-ybmh`, component 08
- [ ] 38 remaining test specs → executable scripts
- [ ] Second workstation bootstrap and isolation test
- [ ] GitHub publish + README polish + deploy GIF
- [ ] Mode B cert distribution (external PKI)
- [ ] Subscription-level diagnostic setting

---

## Session Reference

| Session | Date | Key outcome |
|---------|------|-------------|
| Autonomous overnight run | 2026-04-30 | Full IaC + tests + docs authored |
| Live deployment | 2026-04-30 | RG deployed, tests passing, bootstrap complete, 78/78 push verified |
| SAS expiry / silent failure | 2026-05-01 | SAS expired; system DEGRADED; silent 403 failure mode documented; rotation pending |
| Norton TLS fix + manual SAS rotation | 2026-05-08-s1 | Norton SSL interception diagnosed; token rotated manually; system LIVE |
| Component 08 build (SAS rotator) | 2026-05-08-s2 | Azure Automation Account deployed; runbook tested (job 45bb7628); IaC reconciled |
| Doc audit + P1/P2 closure | 2026-05-09 | IaC-Reality Inversion in ADR-008 found and corrected; all stale refs fixed |
| Stage 5 finalization | 2026-05-10 | Session notes written; STATUS.md corrected; cross-agent review completed |

Full session notes: `docs/session-notes/`
