# Daily Capture: SAS Token Storage — Four Errors, One Root Cause
**Date:** 2026-04-30
**Session source:** AWACS secure lab backup — push-files.ps1 end-to-end verification on DESKTOP-0DBOTVV

---

## What Happened

A user-delegation SAS token stored in Azure Key Vault produced four distinct errors across four push attempts. Every error looked like a different problem but traced to one root: the SAS token (containing `&`, `%`, `=` characters) was corrupted at the storage step. Error progression: `PublicAccessNotPermitted` (token truncated to 27 chars by shell `&` interpretation) → `AuthenticationFailed: se is mandatory` (UTF-8 BOM prepended by PowerShell's `Out-File`) → `AuthorizationPermissionMismatch` (signer lacked `Storage Blob Data Contributor` — user-delegation SAS cannot exceed signer's own permissions) → RBAC propagation delay. Four errors, one theme: the SAS is only as good as how it's stored.

---

## Social Potential

**LinkedIn viable:** Yes
**Hook angle:** Four different Azure errors. One root cause. And I didn't see it until the fourth one.
**Target audience:** Azure engineers, DevOps, cloud platform teams, anyone who's debugged Azure Storage auth
**Post type:** Story
**Emotional driver:** Recognition + surprise (the cascade reveal)
**Priority:** High

**Draft hook options:**
1. "The script hit 4 different Azure errors in a row. Each one looked like a different problem. They weren't. Here's the cascade."
2. "PublicAccessNotPermitted. Then AuthenticationFailed. Then AuthorizationPermissionMismatch. Same bug. Different costume each time."
3. "I corrupted a SAS token three different ways before I understood the actual issue. Here's the complete failure chain."

**Viral levers present:**
- [x] Confession arc — leads with cascading failure, not a flex
- [x] Villain-vindication — PowerShell 5.1's Out-File BOM is the villain; WriteAllText is the fix
- [x] Memeable phrase: "Four errors. One root cause. And I didn't see it until the fourth one."
- [ ] All-caps emotional pivot
- [x] Specific technical mechanism: `Out-File -Encoding utf8` writes BOM; `[System.IO.File]::WriteAllText` with `New-Object System.Text.UTF8Encoding $false` doesn't; az CLI `--value` interprets `&` as shell separator
- [ ] Self-incriminating AI quote
- [x] Comment-bait question with stored answers: "What's your best Azure Storage auth cascade?" — everyone has one
- [x] Universal unnamed pain: The error that looks unrelated to what you just changed

**Lever count:** 5 / 8
**Viral candidate?:** Yes (5+) — consider timing, add code artifact, write carefully

**Notes:** This is a strong post. The cascade structure is unusual — most Azure auth posts show one problem. Showing the progression and the reveal that it was one root cause the whole time is a genuine story arc. Consider a LinkedIn carousel showing the error progression as individual slides.

---

## Training Material

**Training potential:** High
**Could become:** Case study / Live demo
**Which course it fits:** Course 1 (AI-Assisted Infrastructure), Course 2 (Methodology — debugging under constraints)
**Teaching point:** (1) Shell special characters in secrets require file-based storage, never `--value`. (2) PowerShell 5.1 UTF-8 encoding always adds BOM — use `System.Text.UTF8Encoding($false)` for any file that's read by non-PowerShell consumers. (3) User-delegation SAS permissions are bounded by the signer's actual data-plane rights — `Storage Blob Delegator` alone is not enough.
**Prerequisite knowledge:** Azure Storage SAS fundamentals, PowerShell file I/O, Azure RBAC basics

**Notes:** The RBAC piece (Delegator vs Data Contributor) is underDocumented in Azure docs and comes up constantly. High value as standalone training content.

---

## Technical Reproduction

**Steps to recreate:**
1. Generate a user-delegation SAS: `az storage container generate-sas --as-user --auth-mode login --permissions acw`
2. Try storing with: `az keyvault secret set --value $sas` — result: SAS truncated at first `&`
3. Fix: store via `--file`; write file with `Out-File -Encoding utf8` — result: 3-byte BOM prepended
4. Fix: use `[System.IO.File]::WriteAllText($path, $sas, (New-Object System.Text.UTF8Encoding $false))` — result: 403 AuthorizationPermissionMismatch
5. Diagnose: `az role assignment list --assignee <userId> --scope <storageAccountId>` — only `Storage Blob Delegator` present
6. Fix: assign `Storage Blob Data Contributor`, wait for RBAC propagation, regenerate SAS

**Dependencies:**
- Azure CLI 2.50+
- PowerShell 5.1
- Azure subscription with Owner access
- Azure Key Vault (RBAC mode)
- Azure Storage Account (public access disabled)

**Environment:**
- Windows 11, PowerShell 5.1, az CLI

**Gotchas:**
- `az keyvault secret set --value <SAS>` interprets `&` as command separator — ALWAYS use `--file`
- `Out-File -Encoding utf8` in PS 5.1 writes 3-byte UTF-8 BOM (bytes EF BB BF); `az keyvault secret set --file` may or may not strip it — don't rely on this
- `Get-AzKeyVaultSecret -AsPlainText` returns BOM as 3 actual string characters, not stripped as Unicode U+FEFF
- `Storage Blob Delegator` ≠ write access; it only grants `GenerateUserDelegationKey` action
- User-delegation SAS is bounded by signer's actual RBAC permissions on the data plane
- RBAC propagation can take 2–5 minutes; regenerate SAS AFTER propagation, not before

**Code/commands to preserve:**
```powershell
# CORRECT: Store SAS token in Key Vault without shell escaping or BOM issues
$sas = (az storage container generate-sas --name "lab-files" `
    --account-name $storageAccount `
    --auth-mode login --as-user --permissions acw `
    --expiry $expiry --output tsv 2>&1).Trim()

$tmpFile = Join-Path $env:TEMP "awacs-sas-$(Get-Random).txt"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($tmpFile, $sas, $utf8NoBom)

az keyvault secret set --vault-name $kvName --name "current-write-sas" --file $tmpFile --output none
Remove-Item $tmpFile -Force

# CORRECT: Read SAS back defensively in push script
$sasSecret = (Get-AzKeyVaultSecret -VaultName $kvName -Name $secretName -AsPlainText).TrimStart([char]0xFEFF).Trim()

# Required RBAC for user-delegation SAS that can delegate write:
# Storage Blob Delegator  — generate the key
# Storage Blob Data Contributor — have the permissions to delegate
```

**Related files:** `workstation/push-files.ps1`, `deploy/Deploy.ps1`

---

## Product Extraction

**Standalone potential:** Maybe
**What it is:** A safe SAS rotation helper that handles storage, BOM, and permission verification
**Who would use it:** Azure Storage teams, anyone who rotates SAS tokens as part of a backup pipeline
**What it needs for GitHub:**
- [ ] Parameterize storage account, container, KV vault, secret name
- [ ] Add permission pre-check (verify signer has Blob Data Contributor before generating)
- [ ] Add BOM-safe write as utility function
- [ ] Add rotation schedule wrapper

**MVP scope:** A 50-line PowerShell function: `Invoke-SafeSasRotation -StorageAccount -Container -KeyVault -SecretName -ExpiryHours`
**Monetization angle:** Open source credibility / lead magnet for AWACS training
**Verdict:** Explore further — good fit for AWACS toolbox, low effort to generalize

---

## Content War Chest Category

- [x] **Proof content** — Shows you can do the work
- [x] **Teaching content** — Gives away knowledge
- [x] **Methodology content** — Cascading error resolution discipline

**Primary category:** Teaching content (viral potential via cascade story)

---

## Raw Material

Error progression verbatim:

**Run 1:** `PublicAccessNotPermitted` HTTP 409 — SAS length: 27 chars
- Cause: `az keyvault secret set --value se=2026-...&sp=acw&...` — PowerShell/CMD interprets `&` as command separator; everything after first `&` runs as a separate command
- Fix: `--file <path>`

**Run 2:** `AuthenticationFailed: se is mandatory. Cannot be empty` HTTP 403 — SAS length: 267 (vs 264 generated)
- Cause: `Out-File -Encoding utf8` writes BOM (bytes 239,187,191 = ï»¿); prepended to `se=...`
- Fix: `[System.IO.File]::WriteAllText($path, $sas, (New-Object System.Text.UTF8Encoding $false))`

**Run 3:** `AuthorizationPermissionMismatch` HTTP 403 — SAS length: 266
- Cause: User has `Storage Blob Delegator` only; user-delegation SAS with `sp=acw` requests permissions the signer doesn't hold
- Fix: Assign `Storage Blob Data Contributor` + regenerate SAS

**Run 4:** Still 403 — RBAC propagation lag (2–5 min)
- Status: Waiting for resolution at session end

---

## Next Actions

- [ ] Verify push succeeds after RBAC propagation (wakeup scheduled for 02:51)
- [ ] Update Deploy.ps1 to assign `Storage Blob Data Contributor` to deploying identity during initial deploy
- [ ] Write ADR for SAS rotation pattern (safe storage via `--file`, BOM-free, with permission pre-check)
- [ ] Add defensive `.TrimStart([char]0xFEFF).Trim()` to push-files.ps1 SAS read (already done)
- [ ] Document in RUNBOOK.md: SAS rotation procedure with BOM-safe write

---

## Cross-References

- **Related captures:** `AWACS_daily-capture_2026-04-30_azure-rbac-delegator-vs-contributor.md`
- **Related project files:** `workstation/push-files.ps1`, `deploy/Deploy.ps1`, `components/03-service-principal-auth/`
- **Builds on:** Prior session: SP cert auth chain (already working), KV secret read (working)
- **Feeds into:** Verified end-to-end push flow, SAS rotation as product component
