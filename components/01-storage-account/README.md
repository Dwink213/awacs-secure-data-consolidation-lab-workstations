# Component 01 — Storage Account

**Atomic Lego.** Single responsibility: durable, immutable, write-only-from-lab destination for backup blobs.

## Contract

This component produces:

- One Storage Account with:
  - HTTPS only (`supportsHttpsTrafficOnly: true`)
  - TLS 1.2 minimum (`minimumTlsVersion: TLS1_2`)
  - Account-key auth disabled (`allowSharedKeyAccess: false`)
  - Public anonymous access disabled (`allowBlobPublicAccess: false`)
  - Soft delete on blobs and containers (14 days)
  - Versioning enabled
- One Blob Container `lab-files`
- One Diagnostic Setting on the blob service forwarding `StorageRead`, `StorageWrite`, `StorageDelete` to the Log Analytics workspace ID passed in
- One CanNotDelete Resource Lock on the storage account

This component does **not** apply the immutability policy (that is component 04, applied after the container exists).

## Outputs

| Name | Used by |
|------|---------|
| `storageAccountName` | components 03 (RBAC), 04 (immutability), 06 (consumer RBAC), 07 (workstation script config) |
| `storageAccountId` | components 03, 04, 06 |
| `containerName` | components 03, 04, 06, 07 |
| `blobEndpoint` | component 07 |

## Inputs

| Name | Required | Notes |
|------|----------|-------|
| `prefix` | yes | Used for the SA name (with `unique4` suffix) |
| `location` | yes | Region |
| `logAnalyticsWorkspaceId` | yes | Output from component 05 |
| `softDeleteRetentionDays` | no | Default 14 |

## Tests

This component is verified by:

- C1.1, C1.2, C1.3, C1.4, C1.5 (contracts)
- T2.1, T2.2 (threat-model defense)
- CIS-3.1, CIS-3.7, CIS-3.13, CIS-3.14, CIS-Custom (compliance)

## Failure modes

- **Deploy fails on globally-unique name conflict.** The `unique4` suffix is deterministic from RG name + subscription ID; collision is rare but possible. Re-run with a different prefix.
- **Diag setting rejects with "WorkspaceId not found".** Component 05 not deployed first. Bicep `dependsOn` should prevent this; if it happens, deploy 05 standalone first.

## Cost ownership

The storage account lives in the deployer's resource group. They pay. Costs scale with file volume + retention.
