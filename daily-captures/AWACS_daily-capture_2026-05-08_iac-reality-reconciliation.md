# Daily Capture: IaC-to-Reality Reconciliation After Imperative Deploy
**Date:** 2026-05-08
**Session source:** AWACS Secure Lab Backup — component 08 cleanup session, reconciling Bicep + Deploy.ps1 after live imperative deployment

---

## What Happened

After the Azure Automation Account was deployed imperatively (via az CLI + REST API calls directly in the session), the IaC layer — Bicep module and Deploy.ps1 — still described the old approach (Azure Functions + zip deploy). This session's cleanup work identified and closed all the divergences: stale output name (`funcAppName` → `autoAcctName`), wrong Step 5b (zip deploy → REST runbook upload), missing Automation Variables in Bicep, Functions scaffolding in a directory that implied a Functions runtime (`function/` → deleted, replaced with `runbook/`), and a README that described a different product than what was deployed. Every artifact was brought into alignment with the live system before committing.

---

## Social Potential

**LinkedIn viable:** Maybe
**Hook angle:** The Bicep said Azure Functions. The live system said Automation Account. Here's how we found and closed every gap before committing.
**Target audience:** Platform engineers, IaC practitioners, Azure architects
**Post type:** Teaching / Behind-the-scenes
**Emotional driver:** Recognition (the "imperative-first, IaC-second" trap everyone falls into)
**Priority:** Medium

**Draft hook options:**
1. "We deployed it. It worked. Then we read the Bicep. The Bicep lied."
2. "The fastest way to get a system working is imperative deployment. The fastest way to confuse the next engineer is to leave the IaC out of sync."
3. "After an emergency pivot, the live system said one thing. The code said another. Here's the reconciliation checklist."

**Viral levers present:**
- [ ] Confession arc
- [ ] Villain-vindication
- [ ] Memeable phrase: "The Bicep lied." (candidate)
- [ ] All-caps emotional pivot
- [x] **Specific technical mechanism:** module output name mismatch catches (Bicep compile-time error if left uncorrected)
- [ ] Self-incriminating AI quote
- [ ] Comment-bait question
- [x] **Universal unnamed pain:** the imperative-then-IaC gap that everyone creates and nobody fully closes

**Lever count:** 2 / 8
**Viral candidate?:** Normal (0-2)

**Notes:** Better as a teaching post than a viral story. Could anchor a course module on "IaC hygiene after emergency deploys."

---

## Training Material

**Training potential:** High
**Could become:** Module + Exercise
**Which course it fits:** Course 1 (AI-Assisted Infrastructure) — "closing the IaC gap after emergency changes"
**Teaching point:** After any imperative (emergency) deployment, there's always a reconciliation pass. What to audit: module outputs, step comments, directory structure, READMEs, deploy script variable names. The places things hide.
**Prerequisite knowledge:** Basic Bicep, az CLI, understanding of IaC vs. imperative deployment

**Notes:** The specific audit checklist from this session (output names, directory semantics, README truthfulness, step descriptions) is reusable across any IaC stack. High instructional value.

---

## Technical Reproduction

**Steps to recreate:**
1. Deploy something imperatively under time pressure (emergency rotation, quota pivot, etc.)
2. After the immediate fix: read every file that describes the deployed system
3. Enumerate divergences: variable names, output names, directory names, README claims, deploy script steps
4. For each divergence: edit the file to match reality — not reality to match the file
5. Verify: if using Bicep, check that module outputs referenced in orchestrator actually exist in the module

**Dependencies:**
- Any IaC project with an orchestrator (deploy/main.bicep) and module (components/N/main.bicep)
- A recent imperative change that the IaC doesn't reflect

**Environment:**
- Any Azure + Bicep project

**Gotchas:**
- Bicep compile-time catches output name mismatches — but only if you run `az bicep build` or attempt a deploy. Stale output references silently exist in the file until someone tries to use them.
- README truthfulness is the hardest to audit — READMEs lie by omission more than commission. Check: does the runtime section match the actual runtime? Does the verify section point to the right resource type?
- Directory names carry semantic weight — `function/` implies Functions runtime. Rename or delete before committing.
- Deploy script step descriptions are often the last thing updated — "Publishing SAS rotator function..." still says "function" after the pivot.

**Related files:**
- `deploy/main.bicep` — fixed: comment, module 08 comment, output name
- `deploy/Deploy.ps1` — fixed: description, Step 5b entirely
- `components/08-sas-rotator/main.bicep` — added: Automation Variables
- `components/08-sas-rotator/runbook/rotate-sas.ps1` — created: Automation-native runbook
- `components/08-sas-rotator/README.md` — rewritten: Automation Account reality
- `components/08-sas-rotator/function/` — deleted: wrong runtime scaffolding
- `STATUS.md` — updated: SAS state, automation status, resources table, gotchas list

---

## Product Extraction

**Standalone potential:** No
**What it is:** A process, not a product
**Verdict:** Not a product — but strong course material

---

## Content War Chest Category

- [x] **Teaching content** — the reconciliation checklist is reusable
- [x] **Methodology content** — IaC hygiene after imperative changes is a discipline practice

**Primary category:** Teaching content

---

## Raw Material

**Divergences found and fixed in this session:**

| File | What was wrong | What was fixed |
|------|---------------|----------------|
| `deploy/main.bicep` line 2 | "six cloud-side Atomic Legos (01-06)" | "seven" + added 08 |
| `deploy/main.bicep` line 100 comment | "Azure Function + MSI" | "Azure Automation Account + MSI" |
| `deploy/main.bicep` line 124 | `output funcAppName = rotator.outputs.funcAppName` | `output autoAcctName = rotator.outputs.autoAcctName` |
| `deploy/Deploy.ps1` description | "components 01-06" | "components 01-06, 08" |
| `deploy/Deploy.ps1` Step 5b | zip deploy to Function App | REST API upload to Automation Account |
| `components/08-sas-rotator/main.bicep` | No Automation Variables | Added 4 Variables (StorageAccountName, ContainerName, KeyVaultName, SecretName) |
| `components/08-sas-rotator/function/` | Functions scaffolding (host.json, function.json, requirements.psd1, run.ps1) | Deleted entirely |
| `components/08-sas-rotator/runbook/` | Did not exist | Created with `rotate-sas.ps1` (Automation-native) |
| `components/08-sas-rotator/README.md` | Described Azure Functions runtime, verify commands pointed to Function App | Rewritten for Automation Account |
| `STATUS.md` | Stale: old expiry, manual rotation, emergency alert block, missing Automation Account | Updated: automated rotation, correct expiry, new gotchas, Automation Account in resources table |

**Total files touched:** 7 modified, 1 created (runbook), 1 directory deleted (function/)

---

## Next Actions

- [ ] Consider building an "IaC hygiene audit" checklist as a reusable artifact in `docs/`
- [ ] Run `az bicep build deploy/main.bicep` to confirm the updated output references compile cleanly

---

## Cross-References

- **Related captures:** `AWACS_daily-capture_2026-05-08_sas-rotator-build.md` (the build this session is cleaning up)
- **Related project files:** All files in the divergences table above
- **Builds on:** The imperative deployment pattern that necessitated this cleanup
- **Feeds into:** A clean, committable state; course module on IaC hygiene
