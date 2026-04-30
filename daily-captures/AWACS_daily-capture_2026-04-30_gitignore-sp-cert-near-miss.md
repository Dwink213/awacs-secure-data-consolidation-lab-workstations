# Daily Capture: SP Cert Near-Miss — No .gitignore in a Public-Bound Repo
**Date:** 2026-04-30
**Session source:** AWACS secure lab backup — session close-out after context compaction resume

---

## What Happened

After resuming from a context compaction, git status revealed 12 uncommitted artifacts. Before staging, the session agent checked `out/` contents and found `awdust-sp-cert.pem` and `awdust-sp-cert.pfx` — the service principal's private key — sitting in an untracked directory. No `.gitignore` existed in the repo. The project is heading to GitHub as a public repo. One `git add .` would have committed the SP private key to a public repository. A `.gitignore` was written first, `out/` was excluded, and the commit ran cleanly. The certs were never staged.

---

## Social Potential

**LinkedIn viable:** Yes
**Hook angle:** I almost committed a service principal private key to a public GitHub repo. Here's what caught it.
**Target audience:** Azure engineers, DevOps, cloud architects, anyone who's done a "fast deploy"
**Post type:** Story / Teaching
**Emotional driver:** Fear (this happened to me) + relief (it was caught)
**Priority:** High

**Draft hook options:**
1. "No .gitignore. SP private key in out/. Public GitHub repo. One 'git add .' away from a credential leak. Here's what caught it — and it wasn't me being careful."
2. "The most dangerous moment in a new infrastructure repo: the first commit. Here's why."
3. "My deploy script generates the SP cert. My repo had no .gitignore. The cert was sitting in out/. The gap between 'fast deploy' and 'credential leak' was one command."

**Viral levers present:**
- [x] **Confession arc** — "I almost committed a private key to a public repo" is a failure everyone in cloud has come close to
- [x] **Villain-vindication structure** — The villain: no .gitignore convention. The fix: explicit pre-commit inspection before first `git add`.
- [x] **Memeable phrase** — "One `git add .` away from a public SP cert."
- [ ] All-caps emotional pivot
- [x] **Specific technical mechanism** — `git status --short` → inspect `out/` contents → write .gitignore → stage specific files by name (not `git add .`)
- [ ] Self-incriminating AI quote
- [x] **Comment-bait question with stored answers** — "What's the closest you've come to committing a credential to a public repo?" Every cloud engineer has a story.
- [x] **Universal unnamed pain** — "The first commit of a new repo is the most dangerous commit." Nobody talks about this but everyone has felt it.

**Lever count:** 5 / 8
**Viral candidate?:** Yes (5+)

**Notes:** Sanitize for public — don't name the subscription ID, app ID, or thumbprint in the post. The story works without them. Pair this with a specific checklist for "pre-first-commit hygiene" to give it teaching value beyond the story.

---

## Training Material

**Training potential:** High
**Could become:** Module / Case study / Exercise
**Which course it fits:** Course 1 (AI-Assisted Infrastructure) — security hygiene in automated deploy workflows
**Teaching point:** Deploy scripts that generate credentials MUST be paired with a `.gitignore` before the first commit. Specifically: any directory that holds generated keys, certs, PFX files, or SAS tokens needs to be in `.gitignore` before the repo is initialized. This is a pre-flight step, not a post-deploy cleanup.
**Prerequisite knowledge:** Git basics, Azure service principals, PEM/PFX cert formats

**Notes:** This pairs well with the "SAS token via --value vs --file" capture — both are in the category of "the deploy worked, but the artifact handling was wrong." Could be one case study: "When the deploy succeeds but leaves a trap."

---

## Technical Reproduction

**Steps to recreate:**
1. Run a deploy script that generates a service principal cert and writes it to `out/` (or any local directory)
2. Do NOT write a `.gitignore` before or during the deploy
3. Prepare to `git add` at session end — check git status
4. Notice untracked files include the cert directory

**The correct sequence:**
1. Before any deploy: write `.gitignore` with generated output directories excluded
2. After deploy: `git status --short` — verify `out/` is not showing as untracked
3. Stage specific files by name: `git add .gitignore STATUS.md deploy/...` — never `git add .` for first commit in a new repo with generated secrets

**Dependencies:**
- Git repo with no .gitignore
- Deploy script that generates credentials to a local directory

**Environment:**
- Any — this pattern applies to any repo with a deploy script that generates local credential artifacts

**Gotchas:**
- `git add .` stages everything untracked, including cert files — never use it without first verifying there are no secrets in untracked files
- `.gitignore` must be written BEFORE any `git add` or staging of the directory containing secrets — once staged, `.gitignore` won't untrack the file without `git rm --cached`
- PowerShell 5.1 `New-Object System.Text.UTF8Encoding $false` → PFX/PEM are binary; this is a general reminder that `out/` shouldn't exist in the repo at all

**Code/commands to preserve:**
```
# Pattern: inspect before staging
git status --short
ls out/  # or: Get-ChildItem out/

# If secrets found: write .gitignore first
echo "out/" >> .gitignore
echo ".claude/" >> .gitignore

# Stage specific files, never git add .
git add .gitignore STATUS.md daily-captures/ docs/ workstation/bootstrap.ps1 workstation/push-files.ps1

# Verify out/ is now ignored
git status --short  # out/ should not appear
```

**Related files:** `.gitignore` (created this session), `out/awdust-sp-cert.pem`, `out/awdust-sp-cert.pfx`, `out/awdust-workstation-config.json`

---

## Product Extraction

**Standalone potential:** Maybe — as a checklist/pre-commit hook pattern, not a standalone product
**What it is:** A pre-commit inspection pattern for repos with deploy-generated credential outputs
**Who would use it:** Anyone deploying infrastructure with an automated cert or key generation step
**What it needs for GitHub:**
- [ ] Could be a `pre-commit` hook script that checks for common credential file extensions (*.pem, *.pfx, *.key) in untracked files

**MVP scope:** A one-page "first commit checklist" for Azure infra repos
**Monetization angle:** Lead magnet / teaching content — not a product on its own
**Competitors/alternatives:** `git-secrets`, `trufflehog`, pre-commit hooks — all exist but require knowing to install them. The gap is: what do you do on session 1, before any tooling is installed?
**Verdict:** Explore further — as a section of the AWACS deployment checklist, not a standalone product

---

## Content War Chest Category

- [x] **Proof content** — Real near-miss, real repo, real cert type
- [x] **Teaching content** — Specific inspection pattern with commands
- [x] **Methodology content** — Pre-commit hygiene as a discipline practice

**Primary category:** Teaching content

---

## Raw Material

**Git status at discovery:**
```
?? .claude/
?? STATUS.md
?? daily-captures/
?? deploy/main.json
?? out/
```

**Out/ contents at discovery:**
```
out/awdust-sp-cert.pem   (2,722 bytes) — RSA private key + cert chain
out/awdust-sp-cert.pfx   (2,435 bytes) — PFX format with private key
out/awdust-workstation-config.json — tenant ID, client ID, thumbprint
```

**Action taken:**
1. `.gitignore` written: excludes `out/`, `.claude/`, `*.tmp`, `*.bak`
2. Files staged by explicit name: no `git add .` used
3. Committed cleanly: `b25b8e9` — 12 files, `out/` not present

**Post-commit git status:**
```
# clean working tree — no untracked secrets
```

---

## Next Actions

- [ ] Add pre-commit inspection to the RUNBOOK.md under "First-time repo setup" — document the `git status → inspect dirs → .gitignore first` sequence
- [ ] Consider a `deploy/preflight.sh` check: if `out/` exists and `.gitignore` does not contain `out/`, warn the operator before proceeding
- [ ] LinkedIn post: "One `git add .` away from a public SP cert" — high viral candidate, write carefully

---

## Cross-References

- **Related captures:** `AWACS_daily-capture_2026-04-30_sas-storage-bug-chain.md` — same category: "deploy succeeded but artifact handling was wrong"
- **Related project files:** `.gitignore`, `deploy/Deploy.ps1`, `out/` (excluded from repo)
- **Builds on:** Session 2026-04-30 deploy artifacts; no prior captures on this topic
- **Feeds into:** RUNBOOK.md "First-time repo setup" section; Course 1 security hygiene module; LinkedIn post
