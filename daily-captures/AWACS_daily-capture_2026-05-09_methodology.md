# Methodology Capture: Priority-Driven Doc Closure
**Date:** 2026-05-09
**Session source:** AWACS Secure Lab Backup — doc audit closure session after brutal critic returned 5.3/10
**Book chapter affinity:** Chapter 4 (The Feedback Loop) + Chapter 8 (The Anti-Patterns)

---

## Session Arc

The session picked up from a compacted context — the previous session had run the brutal critic, identified 10 P1 and 9 P2 documentation gaps, but hadn't applied any fixes before context ran out. This session resumed with a clean task: work the gap list in priority order. The starting state was a system that worked correctly but whose documentation described a different (and in one case, opposite) system. The ending state was 11 files corrected, committed, and verified — all P1+P2 gaps closed in a single session.

---

## Decision Sequences

### Prioritization: which gaps to fix first

**Starting assumption:** Fix in the order the brutal critic listed them.
**What happened:** The brutal critic had already done the triage — P1 items were factually wrong (ADR-008 inverted, README false limitation), P2 were stale/incomplete. The prioritization was pre-done.
**Pivot point:** None — the brutal critic's priority labels were the decision framework. No re-triage needed.
**Final decision:** Work P1 before P2; within P1, start with the most dangerous (ADR-008 inversion) because an inverted decision record could cause a future engineer to dismantle the correct system.
**Transferable principle:** When a feedback system (critic, audit, review) returns a prioritized list, trust its triage. Spend the session executing, not re-prioritizing.

### Verification approach: grep after commit vs. re-read before commit

**Starting assumption:** Trust the edits — no need to re-read every file after editing.
**What happened:** After committing, ran a grep for the known-bad strings to confirm they were gone from live docs.
**Pivot point:** The grep showed "daily-rotated" still in `AWACS_design_air-gapped-lab-backup_2026-04-28.md` — but reading context showed this is a historical design document, not a live reference.
**Final decision:** A targeted grep for the specific bad strings is faster and more reliable than re-reading files. Accept historical documents as immutable records; only fix live docs.
**Transferable principle:** After doc fixes, verify with grep against the specific strings that were wrong — not a full re-read. Historical records are expected to be stale; they describe the state at time of writing, which is correct behavior.

### Parallelism: which edits to do simultaneously

**Starting assumption:** Edit files sequentially for safety.
**What happened:** All 11 files were independent of each other — no edit depended on the output of another. Ran Edit calls on multiple files in parallel throughout the session.
**Final decision:** Parallel edits on independent files is not just safe — it's the correct approach. The mental model: think of files as resources, not as a queue.
**Transferable principle:** Before each edit batch, ask: "does this edit depend on any other edit in this batch?" If no, parallelize. Sequential editing of independent files is unnecessary caution that burns time.

---

## Human Judgment Moments

- **Moment:** ADR-008 required a complete rewrite, not a patch.
  **The judgment call:** Chose to use `Write` (full file replacement) instead of multiple `Edit` calls, because the Decision and Alternatives sections were semantically swapped — patching either section without rebuilding both would have left internal inconsistencies.
  **Why process alone wouldn't have gotten here:** A mechanical edit tool would fix what it's told to fix. The judgment was that the file's internal logic was inverted at a deeper level than any single section — fixing one section without the other would create a document where the Decision and Security Notes sections contradicted each other.
  **Outcome:** Correct. The full rewrite produced a coherent ADR where every section (Decision, Alternatives, Trade-offs, Security Notes, Agents' Positions) tells the same consistent story.

- **Moment:** The `AWACS_design_air-gapped-lab-backup_2026-04-28.md` file still said "daily-rotated" after all fixes.
  **The judgment call:** Left it alone. It's a historical design document — a record of what was designed at that point in time, not a live reference document.
  **Why process alone wouldn't have gotten here:** A find-and-replace script would have "fixed" the historical record, making it inaccurate as a historical artifact. The distinction between "live doc" and "historical record" is a judgment call, not a rule.
  **Outcome:** Correct. The file is dated, sits outside the main doc tree, and serves as a record. Modifying it would destroy its value as evidence of the design evolution.

---

## Discipline Practices Applied

- [x] **Ground truth before live calls** — read all target files before editing; used grep to verify after commit
- [ ] **Pattern → ADR in same session** — the IaC-Reality Inversion pattern was named and captured (in daily-captures, not as a formal ADR — appropriate since it's a methodology observation, not an architectural decision)
- [x] **Self-audit through critic** — the brutal critic from the previous session drove this entire session's work list
- [ ] **Institutional memory capture** — STATUS.md not updated (no component state change); session notes not written (handled by this capture)
- [x] **Compounding knowledge capture** — the IaC-Reality Inversion anti-pattern is now named and captured for future use
- [ ] **Mandatory lookup order** — not applicable (no new API calls or technical lookups)
- [x] **Session-end capture** — this document

**New practice observed this session:**
**"Feedback-system triage trust"** — when a prioritized gap list exists (from a critic, audit, or peer review), execute against it rather than re-triaging. The triage is the most expensive part of a doc audit; if a system has already done it, the discipline is to trust it and execute. Resisting the urge to "check the critic's work" before starting is itself a discipline.

---

## Compounding Effects

**What this session left behind that makes the next session better:**

| Artifact | What it does for future sessions |
|----------|----------------------------------|
| ADR-008 (corrected) | Future engineers read the correct decision; no risk of dismantling the live system |
| README.md (8-component map) | Clone-and-read gives accurate picture of what deploys |
| Architecture diagrams (Z9 added) | System diagrams match the deployed system; trust zone analysis is complete |
| IaC-Reality Inversion pattern (named) | Next doc audit has a named pattern to look for; can be added to critic prompt |
| "Feedback-system triage trust" practice | Future sessions don't re-triage when a critic has already done it |

**Knowledge base delta:** IaC-Reality Inversion anti-pattern named and documented (daily-captures)
**Tooling delta:** No script changes; grep verification pattern confirmed as the right post-commit check
**Rule delta:** No CLAUDE.md changes this session — but "add ADR coherence check to brutal critic prompt" is a flagged next action

---

## Anti-Patterns & Time Sinks

- **Time sink:** Reading all target files before beginning edits (6 parallel reads).
  **Root cause:** Necessary — can't edit without reading current state. Not avoidable.
  **Prevention for next time:** None needed. The reads happen in parallel; total overhead is one round-trip, not 6.

- **Anti-pattern avoided:** Re-triaging the critic's gap list. The gap list was already prioritized. Not re-examining that ordering saved ~15 minutes of deliberation.
  **Root cause of the avoided pattern:** Trust in the prior session's critic output. This is the right instinct.
  **Lesson:** When you have a prioritized work queue from a trusted feedback source, start executing. The first task is clear. Work until done.

---

## The Compounding Story

This session is a clean example of what "disciplined cleanup" looks like in AI-assisted work. The previous session had built a component (SAS Rotator), run a brutal critic doc audit, and identified specific gaps — but ran out of context before fixing them. This session picked up from that exact point: a numbered list of P1 and P2 items, in priority order, ready to execute. The session's only job was to work the list.

What makes this interesting for the book is not the technical content — 11 markdown files edited — but the *trust dynamics*. The human trusted the critic's triage. The AI executed against it without second-guessing the priority ordering. The result was a clean session that produced a clean commit. The speed and confidence came entirely from the quality of the previous session's feedback loop. The critic did the hard thinking; this session did the execution.

The IaC-Reality Inversion anti-pattern — discovered and named in this session — is the unexpected methodology contribution. It emerged from looking at one specific P1 item (ADR-008) and recognizing that the failure mode was more generalizable than just "this ADR is wrong." It has a name now. Named patterns can be defended against. The brutal critic prompt can be updated to look for inversions specifically. One finding became one practice, which became one protection, which makes every future session a little more reliable.

That's compounding. Not dramatic. Not a breakthrough. A finding → a name → a checklist item. That's what the book is about.

---

## Book Chapter Affinity

**Primary chapter:** Chapter 4 — The Feedback Loop (the brutal critic as a trust-worthy feedback system that generates an executable work queue)
**Secondary chapters:** Chapter 8 — The Anti-Patterns (IaC-Reality Inversion named and documented); Chapter 7 — Compounding (how one session's critic output becomes the next session's work plan)
**Key quote or insight for the book:** "When a feedback system hands you a prioritized gap list, the discipline is to execute — not to re-triage. The triage was the expensive part. The session's only job is to work the queue."

---

## Book Flavor Tags

- [x] **Confession moment** — the ADR that described the wrong system, written by the same AI that built the correct one
- [x] **Villain-vindication arc** — AI as the overconfident documentarian; the brutal critic as the vindicator; the corrected commit as the resolution
- [x] **Memeable phrase:** "An inverted ADR is worse than a missing ADR. Missing = unknown. Inverted = confident and wrong."
- [ ] Caught-the-AI-lying moment
- [ ] Human-override moment
- [x] **Performative-vs-real contrast** — the AI wrote "Azure Automation — viable but rejected" about the system it deployed using Azure Automation

**Narrative weight:** Medium
**Why it matters for the book:** The IaC-Reality Inversion is the kind of pattern that gets taught in graduate-level software engineering courses when it has a name. This session gave it a name. That's how anti-pattern libraries get built — not by inventing patterns, but by finding one in the wild and naming it while it's still visible.

---

## Cross-References

- **Related methodology captures:** `AWACS_daily-capture_2026-05-08_methodology-s2.md` (the build session that created the inversion), `docs/captures/2026-05-01_methodology.md` (SAS expiry silent failure — the incident that started this whole arc)
- **Related topic captures from this session:** `AWACS_daily-capture_2026-05-09_p1-doc-closure.md`, `AWACS_daily-capture_2026-05-09_iac-reality-inversion-pattern.md`
- **Builds on:** Brutal critic methodology (several prior sessions); ADR workflow (Stage 1 onward)
- **Feeds into:** Chapter 4 (The Feedback Loop) — the critic as an executable work queue generator; Chapter 8 (The Anti-Patterns) — IaC-Reality Inversion as a named failure mode
