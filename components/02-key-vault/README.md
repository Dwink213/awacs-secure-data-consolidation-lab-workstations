# Component 02 — Key Vault

**Atomic Lego.** Single responsibility: holds the rotated SAS secret; gates access by SP identity via RBAC.

## Contract

- One Key Vault with:
  - Soft delete enabled (90-day retention, the Azure default)
  - Purge protection enabled (cannot be disabled once on; intentional)
  - RBAC authorization (`enableRbacAuthorization: true`), not access policies
  - Public network access enabled by default (lab PC needs to reach it); operator can switch to Private Endpoint for hardened deploys
- One initial secret slot named `current-write-sas` (placeholder value; real SAS written by deploy script post-deploy)
- One Diagnostic Setting forwarding `AuditEvent` to the Log Analytics workspace

## Outputs

| Name | Used by |
|------|---------|
| `keyVaultName` | components 03 (RBAC), 07 (script config) |
| `keyVaultUri` | component 07 |
| `keyVaultId` | component 03 |
| `secretName` | component 07 |

## Inputs

| Name | Required | Notes |
|------|----------|-------|
| `prefix` | yes | |
| `location` | yes | |
| `logAnalyticsWorkspaceId` | yes | |
| `tenantId` | yes | Defaults to subscription tenant |

## SAS rotation

The SAS is rotated automatically by **component 08 (SAS Rotator)** — an Azure Automation Account with a system-assigned MSI. The runbook fires every 6 days (noon UTC), generates a new `acw` user-delegation SAS valid for 6d 23h, and writes it to this secret slot. No operator action required under normal operation.

The push script (component 07) reads this secret on every run; rotation is fully transparent to the lab PC.

For the manual fallback procedure (if the Automation Account job is failing), see `RUNBOOK.md` §1.

## Tests

- C2.1, C2.2, C2.3 (contracts)
- CIS-7.1 (compliance)

## Failure modes

- **Purge protection cannot be disabled.** This is a feature, not a bug. The cost is ~90 days of soft-deleted state if you teardown and want to redeploy with the same name. Use a different `prefix` for repeat deploys during dev/test.
