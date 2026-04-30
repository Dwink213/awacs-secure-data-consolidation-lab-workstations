# STATUS.md — AWACS Secure Lab Backup
**Last updated:** 2026-04-30
**Updated by:** EOD capture agent (session: 2026-04-30 live deployment)

---

## System State: LIVE ✅

The AWACS secure lab backup system is **deployed and operational** against Azure subscription `49521d08-4a34-4355-a069-919af69ad956`.

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
| Push script (`workstation/push-files.ps1`) | ✅ Working | 78/78 files pushed 2026-04-30 03:01:16 |
| Test battery (11/11 executable scripts) | ✅ Passing | Storage hardening, KV hardening, immutability, diag, consumer RBAC |
| End-to-end cert → SAS → blob flow | ✅ Verified | REST PUT 201; 79 blobs confirmed in container |

---

## What's Scaffolded (Not Functional)

| Item | Status | Notes |
|------|--------|-------|
| Test specs 12–52 | ⚠️ Spec-only | 38 of 52 test specs have no executable script; runnable subset covers most load-bearing checks |
| SAS rotation automation | ⚠️ Manual only | 24h SAS; RUNBOOK.md documents manual rotation; no scheduled rotator yet |
| Multi-workstation isolation | ⚠️ One workstation tested | DESKTOP-0DBOTVV only; second workstation bootstrap not yet run |
| `deploy/preflight.sh` / `verify.sh` / `teardown.sh` | ⚠️ Present but Windows-focused | `.sh` wrappers exist; `.ps1` versions are the primary path |

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
| Expires | ~2026-05-01T06:41–06:43Z (24h from last regeneration) |
| Permissions | `acw` (add/create/write) |
| Rotation method | Manual — see `RUNBOOK.md` |

**⚠️ Action required by 2026-05-01:** Rotate SAS before expiry. Run:
```powershell
az storage container generate-sas `
    --name lab-files `
    --account-name awdustsaybmh `
    --auth-mode login --as-user `
    --permissions acw `
    --expiry (Get-Date).AddDays(1).ToString("yyyy-MM-ddTHH:mm:ssZ") `
    --output tsv > $env:TEMP\sas.tmp
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$env:TEMP\sas-nobom.tmp", (Get-Content $env:TEMP\sas.tmp -Raw).Trim(), $utf8NoBom)
az keyvault secret set --vault-name awdust-kv-ybmh --name current-write-sas --file "$env:TEMP\sas-nobom.tmp"
Remove-Item $env:TEMP\sas.tmp, $env:TEMP\sas-nobom.tmp
```

---

## Known Gotchas (Hard-Won)

1. **SAS tokens contain `&` — never use `--value`** — use `--file` with BOM-free UTF-8 write
2. **PowerShell 5.1 `Out-File -Encoding utf8` adds 3-byte BOM** — use `System.Text.UTF8Encoding($false)`
3. **User-delegation SAS needs TWO roles:** `Storage Blob Delegator` (key generation) AND `Storage Blob Data Contributor` (data-plane permissions)
4. **RBAC propagation: 2–5 min** — regenerate SAS AFTER propagation, not before
5. **`Install-Module` hangs non-interactively** — pre-install NuGet provider first
6. **`TimeSpan.MaxValue` overflows Task Scheduler XML** — omit `-RepetitionDuration` for indefinite repeat
7. **`LogonType S4U` requires admin** — use `Interactive` for always-logged-in workstations

---

## V2 Backlog (from SESSION_2026-04-30.md)

- [ ] Auto-assign `Storage Blob Data Contributor` in `deploy/Deploy.ps1`
- [ ] SAS rotation automation (Function-based rotator or scheduled task)
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

Full session notes: `docs/session-notes/SESSION_2026-04-30.md`
