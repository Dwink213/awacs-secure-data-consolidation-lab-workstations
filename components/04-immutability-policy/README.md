# Component 04 — Immutability Policy

**Atomic Lego.** Single responsibility: the "you cannot delete" guarantee on the container.

## Contract

Applies a **time-based retention policy** (immutability) to the `lab-files` container in the storage account. The policy is created in **Unlocked** state by default — this allows the operator to extend the retention period during the initial 30-day window without full lock. Lock procedure is manual and documented in `RUNBOOK.md`.

## Why time-based, not legal hold

Time-based retention is the right tool when retention duration is known up front (e.g., "90 days from upload"). Legal hold is the right tool when retention is open-ended pending an external event (e.g., "until litigation resolves"). For lab data backup, time-based is the natural fit.

GxP upgrade hook: legal hold can be added on top of time-based without redeploy if the deployer's environment requires it.

## Inputs

| Name | Required | Notes |
|------|----------|-------|
| `storageAccountName` | yes | From component 01 |
| `containerName` | yes | From component 01 |
| `retentionDays` | yes | Default 90 |
| `allowProtectedAppendWrites` | no | Default false; allows append-blob extension |

## Outputs

None — this is a side-effect component that mutates the container.

## Lock procedure (manual, post-deploy)

After verifying the policy is correct, lock it via:

**Command:** `az storage container immutability-policy lock --account-name <sa> --container-name lab-files --if-match <etag>`
**What it does:** Transitions the policy from Unlocked to Locked; once Locked, retention can only be *extended*, never reduced.
**Expected output:** Policy state returns `Locked`.

## Tests

- C4.1, C4.2 (contracts)
- T1.1, T2.2 (threat-model defense)
- I3.2 (integration)

## Failure modes

- **Policy cannot be locked because retention period is the default.** Microsoft requires an explicit retention period > 0 days. Verify Bicep parameter.
- **Teardown refused due to active immutability.** This is by design (D6.5 test). To force-teardown for testing, pass `-ForceTearDownExpiredPolicy` to `teardown.ps1`.
