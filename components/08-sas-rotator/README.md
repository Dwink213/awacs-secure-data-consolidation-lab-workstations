# Component 08: SAS Rotator

## What This Does

A scheduled Azure Automation Account runbook that automatically rotates the `current-write-sas` Key Vault secret every 6 days. It generates a new user-delegation SAS token (valid 6d 23h) and writes it to Key Vault before the old one expires. The workstation push script reads from Key Vault on every run — no workstation changes needed.

## Why It Exists

Azure user-delegation SAS tokens have a hard 7-day maximum lifetime. Without automation, manual rotation is required weekly. When missed, workstation blob pushes fail silently with HTTP 403 (see `docs/session-notes/` for the 2026-05-01 incident). This component eliminates the manual dependency.

## Why Automation Account (Not Azure Functions)

Originally designed as an Azure Function (Consumption plan). Pivoted to Azure Automation because personal/PAYG subscriptions frequently have Dynamic VM quota = 0, which blocks Consumption plan creation. Azure Automation Account (Free SKU) requires no Dynamic VM quota and supports the same system-assigned MSI model. See `docs/decisions/ADR-008-sas-rotation-automation.md` for full rationale.

## Contract

| Property | Value |
|---|---|
| Trigger | Automation Schedule `every-6-days` (noon UTC, every 6 days) |
| Runtime | PowerShell (Azure Automation, built-in Az modules) |
| Identity | System-assigned Managed Identity (no credentials stored) |
| SAS expiry | 6 days 23 hours from time of generation |
| SAS permissions | `acw` (add, create, write) — write-only, HTTPS-only |
| Secret written | `current-write-sas` in `awdust-kv-ybmh` |

## Dependencies

| Dependency | Type |
|---|---|
| `awdustsaybmh` (Storage Account) | Data plane — generates user-delegation key |
| `lab-files` (Container) | Scope of the SAS token |
| `awdust-kv-ybmh` (Key Vault) | Writes new secret version |
| `awdust-la-ybmh` (Log Analytics) | Receives Automation job diagnostic logs |

## Automation Variables (config, set by Bicep at deploy time)

| Variable Name | Value | Encrypted |
|---|---|---|
| `StorageAccountName` | Name of the data SA | No |
| `ContainerName` | Blob container name | No |
| `KeyVaultName` | Key Vault name | No |
| `SecretName` | KV secret name (`current-write-sas`) | No |

The runbook reads these at runtime via `Get-AutomationVariable`.

## RBAC Required (on Automation Account MSI)

| Role | Scope | Why |
|---|---|---|
| Storage Blob Delegator | Storage Account | GetUserDelegationKey API call |
| Storage Blob Data Contributor | `lab-files` container | SAS can only grant perms the issuer holds |
| Key Vault Secrets Officer | `current-write-sas` secret (resource-scoped) | Write new secret versions |

All three are assigned by `main.bicep` at deploy time.

## Resources Created by `main.bicep`

| Resource | Name | Notes |
|---|---|---|
| Automation Account | `{prefix}-auto-{suffix}` | Free SKU, system-assigned MSI |
| Automation Variables | `StorageAccountName`, `ContainerName`, `KeyVaultName`, `SecretName` | Config, not secrets |
| Diagnostic Settings | `send-to-la` | Job logs → Log Analytics |

## Resources Created by `Deploy.ps1` (imperative, post-Bicep)

| Resource | Notes |
|---|---|
| Runbook `rotate-sas` | Uploaded from `runbook/rotate-sas.ps1` via REST API |
| Schedule `every-6-days` | Noon UTC, interval=6 days |
| Job Schedule link | Binds `rotate-sas` runbook to `every-6-days` schedule |

These are created imperatively because `az automation runbook replace-content` and `az automation jobSchedules create` are not available in the az CLI extension. Deploy.ps1 uses `Invoke-RestMethod` with a Bearer token for both.

## Failure Mode

If rotation fails (network error, RBAC not propagated, etc.):
- `rotate-sas.ps1` calls `Write-Error` + `throw` — Automation marks the job **Failed**
- The existing SAS token remains in Key Vault and continues to work until it expires
- Workstation pushes are unaffected until the old token's expiry
- Check job logs: Automation Account → Jobs → filter by Status=Failed
- Check via Log Analytics: `AzureDiagnostics | where ResourceType == "AUTOMATIONACCOUNTS" | where Category == "JobLogs" | order by TimeGenerated desc`
- Manual fallback: see `RUNBOOK.md` — SAS Rotation (Manual Fallback)

## Verify After Deploy

```powershell
# 1. Confirm Automation Account exists and MSI is assigned
az automation account show --resource-group awdust-rg --name awdust-auto-ybmh --query "{name:name, state:state, msi:identity.principalId}" -o json

# 2. Trigger the runbook manually (skip waiting 6 days)
az automation runbook start --resource-group awdust-rg --automation-account-name awdust-auto-ybmh --name rotate-sas

# 3. Check the job completed successfully
az automation job list --resource-group awdust-rg --automation-account-name awdust-auto-ybmh --query "[0].{id:name, status:status}" -o json

# 4. Read back the new SAS and parse its expiry
az keyvault secret show --vault-name awdust-kv-ybmh --name current-write-sas --query value -o tsv | ForEach-Object {
    if ($_ -match "se=([^&]+)") { "New expiry: $([uri]::UnescapeDataString($matches[1]))" }
}

# 5. Confirm in Log Analytics (may take 2-5 min to appear)
# AzureDiagnostics | where ResourceType == "AUTOMATIONACCOUNTS" | where Category == "JobLogs" | order by TimeGenerated desc | take 10
```
