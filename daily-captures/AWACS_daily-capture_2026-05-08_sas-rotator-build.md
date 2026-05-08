# Daily Capture: SAS Rotator — Azure Automation Account (Component 08)
**Date:** 2026-05-08
**Session source:** AWACS Secure Lab Backup — session s2, building automated SAS rotation after 6-day manual-rotation outage

---

## What Happened

After a 6-day SAS token expiry outage (2026-05-01 to 2026-05-08) caused by missed manual rotation, component 08 was designed and deployed to automate SAS rotation permanently. The component was originally planned as an Azure Function (Consumption plan), but a Dynamic VM quota of 0 on the personal subscription blocked deployment. Pivoted to Azure Automation Account (Free SKU), which requires no Dynamic VM quota and supports the same system-assigned MSI model. The runbook was deployed, tested live (job 45bb7628 succeeded), and the IaC + Deploy.ps1 were reconciled to match the imperative deployment steps. The system now rotates automatically every 6 days with a 23-hour overlap buffer.

---

## Social Potential

**LinkedIn viable:** Yes
**Hook angle:** My AI assistant planned an Azure Function to fix my backup system. Azure said no (quota = 0). Here's what happened next.
**Target audience:** Platform engineers, Azure architects, IT ops leads, AI-assisted infrastructure practitioners
**Post type:** Story
**Emotional driver:** Recognition (the Azure quota wall), then surprise (MSI without Functions), then satisfaction (it works)
**Priority:** High

**Draft hook options:**
1. "Azure gave me a quota of 0. The plan was right. The service was wrong. Here's how we pivoted in the same session."
2. "The AI designed the perfect Azure Function. Then Azure said: Dynamic VM quota exhausted. So we built the same thing differently — and it cost $0/month."
3. "I asked Claude to build an automated SAS rotator. It built the right architecture. Then reality hit. This is what happened after."

**Viral levers present:**
- [x] **Confession arc** — leads with the outage: 6 days of silent HTTP 403s before anyone noticed
- [x] **Villain-vindication structure** — Azure's Dynamic VM quota is the villain nobody expects; MSI on Automation is the vindication
- [ ] **Memeable phrase:** none yet — candidate: "The plan was right. The service was wrong."
- [ ] **All-caps emotional pivot:** not in this version
- [x] **Specific technical mechanism:** "Azure Automation Account Free SKU — no Dynamic VM quota, same MSI model as Functions"
- [ ] **Self-incriminating AI quote:** no direct quote captured
- [x] **Comment-bait question:** "What Azure quota surprised you at the worst possible moment?"
- [x] **Universal unnamed pain:** quota walls that only appear at deploy time, not during planning

**Lever count:** 4 / 8
**Viral candidate?:** Likely above average (3-4)

**Notes:** Lead with the outage duration (6 days, 18 hours of silent failure) — that's the visceral hook. The quota pivot is the twist. The MSI-on-Automation pattern is the teach. Three-act post.

---

## Training Material

**Training potential:** High
**Could become:** Case study + live demo
**Which course it fits:** Course 1 (AI-Assisted Infrastructure) — "when your planned architecture hits a real constraint"
**Teaching point:** How to handle a constraint discovered at deploy time; when to pivot vs. when to fight the constraint. Also: MSI as a credential-free identity model across Azure compute types.
**Prerequisite knowledge:** Azure Functions basics, Managed Identity concepts, basic Bicep/IaC

**Notes:** The Dynamic VM quota gotcha affects many personal/PAYG subscriptions — high student hit rate. The pivot to Automation Account is non-obvious and teachable. The MSI model being portable across compute types is a durable principle worth embedding.

---

## Technical Reproduction

**Steps to recreate:**
1. Attempt to deploy Azure Function Consumption plan on personal/PAYG subscription — observe quota failure
2. Pivot to Azure Automation Account (Free SKU) — same MSI model, no quota requirement
3. Create Automation Account with system-assigned MSI via Bicep
4. Assign RBAC: Storage Blob Delegator (SA scope) + Storage Blob Data Contributor (container scope) + Key Vault Secrets Officer (secret resource scope)
5. Create Automation Variables: StorageAccountName, ContainerName, KeyVaultName, SecretName (JSON-encoded strings)
6. Upload runbook content via REST API PUT (Content-Type: text/powershell) — az CLI lacks this verb
7. Publish runbook via `az automation runbook publish`
8. Create schedule via `az automation schedule create` (frequency=Day, interval=6)
9. Link runbook to schedule via REST API PUT on jobSchedules — az CLI lacks this verb too
10. Trigger test run: `az automation runbook start`; verify KV secret updated; parse SAS expiry

**Dependencies:**
- Azure subscription with Automation Account resource provider registered
- Az PowerShell modules (Az.Accounts, Az.Storage, Az.KeyVault) — built into Automation runtime
- Bearer token for REST API calls: `az account get-access-token --query accessToken -o tsv`

**Environment:**
- Windows 11, PowerShell 5.1 + Azure CLI
- Azure eastus2 region
- Personal/PAYG subscription with Dynamic VM quota = 0

**Gotchas:**
- `az automation runbook replace-content` does not exist — use REST API PUT with `Content-Type: text/powershell`
- `az automation jobSchedules create` does not exist — use REST API PUT with `Content-Type: application/json`
- Automation Variable string values must be JSON-encoded: `'"${myVar}"'` not `'${myVar}'`
- `Get-AutomationVariable` not `$env:VAR` — Automation Account is not Functions
- PowerShell Automation runbooks use `Write-Output` not `Write-Host` for the Output stream
- `param($Timer)` is Functions syntax — Automation runbooks are plain PS1, no binding parameter

**Code/commands to preserve:**
```powershell
# Runbook content upload via REST (no az CLI equivalent)
$token = (az account get-access-token --query accessToken -o tsv)
$putUri = "https://management.azure.com/subscriptions/$subId/resourceGroups/$rg/providers/Microsoft.Automation/automationAccounts/$acct/runbooks/rotate-sas/draft/content?api-version=2023-11-01"
$content = [System.IO.File]::ReadAllText($runbookPath, [System.Text.Encoding]::UTF8)
Invoke-RestMethod -Method PUT -Uri $putUri -Headers @{ Authorization = "Bearer $token"; 'Content-Type' = 'text/powershell' } -Body $content

# Job schedule link via REST (az CLI missing 'jobSchedule create')
$linkUri = "https://management.azure.com/subscriptions/$subId/resourceGroups/$rg/providers/Microsoft.Automation/automationAccounts/$acct/jobSchedules/$([guid]::NewGuid())?api-version=2023-11-01"
$body = @{ properties = @{ runbook = @{ name = 'rotate-sas' }; schedule = @{ name = 'every-6-days' } } } | ConvertTo-Json -Depth 5
Invoke-RestMethod -Method PUT -Uri $linkUri -Headers @{ Authorization = "Bearer $token"; 'Content-Type' = 'application/json' } -Body $body
```

**Related files:**
- `components/08-sas-rotator/main.bicep` — Automation Account + RBAC + Variables
- `components/08-sas-rotator/runbook/rotate-sas.ps1` — canonical runbook
- `components/08-sas-rotator/README.md` — contract, RBAC, verify commands
- `docs/decisions/ADR-008-sas-rotation-automation.md` — full decision record including pivot
- `deploy/main.bicep` — module 08 wired in
- `deploy/Deploy.ps1` — Step 5b: runbook upload + schedule link

---

## Product Extraction

**Standalone potential:** Maybe
**What it is:** A turnkey Bicep module + Deploy.ps1 snippet for credential-free SAS rotation using Azure Automation Account MSI — works on personal/PAYG subscriptions where Functions Consumption plan fails.
**Who would use it:** Azure engineers on personal subscriptions; labs; dev/test environments; anyone who hit the Dynamic VM quota wall
**What it needs for GitHub:**
- [ ] Parameterized module (no hardcoded names)
- [ ] README with quota failure diagnosis and pivot explanation
- [ ] Example Deploy.ps1 snippet for runbook upload

**MVP scope:** Single Bicep module + runbook PS1 + one-page README explaining the quota pivot pattern
**Monetization angle:** Open source credibility (solves a documented pain point, drives course leads)
**Competitors/alternatives:** Manual rotation scripts; Azure DevOps pipelines; Key Vault rotation policies (not applicable to SAS tokens)

**Verdict:** Explore further — strong lead magnet candidate once this repo is public

---

## Content War Chest Category

- [x] **Proof content** — Shows you can do the work (infrastructure engineering, real constraint navigation)
- [x] **Teaching content** — Gives away the quota-pivot pattern
- [x] **Methodology content** — Real-time pivot on a live system, documented as it happened

**Primary category:** Proof content

---

## Raw Material

> "Dynamic VM quota: 0. The Functions Consumption plan is the runtime we wanted. It is not the runtime we can have today. Automation Account, Free SKU, same MSI — let's build."

**Job output (verbatim from live test):**
- Job ID: 45bb7628
- Status: Completed
- SAS expiry updated to: 2026-05-15T21:41:03Z
- Secret length: 272 chars

**Key discovery:** The `az automation` CLI extension exists but is incomplete. Two critical operations — runbook content upload and job schedule linking — require direct REST API calls. The az CLI wraps enough to create the account shell and schedule; the gap is in content and linking operations.

---

## Next Actions

- [ ] Write LinkedIn post: "Azure said quota = 0. Here's what we built instead." (3-act structure: outage → quota wall → MSI pivot)
- [ ] Extract the REST API snippet pattern into `docs/snippets/automation-runbook-upload.ps1` for reuse
- [ ] Consider extracting component 08 as a standalone open-source module once the repo goes public

---

## Cross-References

- **Related captures:** `AWACS_daily-capture_2026-05-08_sas-rotation.md` (the manual rotation this replaces), `AWACS_daily-capture_2026-05-08_norton-tls-interception.md` (what blocked rotation toolchain)
- **Related project files:** `components/08-sas-rotator/`, `docs/decisions/ADR-008-sas-rotation-automation.md`
- **Builds on:** Component 02 (Key Vault), Component 01 (Storage Account), MSI RBAC pattern from Component 03
- **Feeds into:** V2 backlog: test specs for component 08, GitHub public release
