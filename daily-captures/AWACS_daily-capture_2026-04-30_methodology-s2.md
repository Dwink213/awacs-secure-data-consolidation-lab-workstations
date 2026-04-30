# Methodology Capture: The Completion Arc
**Date:** 2026-04-30
**Session source:** AWACS secure lab backup — RBAC propagation wait → SAS regeneration → REST verification → 78/78 push
**Book chapter affinity:** Chapter 7 (Compounding) + Chapter 2 (Ground Truth)

---

## Session Arc

The session began with a known pending state: RBAC propagation in progress after assigning `Storage Blob Data Contributor` to the deploying identity. The work ahead was not debugging — it was *verification*. The question was whether everything that had been fixed actually worked in sequence. It did. The SAS regenerated clean (264 chars, BOM-free). The REST PUT returned 201. The pushed.json ledger was cleared. The full push ran: 78/78 files in 8 minutes and 22 seconds, largest file 352MB, 79 blobs confirmed in the container. The session ended not with a breakthrough but with a verification — and that is its own kind of result.

---

## Decision Sequences

### Decision 1: Delete the ledger before the final push
**Starting assumption:** The pushed.json ledger would skip files already marked as uploaded, potentially masking failures if some entries were from the failed runs
**What happened:** User instruction: delete `C:\ProgramData\AwacsBackup\pushed.json` so the next push treats all 78 files as new and every upload is freshly verified
**Pivot point:** Recognized that a clean sweep mattered more than dedup efficiency for a verification run
**Final decision:** Delete the ledger, run full push — all 78 files uploaded and all 78 new ledger entries written
**Transferable principle:** When verifying a system for the first time, remove deduplication state. A verification that skips half the work because a prior failed run partially updated the ledger is not a verification.

### Decision 2: REST PUT verification before full push
**Starting assumption:** SAS regeneration followed immediately by the full push would be sufficient
**What happened:** Added an intermediate step — a REST PUT of a 12-byte test blob (`awacs-verify.txt`) — before invoking push-files.ps1
**Pivot point:** The prior failure pattern: well-formed SAS, correct command, still 403. Trust was low. A cheap test before a long run was the right call.
**Final decision:** REST PUT → 201 → full push. The REST PUT took 5 seconds; the full push took 8 minutes. The 5 seconds saved potential diagnosis of another auth failure at file 1 of 78.
**Transferable principle:** Before a long automated run that would fail the same way at every file, run the cheapest possible end-to-end check that exercises the full auth path. A single blob PUT is that check for a write-SAS pipeline.

### Decision 3: Regenerate the SAS after RBAC propagation, not before
**Starting assumption:** The SAS generated before role assignment might still work once the role propagated
**What happened:** Discarded the prior SAS and regenerated a fresh one after waiting for propagation
**Pivot point:** The user-delegation SAS is signed against the delegation key, which is bound to the signer's permissions at key-generation time. A SAS generated before the role exists was generated with no data-plane permissions to delegate — it cannot retroactively gain them.
**Final decision:** Always regenerate after RBAC changes
**Transferable principle:** User-delegation SAS is a snapshot of the signer's permissions at key-generation time. RBAC changes after key generation are invisible to that SAS. Regenerate. This is documented in the gotchas list now; it was hard-won.

---

## Human Judgment Moments

- **Moment:** Choosing to wait rather than immediately testing after the RBAC assignment
  **The judgment call:** RBAC propagation in Azure takes 2–5 minutes. Testing immediately after the assignment would produce a false failure — the role exists, but the authorization service hasn't seen it yet. The wakeup timer was set for 3 minutes.
  **Why process alone wouldn't have gotten here:** Process says "assign role, then test." It doesn't say "wait 3 minutes between those two steps." That delay comes from experience with Azure propagation latency, not from documentation.
  **Outcome:** The 3-minute wait was correct. The REST PUT at the end of the wait returned 201 on first attempt.

- **Moment:** Treating the push verification as a ceremony, not just a task
  **The judgment call:** Logged every file name, every file size, the cert expiry check, the SAS length and prefix, the per-file sha256. The full push log is a teaching artifact — not because it was designed to be, but because the logging discipline that was built into push-files.ps1 made it one automatically.
  **Why process alone wouldn't have gotten here:** Logging discipline was established in CLAUDE.md as Rule 8. But Rule 8 doesn't know that the log would end up being used in a daily capture, a LinkedIn post, and a course case study. The log's value as a teaching artifact was a compounding effect of a rule applied consistently.
  **Outcome:** The full push log exists. It will be used.

---

## Discipline Practices Applied

- [x] **Ground truth before live calls** — REST PUT verification before full 78-file push
- [ ] **Pattern → ADR in same session** — SAS dual-role pattern not yet formalized as ADR (pending)
- [ ] **Self-audit through critic** — not run this session
- [x] **Institutional memory capture** — five daily captures written; session notes updated
- [x] **Compounding knowledge capture** — gotchas list updated in end-to-end push capture; methodology documents both sessions
- [ ] **Mandatory lookup order** — no new lookups needed; all operations were from established patterns
- [x] **Session-end capture** — this document

**New practice observed this session:**
**Verification ceremony at completion.** When a system has been through multiple debugging rounds and is finally working, the correct closing move is not "it works, move on" but "it works, verify every layer, document the proof." The REST PUT before the full push, the blob count check after, the ledger count check — these are a ceremony. The ceremony serves two purposes: it confirms the system is actually working (not just that the last error is gone), and it produces the artifacts (logs, counts, blob names) that become the proof content for downstream use. This is distinct from ordinary testing. Testing happens during development. The verification ceremony happens at completion, and its audience is partially the future.

---

## Compounding Effects

**What this session left behind that makes the next session better:**

| Artifact | What it does for future sessions |
|----------|--------------------------------|
| push-files.ps1 with BOM-trim + SAS prefix logging | Any future SAS issue surfaces in the log immediately: length and first 5 chars on every run |
| pushed.json with 78 entries | Next run skips all 78 already-uploaded files unless they change |
| RBAC state: both Delegator AND Data Contributor | SAS rotation works; any future regeneration succeeds on first attempt |
| Five daily captures with proof logs | Content pipeline: three LinkedIn posts, one course case study, one product README section |
| Session notes with full debug chain | Anyone debugging the same 4-layer error chain finds the answer in 10 minutes instead of 3 hours |
| Scheduled task active on DESKTOP-0DBOTVV | System is live; no human intervention needed for the next 24h of backups |

**Knowledge base delta:** Gotchas documented across 4 daily captures; not yet in `/knowledge/` (pending)
**Tooling delta:** push-files.ps1 hardened (BOM-trim, SAS prefix logging); bootstrap.ps1 fixed (NuGet, TimeSpan, Interactive logon)
**Rule delta:** Two candidates for CLAUDE.md addition: "Store SAS secrets via --file always" and "User-delegation SAS requires both Delegator and Data Contributor — regenerate after RBAC changes"

---

## Anti-Patterns & Time Sinks

- **Time sink:** None in the completion arc — the propagation wait was unavoidable, and the REST PUT was the right intermediate check
  **Root cause:** N/A
  **Prevention for next time:** N/A — this phase was clean execution, not debugging

- **Anti-pattern (inherited from prior phase, not this one):** The SAS was stored in KV before verifying what was actually stored. The "verify what you stored before running the downstream test" practice was articulated in the methodology capture but not yet encoded as a rule. The next deployment would benefit from a `az keyvault secret show` step in the SAS storage procedure to verify length and prefix before running any push.

---

## The Compounding Story

The completion arc is the quietest part of the story. The debugging was dramatic — four errors, each revealing a new layer, each requiring a different fix. The completion was methodical: wait, regenerate, verify, run, count, confirm. 78 files. 79 blobs. 8 minutes and 22 seconds. But the quietness of the completion is itself the point.

The system worked on the first attempt after the fixes were in place. Not "mostly worked" or "worked with one more tweak." On the first verified attempt after the root causes were corrected, every blob landed. This is not luck. This is what happens when debugging is done at the layer where the problem exists rather than papered over at the symptom layer. The BOM was fixed at the write layer AND defended against at the read layer. The RBAC was fixed by assigning the correct roles AND by regenerating the delegation key after propagation. The bootstrap was fixed by pre-installing NuGet AND by switching to the correct logon type. Each fix was complete.

The methodology lesson here is about the difference between "error is gone" and "root cause is fixed." After the first fix (--file instead of --value), the SAS stored correctly. After the second fix (BOM-free write), the SAS read correctly. After the third fix (Storage Blob Data Contributor), the SAS was valid for its claimed permissions. Any of those three could have been declared "done" when the immediate error went away. None of them were. The fixes compound: the next engineer who works on this system will not encounter the BOM problem, the truncation problem, or the RBAC naming problem — because all three were fixed and documented in the same session.

The verification ceremony at the end matters because it closes the loop. Not "the last error is gone" but "78 blobs are in the container, the ledger has 78 entries, the scheduled task fires every 30 minutes." This is what done looks like when the system is actually done.

---

## Book Chapter Affinity

**Primary chapter:** Chapter 7 (Compounding) — the completion arc is a compounding story; the debugging discipline of the prior session made the verification clean; the logging discipline from Rule 8 made the proof artifacts automatic; the methodological capture in this session makes the next engineer faster
**Secondary chapters:** Chapter 2 (Ground Truth) — the REST PUT before the full push is a micro-instance of ground truth practice; Chapter 6 (The Human Layer) — the RBAC propagation wait is a judgment call about timing that doesn't come from documentation
**Key quote or insight for the book:** "The verification ceremony is not a test. Testing happens during development. The verification ceremony happens at completion, and its audience is partially the future."

---

## Book Flavor Tags

- [ ] Confession moment
- [x] **Villain-vindication arc** — four errors, all fixed at the root; the clean 78/78 push is the vindication
- [x] **Memeable phrase** — "The cert authenticated. The SAS fetched. The blobs landed. Four errors to get here."
- [ ] Caught-the-AI-lying moment
- [ ] Human-override moment
- [ ] Performative-vs-real contrast

**Narrative weight:** Medium
**Why it matters for the book:** Completion arcs are underrepresented in technical writing because they feel anticlimactic. But the clean completion is the payoff for the discipline applied during debugging. Showing what it looks like when everything works — after showing all the ways it didn't — is how you make the discipline feel real rather than theoretical.

---

## Cross-References

- **Related methodology captures:** `AWACS_daily-capture_2026-04-30_methodology.md` — prior session methodology (cascade debugging); this document covers the completion arc that followed
- **Related topic captures from this session:** `AWACS_daily-capture_2026-04-30_end-to-end-push-verified.md`, `AWACS_daily-capture_2026-04-30_azure-rbac-delegator-vs-contributor.md`, `AWACS_daily-capture_2026-04-30_sas-storage-bug-chain.md`
- **Builds on:** Cascade debugging methodology (prior session); ground truth practice (Chapter 2 themes throughout)
- **Feeds into:** Chapter 7 (Compounding), course case study for Course 1 (AI-Assisted Infrastructure), product README proof section
