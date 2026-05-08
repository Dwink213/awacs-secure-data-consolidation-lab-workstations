# Methodology Capture: Quota Wall + IaC Catch-Up
**Date:** 2026-05-08
**Session source:** AWACS Secure Lab Backup — component 08 build, pivot from Functions to Automation, and IaC reconciliation
**Book chapter affinity:** Chapter 6 — The Human Layer (quota pivot) + Chapter 7 — Compounding (IaC catch-up as a system-leaving practice)

---

## Session Arc

The session started with a planned component (Azure Function SAS rotator) and immediately hit a wall: Dynamic VM quota = 0, Consumption plan refused. Rather than pausing to research alternatives, the AI identified the next viable option (Azure Automation Account, Free SKU, same MSI model) and continued deployment without losing momentum. The runbook was uploaded imperatively — including two REST API workarounds for missing az CLI verbs — and tested live. The session ended not when the system worked, but when the IaC layer was fully reconciled to match what was actually deployed. That second phase — the cleanup — is what makes the work compounding rather than one-off.

---

## Decision Sequences

### Functions → Automation Account pivot

**Starting assumption:** Azure Function Consumption plan (Y1/Dynamic) is the right compute for a timer-triggered, credential-free SAS rotation job. Cheap, serverless, standard pattern.

**What happened:** Bicep deployment failed on App Service Plan creation with "Dynamic VM quota exhausted: 0." Personal/PAYG subscriptions often have this quota at zero. Attempting to increase it via az CLI requires a support ticket and waiting time.

**Pivot point:** The MSI model is not tied to Functions. Any Azure-hosted compute that supports system-assigned identity can call `Connect-AzAccount -Identity`. Azure Automation Account Free SKU qualifies — no Dynamic VM quota, no per-execution cost at this invocation rate (1 run/6 days).

**Final decision:** Azure Automation Account. Free SKU. Same MSI pattern. Same PowerShell runbook logic (minor syntax changes: no `param($Timer)`, `Get-AutomationVariable` instead of `$env:`).

**Transferable principle:** When a planned service hits a quota wall, ask: what does this service provide that I actually need? (MSI-based compute with a timer trigger.) Then find the alternative that provides the same capability without the quota dependency. Don't try to raise the quota when an equivalent exists.

---

### IaC reconciliation sequence

**Starting assumption:** After the imperative deployment worked and was tested, the work was done.

**What happened:** Reading the IaC files revealed 9+ divergences. The module output was named `funcAppName` (Functions-era) but the module now exported `autoAcctName`. `deploy/main.bicep` would have thrown a Bicep compile error on the next deploy. The Deploy.ps1 Step 5b still did a zip deploy to a Function App that no longer existed in the deployment outputs. The `function/` directory implied a Functions runtime. The README described Functions.

**Pivot point:** Committing divergent IaC is not "done" — it's technical debt with a time-bomb. The next engineer (or the next session of this AI) would read the Bicep and believe it describes the live system. It didn't.

**Final decision:** Full reconciliation pass before commit: every file that claims to describe the system must actually describe the system.

**Transferable principle:** The work is done when the IaC is true, not when the system works. A working system with a lying IaC is a liability, not an asset.

---

## Human Judgment Moments

- **Moment:** Quota failure during Functions deployment
  **The judgment call:** Pivot immediately to Automation Account rather than researching quota increase paths or alternative architectures at length
  **Why process alone wouldn't have gotten here:** The quota increase process is a known dead end on personal subscriptions (support ticket, uncertain timeline). The availability of Automation Account as an equivalent was pattern-matched from prior experience with MSI-capable compute types.
  **Outcome:** Correct. Deployment succeeded within the same session, without escalating to support.

- **Moment:** Identifying that the session wasn't done after the runbook tested successfully
  **The judgment call:** Recognize that live system ≠ committed IaC and treat the reconciliation pass as non-optional
  **Why process alone wouldn't have gotten here:** There's no automated check that says "your Bicep output references a module output that doesn't exist." Bicep would catch it at deploy time — but that's the next session's problem, not this session's. The discipline of treating the IaC as the source of truth requires a conscious decision to read the files critically after an imperative change.
  **Outcome:** 9 divergences found and fixed. The commit will be clean.

---

## Discipline Practices Applied

- [x] **Pattern → ADR in same session** — ADR-008 captures the Functions → Automation pivot with full rationale while the context was live
- [x] **Institutional memory capture** — STATUS.md updated; session reference row added; gotchas list extended with 3 new entries
- [x] **Compounding knowledge capture** — README, runbook, Bicep module, and Deploy.ps1 all updated before committing; no "update later" deferred work
- [x] **Session-end capture** — this document

**New practice observed this session:**
**IaC truthfulness audit** — after any imperative deployment that diverges from the planned architecture, enumerate every file that claims to describe the system (Bicep modules, orchestrator, deploy scripts, READMEs, STATUS.md) and verify each claim is still true. Don't commit until the files and the live system agree.

This is distinct from "code review" — it's specifically about semantic truthfulness of architecture descriptions, not code correctness. The question isn't "does this code work?" but "does this file tell the truth?"

---

## Compounding Effects

**What this session left behind that makes the next session better:**

| Artifact | What it does for future sessions |
|----------|----------------------------------|
| `components/08-sas-rotator/runbook/rotate-sas.ps1` | Canonical Automation-native runbook — next deploy uses this directly without reverse-engineering the live config |
| Automation Variables in `main.bicep` | Next deployment is fully declarative for config; no manual variable creation needed |
| STATUS.md — gotchas 8/9/10 | Saves the next session from rediscovering Norton SSL interception, missing az CLI verbs, and JSON encoding requirement |
| ADR-008 | Documents why Functions was rejected and why Automation was chosen — prevents relitigating in a future session |
| `deploy/Deploy.ps1` Step 5b | Any new deployment will wire up the runbook and schedule automatically without manual REST calls |

**Knowledge base delta:** STATUS.md extended; ADR-008 created; component 08 README completely rewritten
**Tooling delta:** `runbook/rotate-sas.ps1` created; `function/` directory deleted; Deploy.ps1 Step 5b correct for Automation
**Rule delta:** None added to CLAUDE.md this session; gotchas captured in STATUS.md instead

---

## Anti-Patterns & Time Sinks

- **Time sink:** The az CLI gaps (missing `runbook replace-content` and `jobSchedules create` verbs) required REST API workarounds. This added complexity to Deploy.ps1.
  **Root cause:** The `azure-cli-automation` extension is incomplete for operational verbs. The az CLI team prioritizes CRUD over operational verbs (content upload, linking operations).
  **Prevention for next time:** When using az automation in a deploy script, check the extension's verb list first. Assume any "action" verb (as opposed to create/delete/show) may require REST. Enumerate before building the deploy step.

- **Time sink:** STATUS.md had accumulated multiple layers of stale state (emergency rotation alert still present after rotation done; SAS expiry from manual rotation, not automation run; missing Automation Account from resources table).
  **Root cause:** STATUS.md was updated mid-session (after manual rotation) but not updated after the subsequent automation deployment. Two partial updates compounded into a document that was half-current.
  **Prevention for next time:** Update STATUS.md exactly once per session, at the end, covering all changes from that session. Mid-session partial updates leave residual stale sections.

---

## The Compounding Story

This session demonstrates what it looks like when a session genuinely closes the loop. The technical work (Automation Account deployment) was completed in the previous session context. This session's work was the discipline work: reading every file that describes the system, finding everything that was no longer true, and fixing it before committing. That's not glamorous. There's no "it worked!" moment in a reconciliation pass — there's only the quiet satisfaction of knowing the next person won't be misled.

The two-phase pattern — imperative-first, declarative-catch-up — is unavoidable in real deployments. The first phase is about getting the system working under time or quota pressure. The second phase is about making the artifacts match the system. Most engineers stop after the first phase. The work "looks done" from the outside. But the IaC has been lying since the moment you pivoted, and it will keep lying until someone reads it carefully. That someone is either you, today, or the next engineer who tries to use your artifacts and finds them describing a product that no longer exists.

The compounding effect is visible here: STATUS.md now has three new gotchas that came directly from this session's pain. The next session that touches az automation will find those gotchas waiting — won't hit the missing-verb wall, won't have to rediscover the JSON encoding requirement for Automation Variables, won't be surprised by Norton blocking Azure CLI. Each piece of captured pain becomes a future session's saved time. That's the compounding effect.

---

## Book Chapter Affinity

**Primary chapter:** Chapter 7 — Compounding ("How does each session make the system more capable?")
**Secondary chapters:** Chapter 6 (The Human Layer — quota pivot as pattern-matched human judgment), Chapter 3 (Formalize While Fresh — ADR written in the same session as the decision)
**Key quote or insight for the book:** "The work is done when the IaC is true, not when the system works. A working system with a lying IaC is a liability, not an asset."

---

## Book Flavor Tags

- [ ] Confession moment
- [x] **Villain-vindication arc** — the az CLI gaps are the villain; REST API workarounds are the vindication; the reconciliation pass is the full close
- [ ] Memeable phrase
- [ ] Caught-the-AI-lying moment
- [x] **Human-override moment** — the human decided the session wasn't done after the runbook tested successfully; process alone (declare victory when system works) would have stopped earlier
- [ ] Performative-vs-real contrast

**Narrative weight:** Medium
**Why it matters for the book:** The reconciliation-pass habit is the specific practice that separates compounding work from accumulating debt. This session's flavor shows what that habit looks like in execution — not as a theory but as a concrete sequence of edits with a reason behind each one.

---

## Cross-References

- **Related methodology captures:** `AWACS_daily-capture_2026-05-08_methodology.md` (s1 — split-brain trust model, layered diagnosis) — same session day, different phase
- **Related topic captures from this session:** `AWACS_daily-capture_2026-05-08_sas-rotator-build.md`, `AWACS_daily-capture_2026-05-08_iac-reality-reconciliation.md`
- **Builds on:** The discipline of "system-leaving" introduced in earlier sessions — leave the system better than you found it
- **Feeds into:** Chapter 7 (Compounding) raw material; Course 1 module on IaC hygiene after emergency deploys
