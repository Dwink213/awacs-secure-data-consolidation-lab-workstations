# Daily Capture: The IaC-Reality Inversion Anti-Pattern
**Date:** 2026-05-09
**Session source:** AWACS Secure Lab Backup — doc audit session; pattern named from ADR-008 inversion

---

## What Happened

During a doc audit session, the ADR for component 08 (SAS Rotator) was found to have its Decision and Alternatives sections completely inverted: it recorded the rejected design (Azure Functions) as the chosen approach, and the actual live system (Azure Automation Account) as the approach that was "viable but rejected." This is a new named anti-pattern: **IaC-Reality Inversion** — when AI-generated documentation captures the planned design at decision time, the pivot happens during implementation, and the ADR is never updated. The result is a document that is authoritative, well-structured, and confidently wrong. More dangerous than a missing doc.

---

## Social Potential

**LinkedIn viable:** Yes
**Hook angle:** There's a doc failure mode more dangerous than "docs are missing." It's "docs say the opposite of what's true." We found one. Here's what it looks like.
**Target audience:** Engineering managers, platform engineers, DevOps practitioners, anyone using AI for infrastructure documentation
**Post type:** Teaching / Hot take
**Emotional driver:** Recognition + fear — this pattern is widespread and under-named
**Priority:** High

**Draft hook options:**
1. "There's a category of doc error worse than outdated: Inverted. The ADR says Azure Functions. The live system runs Automation Account. Both written by AI. One of them is wrong — and it's confidently wrong."
2. "We have a name for docs that are missing. We don't have a good name for docs that are backwards. We do now: IaC-Reality Inversion."
3. "If someone read ADR-008 and tried to maintain this system, they would confidently dismantle the working design to install the broken one. That's the blast radius of an inverted ADR."

**Viral levers present:**
- [x] **Confession arc** — opens with the failure, not the fix
- [x] **Villain-vindication** — AI as the confident documentarian that documented the plan instead of the shipped reality
- [x] **Memeable phrase:** "An inverted ADR is worse than a missing ADR. Missing = unknown. Inverted = confident and wrong."
- [ ] All-caps emotional pivot
- [x] **Specific technical mechanism:** "Decision section = Azure Functions. Alternatives Rejected = Azure Automation Account. Live system = Automation Account. The document is perfectly structured. It's just backwards."
- [x] **Self-incriminating AI quote:** The AI that wrote ADR-008 wrote in the Alternatives table: "Azure Automation runbook — Viable but... adds less cognitive overhead." It was arguing against the thing it built.
- [x] **Comment-bait question:** "Has your documentation ever confidently described a system you didn't build? How did you catch it?"
- [x] **Universal unnamed pain:** The gap between what was planned and what shipped, when AI is moving fast enough to outrun its own documentation

**Lever count:** 7 / 8
**Viral candidate?:** Yes (5+) — this is a strong candidate; 7 levers, universal pain, self-incriminating AI quote is screenshot-worthy

**Notes:** The "self-incriminating AI quote" is the screenshot moment: the AI wrote "Azure Automation runbook — Viable but rejected" in the Alternatives table of an ADR describing the system it built using Azure Automation. That exchange captures the pattern perfectly. Draft carefully — this is content that engineers will screenshot and share.

---

## Training Material

**Training potential:** High
**Could become:** Case study + named anti-pattern definition
**Which course it fits:** Course 2 (Methodology) — the discipline of verification; Course 3 (Advanced Patterns) — managing AI-generated artifacts
**Teaching point:** AI generates documentation that is coherent with its context at the time of writing, not with the reality at the time of shipping. When AI is moving fast (overnight build sessions, context compaction, multi-session work), the gap between planned and shipped widens. The named anti-pattern gives students a pattern to look for and catch.

**Prerequisite knowledge:** AI-assisted infrastructure development; basic ADR workflow; understanding that AI has context windows and can't "see" what was deployed after the session ended

**Notes:** This pairs naturally with "ground truth before claiming done" and "ADR audit as part of EOD capture." The anti-pattern should be in the course taxonomy alongside other named failure modes.

---

## Technical Reproduction

**Steps to recreate:**
1. Build component X (Plan A: Azure Functions)
2. Hit a blocker mid-build (quota failure, compatibility issue, etc.)
3. Pivot to Plan B (Azure Automation Account)
4. AI writes the ADR during or near the Plan A phase, before pivot
5. Pivot succeeds; AI deploys Plan B
6. ADR remains from Plan A — never updated by AI or human
7. Next session: someone reads ADR → confidently acts on wrong information

**Why it happens:**
- AI writes ADR when a plan is fresh, not after implementation
- Context compression across sessions loses the "oh we changed this" signal
- ADRs look complete — well-structured, decision/alternatives/trade-offs all present — so they don't trigger manual review
- The only tell is reading Decision + Alternatives together and noticing the live state matches the "rejected" option

**Gotchas:**
- Git log won't help — the ADR was committed before the pivot, so the history looks clean
- The ADR will pass any linting or format-checking tools — the error is purely semantic
- It's undetectable without knowing what actually runs — which requires either a live state check or a doc audit that specifically asks "does the decision match reality?"

**Code/commands to preserve:**
```powershell
# Detection heuristic: check if anything in the Alternatives table
# appears in the live resource group
$alternatives = grep -A20 "Alternatives Considered" docs/decisions/ADR-008*.md
$liveResources = az resource list --resource-group awdust-rg --query "[].type" -o tsv
# If any alternative option appears in liveResources → possible inversion
```

**Related files:**
- `docs/decisions/ADR-008-sas-rotation-automation.md` (before: inverted; after: corrected)

---

## Product Extraction

**Standalone potential:** Maybe
**What it is:** "ADR Coherence Linter" — reads ADR Decision and Alternatives sections, cross-references against live deployed resources (Bicep outputs, Terraform state, az CLI), flags inversions
**Who would use it:** Platform engineering teams, DevOps leads who use AI for infrastructure + documentation
**MVP scope:** A prompt template for a doc-audit pass: "Read this ADR. Now read these deployed resource names. Does the Decision match what's deployed? Does the Alternatives section describe anything that IS deployed?"
**Monetization angle:** Lead magnet (prompt template / checklist) → paid methodology course
**Verdict:** Park for later — the prompt-template MVP is 1 hour of work and could be a lead magnet

---

## Content War Chest Category

- [ ] Proof content
- [x] **Teaching content** — Gives away a named pattern engineers can use
- [x] **Methodology content** — The AWACS discipline of doc auditing caught something most teams miss
- [ ] Product content

**Primary category:** Teaching content

---

## Raw Material

**The self-incriminating AI quote (ADR-008 Alternatives table, pre-fix):**
```
| Azure Automation runbook | Viable but introduces a separate service with its own managed runtime,
  update cycle, and cost model. Functions runtime is already a common pattern;
  adds less cognitive overhead. |
```
*This was written by the same AI that deployed Azure Automation Account as the live system.*

**The inversion signature:**
- ADR Decision section: "Add an Azure Function (component 08)"
- Alternatives Considered: "[Azure Automation runbook] Viable but... rejected"
- Live resource: `awdust-auto-ybmh` — an Azure Automation Account

**Pattern definition (proposed for course taxonomy):**
> **IaC-Reality Inversion**: A documentation failure mode in which the ADR (or equivalent design record) records the planned approach as chosen and the actual shipped approach as rejected. Characterized by: (1) AI-generated documentation, (2) a mid-implementation pivot, (3) no ADR update after pivot. The document appears complete and well-structured — the error is purely semantic.

---

## Next Actions

- [ ] Add "IaC-Reality Inversion" to the AWACS anti-pattern taxonomy (when one is created)
- [ ] Add an "ADR coherence check" step to the brutal critic agent prompt: "For each ADR, confirm the Decision section matches what's live, not what was planned"
- [ ] Draft the LinkedIn post using Hook Option 1 — the self-incriminating AI quote is the screenshot

---

## Cross-References

- **Related captures:** `AWACS_daily-capture_2026-05-09_p1-doc-closure.md` (the fix session), `AWACS_daily-capture_2026-05-08_iac-reality-reconciliation.md` (when the inversion was first caught)
- **Related project files:** `docs/decisions/ADR-008-sas-rotation-automation.md`
- **Builds on:** Brutal critic doc audit pattern (previous sessions)
- **Feeds into:** Course 2 anti-pattern library; "The Anti-Patterns" chapter of the book (Chapter 8)
