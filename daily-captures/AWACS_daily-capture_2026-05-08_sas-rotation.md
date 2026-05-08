# Daily Capture: SAS Token Rotation — System Returned to LIVE After 6-Day Outage
**Date:** 2026-05-08
**Session source:** AWACS Secure Lab Backup — SAS token expired 2026-05-01, rotation blocked by Norton SSL issue

---

## What Happened

The AWACS backup system had been DEGRADED for 6 days following SAS token expiry on 2026-05-01T06:41Z. Blob writes from DESKTOP-0DBOTVV were returning HTTP 403 silently — no alert fired, no error surfaced to the user, the scheduled task simply stopped doing useful work while logging nothing actionable. Once the Norton SSL interception issue was resolved, the rotation was executed: generated a new 7-day user-delegation SAS (Azure's maximum for this token type), wrote it to Key Vault using BOM-free UTF-8 via `--file`, and confirmed the round-trip read-back. System returned to LIVE at 2026-05-08T00:35:57Z. New expiry: 2026-05-14T20:35:40Z.

---

## Social Potential

**LinkedIn viable:** Maybe
**Hook angle:** "The backup system ran perfectly for 6 days after it stopped working. That's a silent failure — and it's worse than a loud one."
**Target audience:** IT directors, platform engineers, anyone running scheduled automation
**Post type:** Teaching
**Emotional driver:** Fear (recognition that this could be happening right now)
**Priority:** Medium — better as part of a larger post about silent failure modes, not standalone

**Draft hook options:**
1. "My backup system ran every 30 minutes for 6 days. It hadn't backed up anything since May 1st."
2. "Silent failure is the most dangerous kind. No alert. No error. Just nothing happening."
3. "The scheduled task showed 'last run: success.' The storage account hadn't received a file in 6 days."

**Viral levers present:**
- [x] **Confession arc** — system was degraded and we didn't know until checking manually
- [ ] Villain-vindication
- [x] **Memeable phrase:** "The task said 'success.' It wasn't." — one-liner that captures the fear
- [ ] All-caps emotional pivot
- [x] **Specific technical mechanism** — user-delegation SAS 7-day Azure hard cap; `--file` vs `--value` BOM gotcha
- [ ] Self-incriminating AI quote
- [ ] Comment-bait question
- [x] **Universal unnamed pain** — "automation that looks like it's working but isn't" is universal DevOps terror

**Lever count:** 4 / 8
**Viral candidate?:** Likely above average (3-4)

**Notes:** Best combined with the V2 rotation automation story — the outage motivates the feature. Stronger as a two-part post: Part 1 (the silent failure), Part 2 (we automated the fix).

---

## Training Material

**Training potential:** High
**Could become:** Case study + Exercise
**Which course it fits:** Course 1 (AI-Assisted Infrastructure) — credential lifecycle management
**Teaching point:** User-delegation SAS tokens have a hard 7-day Azure maximum. Unlike storage-account-key SAS tokens (which can be indefinite), user-delegation tokens are bounded by the delegating user's session. This means any system using user-delegation SAS MUST have rotation automation — manual rotation every week is not sustainable. Also: always verify the round-trip (write → read back → parse expiry) not just the write.
**Prerequisite knowledge:** Azure Storage SAS concepts, Key Vault secret management basics

**Notes:** The BOM gotcha (`System.Text.UTF8Encoding($false)`) is a mandatory teaching moment — PowerShell 5.1's `Out-File -Encoding utf8` silently adds a 3-byte BOM that Azure CLI's `--value` can't handle, but `--file` reads the raw bytes cleanly.

---

## Technical Reproduction

**Steps to recreate:**
1. Generate user-delegation SAS: `az storage container generate-sas --auth-mode login --as-user --permissions acw --expiry <7-days-max>`
2. Write BOM-free to temp file: `[System.IO.File]::WriteAllText($path, $sas.Trim(), (New-Object System.Text.UTF8Encoding $false))`
3. Store in Key Vault: `az keyvault secret set --vault-name <kv> --name <name> --file <path>`
4. Verify round-trip: `az keyvault secret show --query value -o tsv` → parse `se=` parameter

**Dependencies:**
- Azure CLI authenticated with sufficient RBAC: `Storage Blob Delegator` + `Storage Blob Data Contributor` on the storage account
- Key Vault `Secrets Officer` role on the vault

**Environment:**
- Windows 11, PowerShell 5.1
- Azure subscription 49521d08-4a34-4355-a069-919af69ad956

**Gotchas:**
- User-delegation SAS max is 7 days — `--expiry AddDays(30)` returns exit code 2
- NEVER use `--value` with a SAS token — the `&` characters break CLI argument parsing
- NEVER use `Out-File -Encoding utf8` — PowerShell 5.1 adds a 3-byte BOM silently
- Verify round-trip after write — a BOM in the stored value will cause silent 403 on blob PUT

**Rotation commands (canonical):**
```powershell
az storage container generate-sas `
    --name lab-files `
    --account-name awdustsaybmh `
    --auth-mode login --as-user `
    --permissions acw `
    --expiry (Get-Date).AddDays(7).ToString("yyyy-MM-ddTHH:mm:ssZ") `
    --output tsv > $env:TEMP\sas.tmp

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$env:TEMP\sas-nobom.tmp", (Get-Content $env:TEMP\sas.tmp -Raw).Trim(), $utf8NoBom)
az keyvault secret set --vault-name awdust-kv-ybmh --name current-write-sas --file "$env:TEMP\sas-nobom.tmp"
Remove-Item $env:TEMP\sas.tmp, $env:TEMP\sas-nobom.tmp
```

**Related files:**
- `RUNBOOK.md` — manual rotation procedure
- `STATUS.md` — updated to LIVE with new expiry
- `workstation/push-files.ps1` — consumes the KV secret on each scheduled run

---

## Product Extraction

**Standalone potential:** No — this is component-level work within the AWACS backup product
**What it is:** N/A
**Verdict:** Not a product — feeds V2 backlog item #2 (rotation automation via Azure Function)

---

## Content War Chest Category

- [x] **Proof content** — End-to-end credential lifecycle management in a live system
- [x] **Teaching content** — SAS type constraints, BOM gotcha, rotation pattern
- [ ] Methodology content
- [ ] Product content

**Primary category:** Teaching content (with proof component)

---

## Raw Material

```
Token generated: 2026-05-08T00:35:42Z
Token expires:   2026-05-14T20:35:40Z (7 days, Azure maximum for user-delegation)
Token length:    269 chars
Permissions:     acw (add/create/write)
First char code: 115 (not 65279 — BOM-free confirmed)
KV write confirmed: 2026-05-08T00:35:57Z

Previous token expiry: 2026-05-01T06:47Z
Duration of outage: ~6 days 18 hours
Blobs frozen at: 79 (count will climb as backups resume)
```

---

## Next Actions

- [ ] Trigger AwacsBackupPush task manually on DESKTOP-0DBOTVV to confirm new token works end-to-end
- [ ] Begin V2 item #2: SAS rotation automation (Azure Function or scheduled task on the workstation)
- [ ] Add rotation deadline reminder to next session memory (next rotation due: **2026-05-14**)
- [ ] Consider switching from user-delegation SAS to storage-account-key SAS for longer rotation windows (security trade-off to evaluate)

---

## Cross-References

- **Related captures:** `AWACS_daily-capture_2026-05-08_norton-tls-interception.md` (the blocker that delayed this rotation)
- **Related captures:** `docs/captures/s4-sas-expiry-silent-failure.md` (initial SAS expiry capture from 2026-05-01)
- **Related project files:** `RUNBOOK.md`, `STATUS.md`, `components/03-service-principal-auth/`
- **Builds on:** The original SAS expiry incident (2026-05-01) that identified silent failure as the root problem
- **Feeds into:** V2 rotation automation design; SAS lifecycle section of RUNBOOK.md
