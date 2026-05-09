# Submission Day Runbook — Anthropic Application

**Purpose:** Single ordered sequence to take the application from current state to submitted, without contradictions, broken links, or stale claims.

**Read this before starting.** Each step has a verification gate. If the gate fails, do NOT proceed to the next step. Stop, fix, retry. The goal is one clean submission, not a fast one.

---

## Pre-flight: confirm current repo state

Before any work, run these in the lab workstation repo to know where you actually are:

```
git status
git log --oneline -20
ls docs/deployment-timeline.md 2>/dev/null && echo "TIMELINE EXISTS" || echo "TIMELINE MISSING"
ls docs/session-notes/ 2>/dev/null
git remote -v
```

Capture the output. If anything looks wrong (uncommitted changes you didn't expect, branch other than main, unexpected commit history), stop and orient before doing anything else.

---

## Step 1: SAS rotator build verification

**Critical path:** Yes. Cannot proceed to Step 2 until verified.

Verify the SAS rotator build completed cleanly. Either:

- **A.** It finished overnight, the new code is committed locally, and pushing to main is safe. Confirm by reading the most recent commit messages and reviewing the diff.
- **B.** It is mid-build. Wait. Do not start any other work in this repo while a Claude Code session is actively writing files. Two writers is a merge conflict waiting to happen.
- **C.** It crashed. Read the session notes in `docs/session-notes/` to see where it stopped. Decide: resume, abandon, or roll back. Do not pretend it succeeded.

**Verification gate:** The repo's working tree is clean (`git status` shows no uncommitted changes), the most recent commits relate to the SAS rotator, and a manual review of the rotator code looks reasonable.

**If gate fails:** do not proceed. Resolve before going to Step 2.

---

## Step 2: Decide whether the rotator is presentable

**Critical path:** Yes.

Read the rotator code. Ask yourself: would I be comfortable if a senior engineer at a frontier AI lab read this file and judged my work by it? Three possible answers:

- **Yes, presentable.** Proceed.
- **No, but the gap is small.** Decide whether to fix in 30 minutes or roll back the rotator and submit without it.
- **No, significantly off.** Roll back. The README's "Limitations honestly named" section already says the rotator isn't included. That framing is intact and credible. A half-built rotator is worse than no rotator.

**Verification gate:** You can articulate in one sentence what the rotator does and how it's invoked, and you would point a reviewer at it without hesitation.

**If gate fails:** roll back the rotator commits with `git revert` (do not force-push history). The README stays accurate. Skip to Step 4.

**Note as of 2026-05-09:** The rotator is built and verified. Component 08 (`components/08-sas-rotator/`) is deployed and running. `awdust-auto-ybmh` Automation Account is live. Step 2 passes.

---

## Step 3: Update Limitations Honestly Named (only if rotator is in)

**Critical path:** Conditional. Only if Step 2 succeeded with rotator presented.

**Note as of 2026-05-09:** Done. Limitation 1 now reads: "SAS rotation is automated via Azure Automation Account (component 08)."

---

## Step 4: Generate or finalize the deployment timeline document

**Critical path:** Yes.

**Note as of 2026-05-09:** `docs/deployment-timeline.md` exists and is complete. The README now references it in both the Status line and the repository map.

---

## Step 5: Update the README

**Critical path:** Yes.

**Note as of 2026-05-09:** README updated in commit `2860216` (P1+P2 doc fixes) and subsequent commits. Status line, repo map, deployment timeline reference, limitation corrections all applied.

---

## Step 6: Update the README's Status line and Repository map

**Critical path:** Yes, but small.

**Note as of 2026-05-09:** Done. Status line now reads: "Deployed and running in production since 2026-04-30. 97+ blobs pushed and counting." Repository map includes `docs/deployment-timeline.md`.

---

## Step 7: Commit and push

**Critical path:** Yes.

```
git add README.md docs/deployment-timeline.md
git commit -m "docs: add forensic deployment timeline; update README with build provenance"
git push origin main
```

**Verification gate:** Commit shows on GitHub. README renders correctly on github.com. Click the link to `docs/deployment-timeline.md` from the README and confirm it resolves.

---

## Step 8: Set GitHub repo metadata for all four repos

**Critical path:** Yes. Empty About boxes are a credibility cost.

For each of these four repos, click the gear icon next to "About" on the repo home page and fill in Description, Topics, and Website:

- `application-anthropic-research-engineer`
- `awacs`
- `claude-production-governance-azure-local`
- `awacs-secure-data-consolidation-lab-workstations`

### `awacs-secure-data-consolidation-lab-workstations`

**Description:** Turnkey Azure backup solution for shared lab workstations — immutable blob storage, cert-based SP auth, automated SAS rotation, CIS-aligned. Deployed and running. Built with AWACS multi-agent methodology.

**Topics:** azure, azure-bicep, azure-blob-storage, azure-automation, infrastructure-as-code, security, compliance, powershell, backup, zero-trust

**Website:** https://awacs.ai

**Verification gate:** All four repo home pages show a description in the About box, at least three topic tags, and a website URL.

---

## Step 9: Verify all links in the cover letter and README

**Critical path:** Yes.

Open every URL that appears in the cover letter and the lab workstation README. In a fresh browser tab. Cold. Confirm each one loads.

URLs to verify:

- https://job-boards.greenhouse.io/anthropic/jobs/4669581008
- https://github.com/Dwink213/awacs-secure-data-consolidation-lab-workstations
- https://github.com/Dwink213/awacs
- https://github.com/Dwink213/claude-production-governance-azure-local
- https://github.com/Dwink213/application-anthropic-research-engineer
- https://github.com/anthropics/claude-code/issues/44707
- https://awacs.ai/case-studies/github-contributions.html
- https://awacs.ai/resume
- https://claude.ai/code/session_01NezFRSrjMc92AufV55826o (verify this works from a private/incognito window)

**Verification gate:** Every link loads to the expected content. No 404s, no broken renders, no "this page is private."

**If any link fails:** fix or remove from the cover letter. A broken link in the cover letter is worse than the link not being there.

---

## Step 10: Draft the Why Anthropic answer

**Critical path:** Yes. Required Greenhouse field.

200 to 400 words. Your own voice. Not Claude-generated. Use the four-question framework:

1. Why Anthropic specifically vs OpenAI / DeepMind / Meta AI?
2. What's the smallest piece of Anthropic's published work I've actually engaged with?
3. What's the bet I'm making by going W2 instead of scaling AWACS?
4. What does long-term benefit of humanity mean to me concretely?

Type the answer into a text editor. Read it out loud. If it sounds like Claude wrote it, rewrite. If it sounds like you, keep going.

**Verification gate:** The answer reads like you when read aloud, contains specific references to Anthropic's published work, and does not name the seven values or quote them back.

---

## Step 11: Submit

**Critical path:** Yes.

Open the Greenhouse application form. Fill in:

- Resume: upload the latest version
- Cover letter: paste cover-letter-build-centered.md contents
- Why Anthropic: paste your answer from Step 10
- Anything else the form asks for

Review the entire application before clicking submit. Read every field as if you were the reviewer. Click submit.

**Log the submission** with: date, role, req number, package version, no response yet.

---

## Step 12: Apply to adjacent roles within 48 hours

**Critical path:** No, but high value.

Same package, lightly retargeted, to one or two of:

- Research Engineer, Model Evaluations
- Senior+ Software Engineer, Research Tools
- Forward Deployed / Solutions / Applied AI

Don't let perfect be the enemy of done. If retargeting takes more than 30 minutes per role, submit as-is.

---

## What to do if something goes catastrophically wrong

If at any point a step fails and the failure cascades:

1. Stop. Do not make it worse by trying to fix in a panic.
2. Roll back to a known-good commit if possible: `git reset --hard <good-commit-sha>` then force-push.
3. The application can wait a day. A broken submission is much worse than a one-day late submission.

---

## Order summary

1. Pre-flight repo state check
2. SAS rotator build verification
3. Decide rotator presentable; possibly roll back
4. Update Limitations section (only if rotator stayed)
5. Generate or finalize deployment timeline document
6. Run README update prompt
7. Update Status line and Repository map manually
8. Commit and push
9. Set GitHub metadata on all four repos
10. Verify all links
11. Draft Why Anthropic answer
12. Submit
13. Apply to adjacent roles

If you skip steps or do them out of order, you risk inconsistency in what reviewers see. The order matters. Each gate exists for a reason.
