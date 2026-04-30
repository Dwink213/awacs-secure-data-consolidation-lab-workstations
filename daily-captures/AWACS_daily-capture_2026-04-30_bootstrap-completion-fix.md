# Daily Capture: Bootstrap Completion — Three Bugs Fixed
**Date:** 2026-04-30
**Session source:** AWACS secure lab backup — workstation bootstrap execution on DESKTOP-0DBOTVV

---

## What Happened

`bootstrap.ps1` hung indefinitely in background execution because `Install-Module` prompts for NuGet provider trust and receives no answer when non-interactive. After manually installing NuGet and trusting PSGallery, two more bugs surfaced: `[System.TimeSpan]::MaxValue` as `RepetitionDuration` overflows the Task Scheduler XML schema (`P99999999DT23H59M59S` is the max), and `LogonType S4U` requires admin elevation to register. Both were fixed and the bootstrap now completes cleanly.

---

## Social Potential

**LinkedIn viable:** Yes
**Hook angle:** Your automation script hung silently and you didn't know why — here are three gotchas that bite you when you bootstrap a lab workstation non-interactively
**Target audience:** IT engineers, DevOps, Windows automation practitioners
**Post type:** Teaching
**Emotional driver:** Recognition — every automation engineer has had the silent hang
**Priority:** Medium

**Draft hook options:**
1. "The script ran. It also didn't run. Three separate bugs, three separate reasons — here's what non-interactive Windows automation actually looks like."
2. "Install-Module hung. Not an error. Just... silence. Here's why and how to prevent it."
3. "Three PowerShell bootstrap bugs in one run: NuGet trust, TimeSpan overflow, and a permission mode that requires admin but looks like it doesn't."

**Viral levers present:**
- [ ] Confession arc
- [ ] Villain-vindication
- [ ] Memeable phrase: "none"
- [ ] All-caps emotional pivot
- [x] Specific technical mechanism: NuGet provider trust prompt blocks non-interactive Install-Module; Task Scheduler XML schema max duration; S4U vs Interactive logon type
- [ ] Self-incriminating AI quote
- [ ] Comment-bait question with stored answers
- [x] Universal unnamed pain: The silent background hang that gives you nothing to debug

**Lever count:** 2 / 8
**Viral candidate?:** Normal (0-2)

**Notes:** Good teaching content, low viral ceiling. Better as a blog post or training module than a LinkedIn story.

---

## Training Material

**Training potential:** High
**Could become:** Case study / Exercise
**Which course it fits:** Course 1 (AI-Assisted Infrastructure)
**Teaching point:** Non-interactive automation on Windows has specific gotchas that interactive execution hides. Always test bootstrap scripts with `-NonInteractive` flag and capture ALL output. Three separate failure modes here are each independently common.
**Prerequisite knowledge:** PowerShell basics, Windows scheduled tasks, Az module familiarity

**Notes:**
- NuGet bootstrap: `Install-PackageProvider -Force` + `Set-PSRepository -InstallationPolicy Trusted` must precede `Install-Module` in automation
- `[System.TimeSpan]::MaxValue` as a cron-style duration is a common copy-paste from docs that breaks in production; absence of `-RepetitionDuration` = indefinite on modern Windows
- S4U logon requires `SeServiceLogonRight`; for interactive workstations, `Interactive` is correct and doesn't need elevation

---

## Technical Reproduction

**Steps to recreate:**
1. Write a `bootstrap.ps1` that calls `Install-Module -Force` without pre-installing NuGet
2. Run via `powershell.exe -NoProfile -ExecutionPolicy Bypass -File bootstrap.ps1` in background
3. Observe: hangs at Install-Module with no output
4. Fix: `Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser` + `Set-PSRepository -Name PSGallery -InstallationPolicy Trusted` before any `Install-Module`

**Dependencies:**
- Windows 10/11 with PowerShell 5.1
- PSGallery access (internet)

**Environment:**
- Windows 11, PowerShell 5.1, non-admin user

**Gotchas:**
- `Install-PackageProvider` itself requires TLS 1.2: `[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12`
- `[System.TimeSpan]::MaxValue` = P10675199DT2H48M5.4775807S, exceeds Task Scheduler XML max
- `Register-ScheduledTask` with `S4U` silently requires admin; error is `HRESULT 0x80070005`, not helpful
- `Interactive` logon only runs when the named user is logged in — correct for always-on lab workstations

**Code/commands to preserve:**
```powershell
# Required before Install-Module in any non-interactive script
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

# Correct trigger — no -RepetitionDuration = indefinite
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 30)

# Correct principal for interactive workstation (no admin needed)
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
```

**Related files:** `workstation/bootstrap.ps1`

---

## Product Extraction

**Standalone potential:** No
**What it is:** Part of a larger bootstrap system
**Who would use it:** N/A — embedded in AWACS solution
**Verdict:** Not a product — it's a component

---

## Content War Chest Category

- [x] **Teaching content** — Gives away knowledge (blog, tutorial, lead magnet)
- [x] **Proof content** — Shows you can do the work (portfolio, case study, credibility)

**Primary category:** Teaching content

---

## Raw Material

Three distinct bugs fixed in one bootstrap run:
1. `Install-Module` hangs non-interactively → NuGet provider prompt gets no answer → silent hang forever
2. `New-ScheduledTaskTrigger -RepetitionDuration ([System.TimeSpan]::MaxValue)` → `(8,42):Duration:P99999999DT23H59M59S` → HRESULT 0x80041318 → fix: omit the parameter
3. `New-ScheduledTaskPrincipal -LogonType S4U` → `Register-ScheduledTask: Access is denied. HRESULT 0x80070005` → fix: `-LogonType Interactive`

Final bootstrap output (green):
```
[STEP] SKIP  - Az.Accounts 2.13.2 already installed
[STEP] SKIP  - Az.KeyVault 5.0.1 already installed
[STEP] SKIP  - Az.Storage 6.1.1 already installed
[STEP] SKIP  - Cert with thumbprint BC9BE619... already in CurrentUser\My
[STEP] OK  - Copied push-files.ps1 to C:\ProgramData\AwacsBackup\push-files.ps1
[STEP] OK  - Config written to C:\ProgramData\AwacsBackup\config.json
[STEP] OK  - Scheduled task registered to run every 30 minutes
Bootstrap complete.
```

---

## Next Actions

- [ ] Update bootstrap.ps1 with pre-flight NuGet install as permanent fix
- [ ] Add bootstrap test to test battery (T7.* workstation bootstrap tests)
- [ ] Document in RUNBOOK.md: non-interactive bootstrap requires NuGet pre-install

---

## Cross-References

- **Related captures:** `AWACS_daily-capture_2026-04-30_sas-storage-bug-chain.md`
- **Related project files:** `workstation/bootstrap.ps1`, `workstation/requirements.md`
- **Builds on:** Prior session deploy + test run (all 11 tests passing)
- **Feeds into:** End-to-end push verification
