# Component 06 — Consumer RBAC

**Atomic Lego.** Single responsibility: read-only access to the container from analyst desks (Z8).

## Contract

Assigns built-in `Storage Blob Data Reader` to a specified Entra ID security group, scoped to the `lab-files` container.

That's it. One role assignment, one scope.

## Why a security group, not individual users

- **Operator burden.** Adding/removing users individually is friction; rotating a security group membership is a single Entra ID change.
- **Audit clarity.** "Member of `awacs-lab-readers` group" is a cleaner audit story than "list of 47 individual UPN assignments."
- **Separation from lab-side identity.** The consumers are humans on Z8; the SP on Z1 is a service identity. Different RBAC paths, different audit trails, no overlap.

## Inputs

| Name | Required | Notes |
|------|----------|-------|
| `consumerGroupObjectId` | yes | Object ID of the Entra ID security group |
| `storageAccountName` | yes | From component 01 |
| `containerName` | yes | From component 01 |

## Outputs

| Name | Used by |
|------|---------|
| `roleAssignmentId` | (informational) |

## Tests

- C6.1 (contract)
- T6.1 (threat-model defense)

## Failure modes

- **`consumerGroupObjectId` is wrong type.** If the operator passes a user UPN instead of a group object ID, role assignment goes through but only that user has access. Documented; preflight does not validate this (would require Graph permissions).
- **Group does not exist.** Role assignment Bicep fails with PrincipalNotFound. Operator creates the group first.
