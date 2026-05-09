# Daily Capture: P1+P2 Documentation Closure Post Brutal Critic
**Date:** 2026-05-09
**Session source:** AWACS Secure Lab Backup — continuation session after brutal critic returned 5.3/10 doc score

---

## What Happened

The brutal critic from the previous session identified 10 P1 (factually wrong) and 9 P2 (stale/incomplete) documentation gaps after component 08 (SAS Rotator) was built. The most critical was ADR-008 recording Azure Functions as the chosen design and Azure Automation Account as the rejected alternative — the exact inverse of what was deployed. This session closed all 11 P1 and P2 items: complete ADR-008 rewrite, README.md corrections (false "SAS rotator not included" limitation, missing 08-sas-rotator/ in repo map, "daily-rotated" language), architecture diagram updates (Z9 trust zone added to 3 diagrams, SAS lifetime fixed from 24h to 6d 23h everywhere), and GLOSSARY, RUNBOOK, tests/scripts/README fixes. All shipped in a single commit.

---

## Social Potential

**LinkedIn viable:** Yes
**Hook angle:** My AI wrote an ADR that confidently recorded the rejected design as the decision. Future engineers would have dismantled the correct system to install the broken one.
**Target audience:** Platform engineers, DevOps leads, AI practitioners using AI for IaC and documentation
**Post type:** Story
**Emotional driver:** Recognition + fear — "this has happened to me" for engineers who've inherited docs that don't match reality
**Priority:** High

**Draft hook options:**
1. "The ADR said: Azure Functions chosen. Azure Automation Account rejected. The live system ran Automation Account. Both were written by AI. One of them was wrong — and it wasn't the one you'd expect."
2. "An inverted ADR is worse than a missing ADR. Missing = unknown. Inverted = confident and wrong. Here's how we found it."
3. "The brutal critic gave the docs a 5.3/10. The highest-priority finding: the decision record for our biggest recent change had the decision backwards. Not outdated. Backwards."

**Viral levers present (from checklist above):**
- [x] **Confession arc** — leads with a doc audit failure, not a flex. The ADR recorded the wrong answer.
- [x] **Villain-vindication structure** — the AI that wrote the ADR is the villain (it recorded what was planned, not what shipped); the audit process is the fix
- [x] **Memeable phrase:** "An inverted ADR is worse than a missing ADR. Missing = unknown. Inverted = confident and wrong."
- [ ] All-caps emotional pivot
- [x] **Specific technical mechanism:** "ADR-008 recorded Azure Functions as Decision and Azure Automation as rejected — the exact inverse of what runs in production"
- [ ] Self-incriminating AI quote
- [x] **Comment-bait question with stored answers:** "Has your AI assistant ever written docs that confidently described what you *planned* instead of what you *built*? How did you find it?"
- [x] **Universal unnamed pain:** AI-generated docs that are authoritative about the wrong thing — more dangerous than missing docs

**Lever count:** 5 / 8
**Viral candidate?:** Yes (5+)

**Notes:** The memeable phrase is quotable and travels independently. The comment-bait question is one every engineer working with AI codegen will have a lived answer to. Consider pairing with a screenshot of the ADR before/after.

---

## Training Material

**Training potential:** High
**Could become:** Case study + exercise
**Which course it fits:** Course 2 (Methodology — the discipline of verification)
**Teaching point:** AI-generated documentation captures intent at the time of writing, not reality at the time of shipping. The faster AI moves through implementation, the wider the gap between what was planned and what was built. The discipline practice: run a doc audit (brutal critic or equivalent) after every major implementation, before declaring done.
**Prerequisite knowledge:** Basic understanding of ADRs (Architecture Decision Records), AI-assisted development workflow

**Notes:** This is a natural pairing with the "IaC-reality inversion" capture from this session. Together they form a two-part lesson: (1) how it happens, (2) how to catch it and fix it.

---

## Technical Reproduction

**Steps to recreate:**
1. Build a component via AI agent, pivoting mid-build from Plan A to Plan B (e.g., Azure Functions → Automation Account due to quota failure)
2. Have AI generate the ADR at or near the time of Plan A
3. Ship Plan B without updating the ADR
4. Run a brutal critic doc audit 1+ sessions later
5. Observe the inversion: ADR Decision = Plan A, Alternatives = Plan B (rejected)

**Dependencies:**
- AI code assistant with documentation generation capability
- ADR (Architecture Decision Record) workflow
- A doc audit mechanism (brutal critic, peer review, or equivalent)

**Environment:**
- Any cloud infrastructure project; this instance was Azure IaC (Bicep) + AWACS methodology

**Gotchas:**
- The inversion is not obvious to catch manually — it requires reading both the Decision AND Alternatives sections together
- Git blame won't help if the AI wrote the ADR in one commit and the pivot happened in a later commit
- The ADR will parse correctly and look complete — the error is semantic, not structural

**Code/commands to preserve:**
```
# The 3 grep checks that confirmed the inversion:
grep -A5 "## Decision" docs/decisions/ADR-008-sas-rotation-automation.md
grep -A10 "## Alternatives" docs/decisions/ADR-008-sas-rotation-automation.md
# If Decision says Plan A and Alternatives Rejected says Plan B — you have an inversion.
```

**Related files:**
- `docs/decisions/ADR-008-sas-rotation-automation.md` (rewritten)
- `README.md` (4 fixes)
- `architecture/system-diagram.md`, `component-map.md`, `trust-boundaries.md`, `README.md` (Z9 + component 08 additions)
- `GLOSSARY.md`, `RUNBOOK.md`, `tests/scripts/README.md`, `deploy/README.md`, `components/02-key-vault/README.md`

---

## Product Extraction

**Standalone potential:** Maybe
**What it is:** A "doc coherence checker" that reads a set of ADRs and cross-references them against the live codebase/IaC to flag inversions, stale references, and missing components.
**Who would use it:** Engineering teams using AI for architecture decisions + IaC generation
**What it needs for GitHub:**
- [ ] Parser that extracts Decision and Alternatives sections from ADR files
- [ ] Comparison logic against deployed resource names (from terraform state, bicep outputs, or az CLI)
- [ ] Output: "ADR-008 Decision says X; live state says Y — possible inversion"

**MVP scope:** Shell script that reads ADR Decision sections and greps for those terms in the live Bicep/Terraform output — flags mismatches for human review
**Monetization angle:** Lead magnet / open source credibility
**Competitors/alternatives:** Nothing purpose-built for ADR inversion detection; closest is ADR tooling (adr-tools) which has no semantic checking
**Verdict:** Park for later — the pattern is worth naming but the tooling is a nice-to-have, not urgent

---

## Content War Chest Category

- [x] **Proof content** — Shows you can do the work (ran a doc audit, found a critical inversion, fixed it)
- [x] **Teaching content** — Gives away knowledge (the pattern has a name now: IaC-reality inversion)
- [x] **Methodology content** — Your unique approach (brutal critic → prioritized gap list → systematic closure)
- [ ] Product content

**Primary category:** Methodology content

---

## Raw Material

**The inversion, verbatim (ADR-008 before fix):**
```
## Decision
Add an Azure Function (component 08) with a system-assigned Managed Identity...

## Alternatives Considered
| Azure Automation runbook | Viable but introduces a separate service with its own managed runtime, update cycle,
  and cost model. Functions runtime is already a common pattern; adds less cognitive overhead. |
```

**What actually runs:**
- Azure Automation Account `awdust-auto-ybmh`, Free SKU
- No Function App, no App Service Plan, no Function storage account
- PowerShell runbook uploaded via REST API (not Bicep)

**Brutal critic finding (verbatim):**
> "ADR-008 is the most factually compromised ADR in the repository. It records the wrong decision."

**Commit message (the fix):**
```
docs(P1+P2): fix all stale references to Azure Functions and 24h SAS after component 08 pivot

ADR-008 complete rewrite: Decision section now correctly records Azure Automation Account
as chosen; Azure Functions moved to Alternatives Considered as rejected (quota failure).
```

---

## Next Actions

- [ ] Draft LinkedIn post using Hook Option 2 + the memeable phrase — screenshot of ADR before/after
- [ ] Add "ADR inversion check" to the end-of-component checklist in CLAUDE.md
- [ ] Consider a "doc coherence" step in the brutal critic agent prompt

---

## Cross-References

- **Related captures:** `AWACS_daily-capture_2026-05-08_iac-reality-reconciliation.md` (the build session that created the inversion), `AWACS_daily-capture_2026-05-08_sas-rotation.md` (the component 08 build)
- **Related project files:** `docs/decisions/ADR-008-sas-rotation-automation.md`, `threat-model.md` §2 (Z9)
- **Builds on:** Brutal critic doc audit from previous session
- **Feeds into:** "The IaC-Reality Inversion Anti-Pattern" capture (this session), Course 2 methodology curriculum
