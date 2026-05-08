# Build Log: Component 08 — SAS Rotator
**Date:** 2026-05-08
**Session context:** Post-expiry emergency build — automated SAS rotation to prevent recurrence
**Operator:** Dustin Winkler
**AI agent:** Claude claude-sonnet-4-6
**Hash algorithm:** MD5 (UTF-8 encoded output strings)

> Note: This log reconstructs commands run across two session contexts (pre- and post-context-compaction). Commands marked `[LIVE]` executed against the actual subscription. Commands marked `[IaC-cleanup]` are file edits from the reconciliation pass in session s2.

---

## Phase 1: Preflight + Quota Discovery

### CMD-001 — Attempt Functions Consumption plan deploy
```
az deployment group create \
  --resource-group awdust-rg \
  --template-file components/08-sas-rotator/main.bicep \
  --parameters prefix=awdust ...
```
**Status:** FAILED  
**Output:** `Dynamic VM quota exhausted. Current: 0, Required: 1.`  
**MD5:** `[output not captured — ran in previous session context]`  
**Action taken:** Pivot to Azure Automation Account (no Dynamic VM quota required)

---

## Phase 2: Azure Automation Account Deployment

### CMD-002 — Create Automation Account (via Bicep, updated module)
```powershell
az deployment group create `
  --resource-group awdust-rg `
  --name deploy-08-auto-20260508 `
  --template-file components/08-sas-rotator/main.bicep `
  --parameters prefix=awdust storageAccountName=awdustsaybmh containerName=lab-files keyVaultName=awdust-kv-ybmh ...
```
**Status:** Succeeded  
**Output (key fields):**
```json
{
  "name": "awdust-auto-ybmh",
  "identity": {
    "type": "SystemAssigned",
    "principalId": "41ca010b-76bc-434a-a052-8112c3ef69fc"
  },
  "sku": { "name": "Free" }
}
```
**MD5 (principalId):** `c5ee7acc73f74b1c4f42fefe8d0af69e`
**MD5 (autoAcctName):** `462e6537351a64d0a7a3e73fec6f684f`

---

## Phase 3: RBAC Assignments (via Bicep, same deploy)

### CMD-003 — Storage Blob Delegator on `awdustsaybmh`
**Role GUID:** `db58b8e5-c6ad-4a2a-8342-4190687cbf4a`  
**MD5 (roleId):** `235542b68590f938cac2294c37a2e8ad`  
**Scope:** `/subscriptions/49521d08-4a34-4355-a069-919af69ad956/resourceGroups/awdust-rg/providers/Microsoft.Storage/storageAccounts/awdustsaybmh`  
**Status:** Succeeded

### CMD-004 — Storage Blob Data Contributor on `lab-files` container
**Role GUID:** `ba92f5b4-2d11-453d-a403-e96b0029c9fe`  
**MD5 (roleId):** `acbabb3906ddd76835a00ee54eb95b8d`  
**Scope:** `...storageAccounts/awdustsaybmh/blobServices/default/containers/lab-files`  
**Status:** Succeeded

### CMD-005 — Key Vault Secrets Officer on `current-write-sas` secret
**Role GUID:** `b86a8fe4-44ce-4948-aee5-eccb2c155cd7`  
**MD5 (roleId):** `f028ac2150fc53cf4df98b3745f0ab99`  
**Scope:** `.../vaults/awdust-kv-ybmh/secrets/current-write-sas`  
**Status:** Succeeded

---

## Phase 4: Runbook Upload (REST API — az CLI verb missing)

### CMD-006 — Create runbook shell
```powershell
az automation runbook create `
  --resource-group awdust-rg `
  --automation-account-name awdust-auto-ybmh `
  --name rotate-sas `
  --type PowerShell `
  --output none
```
**Status:** Succeeded

### CMD-007 — Upload runbook content via REST PUT
```powershell
$putUri = "https://management.azure.com/subscriptions/49521d08-.../automationAccounts/awdust-auto-ybmh/runbooks/rotate-sas/draft/content?api-version=2023-11-01"
Invoke-RestMethod -Method PUT -Uri $putUri -Headers @{ Authorization = "Bearer $token"; 'Content-Type' = 'text/powershell' } -Body $runbookContent
```
**Status:** Succeeded (204 No Content)

> **Gotcha captured:** First attempt passed the local file PATH as `-Body` instead of file contents, causing runbook to fail with `CommandNotFoundException`. Fixed by reading file contents into a variable first.

### CMD-008 — Publish runbook draft
```powershell
az automation runbook publish `
  --resource-group awdust-rg `
  --automation-account-name awdust-auto-ybmh `
  --name rotate-sas `
  --output none
```
**Status:** Succeeded

---

## Phase 5: Schedule + Job Schedule Link

### CMD-009 — Create schedule
```powershell
az automation schedule create `
  --resource-group awdust-rg `
  --automation-account-name awdust-auto-ybmh `
  --name every-6-days `
  --frequency Day `
  --interval 6 `
  --start-time 2026-05-09T12:00:00Z `
  --output none
```
**Status:** Succeeded

### CMD-010 — Link runbook to schedule (REST PUT — az CLI verb missing)
```powershell
$linkUri = "https://management.azure.com/.../jobSchedules/{guid}?api-version=2023-11-01"
$body = '{ "properties": { "runbook": { "name": "rotate-sas" }, "schedule": { "name": "every-6-days" } } }'
Invoke-RestMethod -Method PUT -Uri $linkUri -Headers @{ Authorization = "Bearer $token"; 'Content-Type' = 'application/json' } -Body $body
```
**Status:** Succeeded

---

## Phase 6: Live Test

### CMD-011 — Trigger runbook manually
```powershell
az automation runbook start `
  --resource-group awdust-rg `
  --automation-account-name awdust-auto-ybmh `
  --name rotate-sas
```
**Status:** Job created

### CMD-012 — Check job status
```powershell
az automation job list `
  --resource-group awdust-rg `
  --automation-account-name awdust-auto-ybmh `
  --query "[0].{id:name, status:status}" `
  --output json
```
**Output:**
```json
{ "id": "45bb7628", "status": "Completed" }
```
**MD5 (jobId):** `0990799ea6e4aa25645907b29b887865`  
**MD5 (status):** `07ca5050e697392c9ed47e6453f1453f`

### CMD-013 — Verify KV secret updated
```powershell
az keyvault secret show `
  --vault-name awdust-kv-ybmh `
  --name current-write-sas `
  --query attributes.expires `
  --output tsv
```
**Output:** `2026-05-15T21:41:03+00:00`  
**MD5 (expiry):** `6b1b85d9216510187ff8215b4dac2ae7`

---

## Phase 7: IaC Reconciliation (session s2 file edits)

| File | Change | Type |
|------|--------|------|
| `deploy/main.bicep` | Comment: "six" → "seven"; "Azure Function" → "Azure Automation Account"; output name: `funcAppName` → `autoAcctName` | Edit |
| `deploy/Deploy.ps1` | Description: added 08; Step 5b: zip deploy → REST runbook upload | Edit |
| `components/08-sas-rotator/main.bicep` | Added 4 Automation Variables (StorageAccountName, ContainerName, KeyVaultName, SecretName) | Edit |
| `components/08-sas-rotator/runbook/rotate-sas.ps1` | Created Automation-native runbook (Get-AutomationVariable, Write-Output, no param binding) | Create |
| `components/08-sas-rotator/function/` | Deleted (Functions scaffolding, wrong runtime) | Delete |
| `components/08-sas-rotator/README.md` | Rewritten for Automation Account | Rewrite |
| `STATUS.md` | Updated: SAS state, automation status, resources table, 3 new gotchas | Update |

---

## Build Summary

| Item | Value |
|------|-------|
| Component | 08-sas-rotator |
| Live resource created | `awdust-auto-ybmh` (Automation Account, Free SKU) |
| MSI principal | `41ca010b-76bc-434a-a052-8112c3ef69fc` |
| RBAC assignments | 3 (Blob Delegator, Blob Contributor, KV Secrets Officer) |
| Runbook | `rotate-sas` (PowerShell, Published) |
| Schedule | `every-6-days` (noon UTC, interval=6 days) |
| Live test job | `45bb7628` — Completed |
| KV secret updated | Yes — expiry 2026-05-15T21:41:03Z |
| Files modified (reconciliation) | 6 |
| Files created | 2 (`runbook/rotate-sas.ps1`, this log) |
| Files deleted | 1 directory (`function/`) |
| Total session outcome | SAS rotation fully automated; IaC reconciled; STATUS.md current |
