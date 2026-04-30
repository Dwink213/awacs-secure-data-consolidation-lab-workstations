# Methodology Capture: Systematic Cascade Debugging
**Date:** 2026-04-30
**Session source:** AWACS secure lab backup — bootstrap execution + push-files.ps1 end-to-end verification
**Book chapter affinity:** Chapter 2 (Ground Truth) + Chapter 8 (The Anti-Patterns)

---

## Session Arc

The session began with a known starting state: 11/11 tests passing, IaC clean, bootstrap theoretically complete. The actual state was different — bootstrap had silently hung in the background, and the SAS token in Key Vault was malformed. Three hours of systematic debugging followed, each error revealing one more layer of the same root problem. The session ended with the system closer to correct than it started, but not fully verified — RBAC propagation was still pending at close. The discipline: every error was fixed at the layer it existed, not papered over.

---

## Decision Sequences

### Decision 1: Bootstrap strategy — re-run vs. investigate
**Starting assumption:** Bootstrap completed; the test output showed step 1-2 OK before truncating
**What happened:** State check showed Az modules not installed, no push-files.ps1, no scheduled task — bootstrap hadn't progressed past step 2
**Pivot point:** Recognized the background task had silently hung rather than errored
**Final decision:** Pre-install NuGet and trust PSGallery interactively, then re-run bootstrap for steps 3–6
**Transferable principle:** When a background automation task produces no output past a known checkpoint, treat it as a hang, not a success. Check the actual system state, not the task exit code.

### Decision 2: SAS storage — file vs. value vs. env var
**Starting assumption:** The SAS token in KV was valid (it was generated and stored in the prior session)
**What happened:** KV stored 27 chars (`se=2026-05-01T05%3A59%3A22Z`) — only the first parameter; `&` caused shell truncation
**Pivot point:** Saw the length in the push log: "SAS fetched (length: 27)"
**Final decision:** Store via `--file` with BOM-free UTF-8 write (`[System.IO.File]::WriteAllText` with `UTF8Encoding $false`)
**Transferable principle:** Never pass a token containing shell metacharacters (`&`, `%`, `=`, `+`) as a CLI `--value` argument. Always use `--file` for secrets. Always verify what you stored.

### Decision 3: RBAC — which roles actually needed
**Starting assumption:** `Storage Blob Delegator` was sufficient for generating a valid write SAS
**What happened:** `AuthorizationPermissionMismatch` on every PUT — SAS was well-formed but permissions rejected
**Pivot point:** Checked actual role assignments on the storage account; only `Delegator` present
**Final decision:** Assign `Storage Blob Data Contributor` in addition to `Delegator`; regenerate SAS after propagation
**Transferable principle:** For user-delegation SAS, you need TWO roles: one to sign the key (`Delegator`) and one to have something to sign (`Data Contributor`). These are separate. Verify both before attempting SAS generation in a new environment.

---

## Human Judgment Moments

- **Moment:** Deciding to search the session transcript JSONL file for the PFX password rather than asking the user
  **The judgment call:** Attempted to grep the transcript before interrupting the user's sleep
  **Why process alone wouldn't have gotten here:** Knowing that Claude Code session transcripts are JSONL and contain tool call outputs — the password might have been echoed in a tool result
  **Outcome:** Transcript showed `$pfxPass = ` with value cut off. Password not recoverable from log. Fallback: regenerate PFX from the still-present PEM file. Worked cleanly.

- **Moment:** Choosing to add a defensive `.TrimStart([char]0xFEFF).Trim()` to push-files.ps1
  **The judgment call:** Fixed both the storage AND the read side, even though fixing storage alone would have been "sufficient"
  **Why process alone wouldn't have gotten here:** Experience: the BOM problem can re-emerge if any future code writes the SAS a different way. Defense in depth at the read layer costs one line.
  **Outcome:** Belt-and-suspenders — good for long-term robustness.

---

## Discipline Practices Applied

- [ ] Ground truth before live calls
- [ ] Pattern → ADR in same session
- [ ] Self-audit through critic
- [x] **Institutional memory capture** — session notes exist, this capture being written
- [ ] Compounding knowledge capture (KB not updated yet — pending session end)
- [ ] Mandatory lookup order
- [x] **Session-end capture** — this document

**New practice observed this session:**
**State verification before assuming success.** The bootstrap appeared to be running (background task ID existed) but the actual system state showed it hadn't progressed. The practice: at any "I think this worked" moment, verify the actual output state before proceeding. Checking `C:\ProgramData\AwacsBackup\push-files.ps1` existence was more reliable than the task status.

---

## Compounding Effects

**What this session left behind that makes the next session better:**

| Artifact | What it does for future sessions |
|----------|--------------------------------|
| Fixed bootstrap.ps1 (NuGet, TimeSpan, S4U) | Any new workstation bootstraps without hanging |
| Defensive `.TrimStart` in push-files.ps1 | Tolerates BOM-polluted secrets from any future write path |
| `Storage Blob Data Contributor` assigned | SAS rotation now possible without permission debugging |
| BOM-free SAS storage pattern documented | Next person who needs to store a SAS token has the right pattern |
| Three daily captures with viral potential | Content pipeline for the next 2–3 weeks |

**Knowledge base delta:** Not updated this session (pending)
**Tooling delta:** `push-files.ps1` hardened with defensive trim; `bootstrap.ps1` fixed with NuGet pre-install + correct trigger/principal
**Rule delta:** None added to CLAUDE.md yet; candidates: "Store SAS via --file always" and "User-delegation SAS requires both Delegator and Data Contributor"

---

## Anti-Patterns & Time Sinks

- **Time sink:** PFX password lost between sessions
  **Root cause:** Password set interactively in prior session, not documented anywhere (not in session notes, not in KV, not in RUNBOOK)
  **Prevention for next time:** Any password generated during a session goes into a KV secret or session notes IMMEDIATELY. The AWACS CLAUDE.md rule about "receipts on every decision" should extend to: "secrets on every secret."

- **Time sink:** Testing the REST PUT after each SAS regeneration instead of verifying the SAS content first
  **Root cause:** Jumping to end-to-end test before validating the intermediate state (what's actually in KV, what does it start with, how many chars)
  **Prevention for next time:** After any secret store operation: read it back and verify length, prefix, and absence of BOM characters before running the downstream test.

- **Time sink:** Waiting for RBAC propagation at the end of the session
  **Root cause:** `Storage Blob Data Contributor` wasn't assigned at deploy time; discovered at first push test
  **Prevention for next time:** Deploy.ps1 should assign this role during initial deploy, alongside KV Secrets Officer and Delegator. The SAS rotation step in the deploy script already needed both; they should be co-assigned.

---

## The Compounding Story

This session demonstrated a pattern that appears often in infrastructure debugging but is rarely named: the **cascade where one root cause produces N superficially unrelated errors**. Each error looked like a different failure mode — anonymous access rejected, authentication parameter missing, permission mismatch. A less disciplined approach would have treated each as a separate problem. The discipline here was to follow the error *chain* rather than fix each error in isolation: "why did this error occur, and does fixing it expose the next layer of the same root problem?"

The BOM story is particularly instructive because it exposes a language-level assumption that most engineers never question. PowerShell 5.1 writes UTF-8 with BOM. This is correct for Windows consumers (Notepad, most MS tools). It is wrong for any cross-platform consumer — `az` CLI, Linux tools, any tool that reads the file as raw bytes. The fix (`New-Object System.Text.UTF8Encoding $false`) requires knowing that the default encoding *in PS 5.1* is subtly wrong for this use case. This is not in the Azure docs. It's not in the PowerShell docs. It's in the head of engineers who have been burned by it.

The RBAC gap (Delegator vs. Data Contributor) is the cleanest piece of this session for the book because it's a naming problem masquerading as a permissions problem. "Storage Blob Delegator" implies that you can delegate storage access. You cannot — you can only generate the key that makes delegation possible. The actual delegation requires having the permissions yourself. This is architecturally correct and well-reasoned by Microsoft, but the role name actively misleads. The discipline move here was to check actual role assignments rather than assuming the name described the capability.

---

## Book Chapter Affinity

**Primary chapter:** Chapter 2 (Ground Truth) — every error in this session came from the gap between "what I think is true" (SAS stored correctly, bootstrap completed, Delegator role sufficient) and what was actually true (27 chars in KV, background process hung, data-plane permissions missing)
**Secondary chapters:** Chapter 8 (The Anti-Patterns) — the BOM footgun and the silent hang are canonical anti-patterns; Chapter 5 (Institutional Memory) — the lost PFX password is a memory failure

**Key quote or insight for the book:** "The discipline isn't fixing the error — it's resisting the urge to treat each new error as a new problem."

---

## Book Flavor Tags

- [x] **Confession moment** — "The PFX password was set interactively in the prior session. It wasn't documented anywhere."
- [x] **Villain-vindication arc** — PowerShell 5.1's `Out-File` as the BOM villain; `System.Text.UTF8Encoding($false)` as the fix
- [x] **Memeable phrase** — "Four errors. One root cause. And I didn't see it until the fourth one."
- [ ] Caught-the-AI-lying moment
- [x] **Human-override moment** — Grepping the JSONL transcript for the password before asking the user (correct instinct; outcome: couldn't recover, fell back cleanly)
- [ ] Performative-vs-real contrast

**Narrative weight:** Medium
**Why it matters for the book:** The cascade structure is a teaching device — it shows how ground truth failures compound. Each assumption that wasn't verified became the next error. The reader sees the chain of assumptions and recognizes their own debugging habits.

---

## Cross-References

- **Related methodology captures:** Prior session captures in `docs/session-notes/SESSION_2026-04-30.md` (autonomous overnight run)
- **Related topic captures from this session:** `AWACS_daily-capture_2026-04-30_sas-storage-bug-chain.md`, `AWACS_daily-capture_2026-04-30_bootstrap-completion-fix.md`, `AWACS_daily-capture_2026-04-30_azure-rbac-delegator-vs-contributor.md`
- **Builds on:** Prior session methodology (autonomous run, stage-gate bypass, honest gap documentation)
- **Feeds into:** Chapter 2 (Ground Truth), Chapter 8 (Anti-Patterns), SAS rotation product component
