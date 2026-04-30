# Component 03 — Service Principal + Custom Role + RBAC

**Atomic Lego.** Single responsibility: the lab PC's narrowly-scoped Entra identity and the role assignments that make it write-only.

## Why this is split into Bicep + imperative

Bicep deploys ARM resources. Service Principal *creation* is an Entra ID action, not an ARM action — it lives in `Microsoft.Graph` (the Graph API), not Microsoft.Resources. Pure Bicep can declare SP creation only via `Microsoft.Graph/applications` (preview) or via a `deploymentScripts` shim. Both add complexity.

**Decision (ADR-003):** SP creation happens in `deploy/Deploy.ps1` imperatively (one `az ad sp create-for-rbac --create-cert` call). The resulting `appId` and `principalId` are passed as parameters to this component's Bicep, which declares the custom role and the RBAC assignments.

This trade-off is documented in ADR-003 (file present in `docs/decisions/`).

## Contract

This component produces:

- One Custom Role Definition `awacs-lab-pc-writer` scoped to the resource group, with these data actions and nothing else:
  - `Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write`
  - `Microsoft.Storage/storageAccounts/blobServices/containers/blobs/add/action`
- One Role Assignment of `awacs-lab-pc-writer` to the SP, scoped to the storage container
- One Role Assignment of built-in `Key Vault Secrets User` to the SP, scoped to the SAS secret resource ID

## Inputs

| Name | Required | Notes |
|------|----------|-------|
| `servicePrincipalObjectId` | yes | Object ID of SP, supplied by deploy script after SP creation |
| `storageAccountId` | yes | Output from component 01 |
| `containerName` | yes | Output from component 01 |
| `keyVaultId` | yes | Output from component 02 |
| `secretResourceId` | yes | Output from component 02 |

## Outputs

| Name | Used by |
|------|---------|
| `customRoleDefinitionId` | (informational; for inspection) |
| `writeAssignmentId` | (informational) |
| `kvAssignmentId` | (informational) |

## Cert handling

The cert is generated at SP-create time by the deploy script (`az ad sp create-for-rbac --create-cert --years 0.25` for a 90-day cert) and emitted to `./out/<prefix>-sp-cert-<timestamp>.pfx`. The deploy script also emits the thumbprint and password to a sibling file. The operator distributes these to lab PCs via their chosen channel.

For the hardened mode (external CA-signed cert), the operator pre-generates the cert and provides only the public key (.cer) to the deploy. This is captured in ADR-003.

## Tests

- C3.1, C3.2 (contracts)
- T1.1, T2.1, T2.3 (threat-model defense)

## Failure modes

- **`az ad sp create-for-rbac` fails with "Insufficient privileges to complete the operation".** The deploying identity lacks Application Administrator or Cloud Application Administrator in Entra ID. Document this in preflight; suggest the user grant themselves the role temporarily.
- **Custom role creation fails with "Role already exists".** A previous deploy did not teardown cleanly. Manually remove with `az role definition delete --name awacs-lab-pc-writer`.
