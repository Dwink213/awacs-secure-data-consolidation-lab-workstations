# Component 05 — Log Analytics + Alerts

**Atomic Lego.** Single responsibility: the audit trail. Tamper-evident, separate trust zone from the lab PC.

## Contract

Produces:

- One Log Analytics workspace
- One Action Group for alert routing (configurable email + webhook)
- One scheduled query alert: "Workstation hasn't pushed in >25h"
- (Stage 5) Subscription-level diag setting forwarding Activity Log to this workspace — **lives in `deploy/main.bicep`** because it requires subscription scope.

## Why this is component 05 (deployed first)

Every other component points its diagnostic settings at this workspace. If it isn't up first, Bicep dependsOn cascades fail.

## Outputs

| Name | Used by |
|------|---------|
| `workspaceId` | components 01 (diag), 02 (diag) |
| `workspaceCustomerId` | (operator-facing; for KQL queries) |
| `actionGroupId` | (alerts) |

## Inputs

| Name | Required | Notes |
|------|----------|-------|
| `prefix` | yes | |
| `location` | yes | |
| `retentionDays` | no | Default 90 |
| `alertEmail` | no | If empty, alert created in disabled state |
| `alertWebhook` | no | If empty, no webhook leg |

## Tests

- C5.1 (contract)
- F4.1 (failure mode: staleness alert)
- I3.3 (integration: audit chain)
- CIS-5.1 (compliance, in conjunction with deploy/main.bicep subscription diag)

## Failure modes

- **Alert query takes >24h to first-evaluate after deploy.** The KQL alert evaluates over 25h windows, and brand-new workspaces have empty data for the first hour. The alert "always fires" briefly until first push data arrives — documented in RUNBOOK.md as a known startup behavior.
- **Action Group missing email.** Alert fires but nobody is notified. Verify alertEmail parameter.
