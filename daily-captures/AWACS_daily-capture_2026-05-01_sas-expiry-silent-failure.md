# Daily Capture: SAS Token Expiry — Backups Failing Silently
**Date:** 2026-05-01
**Session source:** AWACS secure lab backup — post-expiry operational event

---

## What Happened

The 24-hour write SAS token for storage account `awdustsaybmh` container `lab-files`, generated during the 2026-04-30 live deployment session, expired at approximately 2026-05-01T06:41Z. The scheduled backup task `AwacsBackupPush` on DESKTOP-0DBOTVV runs every 30 minutes and has been returning HTTP 403 on every blob write attempt since expiry. No cloud-side alert fired. No notification reached the operator. The failure was surfaced only because `project_awacs_state.md` (the memory file) carried the expiry timestamp across the context compaction boundary and the agent read it at session start. As of 2026-05-01, backups are failing silently; rotation is pending.

---

## Social Potential

**LinkedIn viable:** Yes
**Hook angle:** My automated backup system has been failing silently for hours. Nothing told me. Here's the gap I didn't design for.
**Target audience:** Azure engineers, platform engineers, cloud ops practitioners, anyone running scheduled credential-dependent automation
**Post type:** Confession / Teaching
**Emotional driver:** Fear (this will happen to you) + recognition (we've all had the silent failure)
**Priority:** High

**Draft hook options:**
1. "My automated backup ran fine all night. Then the token expired. The script kept running. The backups stopped arriving. Nothing told me. Here's what that looks like in production."
2. "A 24-hour SAS token. A scheduled task that runs every 30 minutes. No alerting on expiry. You can see exactly where this is going."
3. "The system said it was running. The blobs disagreed. Silent 403 is the most dangerous error in cloud automation — because it looks exactly like success from the outside."

**Viral levers present (from checklist above):**
- [x] **Confession arc** — "My backup has been failing silently" is a failure everyone in cloud ops has experienced or fears
- [ ] Villain-vindication
- [x] **Memeable phrase:** "The script kept running. The backups didn't."
- [ ] All-caps emotional pivot
- [x] **Specific technical mechanism** — SAS token expiry → HTTP 403 on blob write → no alert → silent data loss window
- [ ] Self-incriminating AI quote
- [x] **Comment-bait question with stored answers** — "What's your worst 'silent failure' story?" Every ops engineer has one.
- [x] **Universal unnamed pain** — "Silent 403" — a credential expires, automation keeps running, nothing signals failure; you only discover it when you look for the data

**Lever count:** 5 / 8
**Viral candidate?:** Yes (5+)

**Notes:** Pair with the memory-system capture — the agent warned that the token was about to expire. That warning came true. The story arc is: agent warns → user doesn't act immediately → token expires → system fails silently → agent surfaces the failure again from memory. The full arc is more compelling than either moment alone. Sanitize the subscription ID and resource names before posting.

---

## Training Material

**Training potential:** High
**Could become:** Module / Case study
**Which course it fits:** Course 1 (AI-Assisted Infrastructure) — specifically the "credential lifecycle and alerting" module; also Course 2 (Methodology) for the "monitoring vs. running a cron" distinction
**Teaching point:** Time-bounded credentials in automated workflows require two things V1 almost always skips: (1) alerting before expiry, not just a calendar note; (2) a graceful failure mode in the automation itself that distinguishes 403 from other errors and escalates. Silent 403 is not a failure state — it's an absence of state. The push script ran. The blob write failed. The script exited 0. Nothing downstream knew.
**Prerequisite knowledge:** Azure SAS tokens, scheduled task basics, HTTP error codes, Key Vault secret retrieval pattern

**Notes:** This pairs directly with the SAS storage bug chain capture from 2026-04-30 — the prior capture is "here's how to write the token correctly"; this capture is "here's what happens when the correctly-written token expires and nobody is watching." Full arc for the Course 1 credential lifecycle module.

---

## Technical Reproduction

**Steps to recreate:**
1. Generate a short-TTL (e.g., 5-minute) SAS token, store in Key Vault
2. Run `workstation/push-files.ps1` before expiry — blobs write successfully
3. Wait for token to expire
4. Run `workstation/push-files.ps1` again — observe HTTP 403 response on blob write
5. Check Azure Storage logs — confirm 403 appears in Log Analytics, but no alert fired

**The correct mitigation (not yet implemented in V1):**
1. Azure Monitor alert rule: `StorageBlobLogs | where StatusCode == 403 and CallerIpAddress contains "workstation-IP"` → alert on 403 spike
2. SAS rotation automation: Azure Function or scheduled task that regenerates the SAS 4 hours before expiry
3. Push script error handling: distinguish HTTP 403 (credential expired) from other errors; write to a local error log with ERROR level; optionally send a Windows event log entry

**Dependencies:**
- `awdustsaybmh` storage account with diagnostic logging to `awdust-la-ybmh`
- `workstation/push-files.ps1` and its scheduled task
- Log Analytics workspace (already deployed)

**Environment:**
- Windows workstation (DESKTOP-0DBOTVV), PowerShell 5.1
- Azure Storage (WORM container `lab-files`)
- Azure Key Vault (`awdust-kv-ybmh`)

**Gotchas:**
- **HTTP 403 on blob write does NOT set PowerShell exit code to non-zero** if the REST call is wrapped in a try/catch that catches silently. Check the push script's error handling explicitly.
- **Log Analytics diagnostic logs have a 2–5 minute ingestion delay** — don't expect real-time 403 detection via LA alone.
- **The scheduled task shows "Last Run Result: 0x0"** even when all blob writes fail, if the script doesn't explicitly set exit code on error. This is the core of the "silent failure" problem.

**Code/commands to preserve:**
```powershell
# Detect SAS expiry proactively (add to push script or as a separate preflight)
$expiry = (az keyvault secret show --vault-name awdust-kv-ybmh --name current-write-sas --query "attributes.expires" -o tsv)
if ([datetime]::Parse($expiry) -lt (Get-Date).AddHours(4)) {
    Write-Error "WARN: SAS token expires within 4 hours. Rotation required."
    # Optionally: exit 1 to cause scheduled task to report failure
}

# Log Analytics alert query (future: create as Azure Monitor alert rule)
# StorageBlobLogs
# | where TimeGenerated > ago(1h)
# | where StatusCode == 403
# | where OperationName == "PutBlob"
# | summarize count() by bin(TimeGenerated, 5m), CallerIpAddress
# | where count_ > 2
```

**Related files:** `workstation/push-files.ps1`, `STATUS.md` (updated 2026-05-01), `RUNBOOK.md` (SAS rotation procedure)

---

## Product Extraction

**Standalone potential:** Maybe — as a pattern/checklist, not a product
**What it is:** A "credential lifecycle checklist" for Azure automation workflows — what to instrument before deploying scheduled tasks that use time-bounded credentials
**Who would use it:** Platform engineers standing up new Azure automation; anyone deploying SAS-based scheduled tasks
**What it needs for GitHub:**
- [ ] A `credential-lifecycle-checklist.md` template covering: expiry alerting, rotation automation, failure mode escalation, exit code discipline
- [ ] Example Azure Monitor alert rule query for 403 detection

**MVP scope:** One markdown checklist + one LA query — 30 minutes to write
**Monetization angle:** Lead magnet / Course 1 teaching content — not a standalone product
**Competitors/alternatives:** General Azure security checklists exist; none specific to SAS token lifecycle in scheduled automation contexts
**Verdict:** Explore further — as a RUNBOOK.md addition and Course 1 module artifact

---

## Content War Chest Category

- [x] **Proof content** — real production failure, real timestamps, real gap
- [x] **Teaching content** — demonstrates what silent 403 looks like and how to prevent it
- [x] **Methodology content** — the gap between "automation is running" and "automation is working"
- [ ] Product content

**Primary category:** Teaching content

---

## Raw Material

**System state at discovery:**
- SAS expiry timestamp (from memory file): ~2026-05-01T06:41Z
- Discovery method: memory file `project_awacs_state.md` surfaced at agent session start
- Actual failure mode: HTTP 403 on `PutBlob` to `awdustsaybmh/lab-files`
- Alert fired: None
- Scheduled task status: Running (every 30 min), exit code 0x0 — silent failure

**STATUS.md before this session (system state field):**
> System State: LIVE ✅

**STATUS.md after this session (system state field):**
> System State: DEGRADED ⚠️ — SAS expired, backups failing silently, rotation pending

**The gap in plain language:**
The memory system correctly predicted the expiry. The agent surfaced the warning at session start. But the push script has no mechanism to distinguish "SAS expired" from "network timeout" — both produce non-200 responses, and the current error handling exits 0. The system appears healthy to Task Scheduler; the data pipeline is broken.

---

## Next Actions

- [ ] **URGENT:** Rotate SAS token — command in STATUS.md SAS Token State section
- [ ] Add HTTP 403 detection to `workstation/push-files.ps1` — exit non-zero on 403, write ERROR to local log
- [ ] Add Azure Monitor alert rule for 403 spike on `awdustsaybmh` — LA query in Technical Reproduction section
- [ ] Add SAS rotation automation to V2 backlog (already there) with this incident as motivation
- [ ] Update `memory/project_awacs_state.md` after rotation with new expiry timestamp
- [ ] Add "credential expiry alerting" to the credential lifecycle checklist in RUNBOOK.md

---

## Cross-References

- **Related captures:** `AWACS_daily-capture_2026-04-30_sas-storage-bug-chain.md` — the prior capture on writing the SAS correctly; this is the sequel ("what happens after you get it right but don't alert on expiry")
- **Related captures:** `AWACS_daily-capture_2026-04-30_memory-system-first-use.md` — the memory system that surfaced this warning; validates the memory pattern AND exposes its limits
- **Related project files:** `STATUS.md` (updated this session), `RUNBOOK.md` (rotation procedure), `workstation/push-files.ps1`
- **Builds on:** 2026-04-30 SAS implementation; memory system initialization; V2 SAS rotation backlog item
- **Feeds into:** Course 1 credential lifecycle module; RUNBOOK.md credential section; V2 SAS rotation automation design; LinkedIn "silent 403" post
