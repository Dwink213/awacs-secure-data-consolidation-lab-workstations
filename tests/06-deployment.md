# Test File 06 — Deployment

Owner: 🔧 Operator. The repo is turnkey if and only if these tests pass on a clean Azure subscription.

---

## Test: D6.1 — Preflight refuses on missing prerequisites

**Component:** deploy/preflight.ps1
**Question:** When run without Azure CLI installed (or not logged in, or insufficient role), does preflight exit non-zero with a specific error message naming the failure?
**Expected Answer:** Yes. Each of the 9 preflight checks (`architecture/deployment-flow.md` §"Preflight checks") emits a named failure when violated.
**Failure Diagnosis:** Run preflight with `-Verbose`. Each check should print a PASS/FAIL line.
**Owner Agent:** 🔧
**Executable:** `tests/scripts/D6_1-preflight-gates.ps1` (mock-driven, simulates each failure mode)

## Test: D6.2 — Clean deploy: full system from empty subscription

**Component:** deploy/Deploy.ps1
**Question:** From a clean subscription (no RG named `<prefix>-rg`), does deploy produce all six cloud-side components and exit 0?
**Expected Answer:** Yes. RG, SA, KV, LA, SP, RBAC, immutability all present after run.
**Failure Diagnosis:** Inspect deploy log. Each Bicep module emits a deployment ID; failed modules visible in `az deployment group list`.
**Owner Agent:** 🔧
**Executable:** `tests/scripts/D6_2-clean-deploy.ps1`

## Test: D6.3 — Re-deploy: idempotent, no changes

**Component:** deploy/Deploy.ps1
**Question:** Running deploy a second time with the same parameters: does it complete successfully with no changes (or only ARM-level no-op changes)?
**Expected Answer:** Yes. `az deployment group what-if` should show 0 changes after the first deploy.
**Failure Diagnosis:** Bicep contains a non-deterministic value (e.g., `utcNow()` for naming). Find and fix.
**Owner Agent:** 🔧
**Executable:** `tests/scripts/D6_3-idempotent.ps1`

## Test: D6.4 — Teardown: clean removal

**Component:** deploy/teardown.ps1
**Question:** Does teardown remove the resource group, RBAC assignments, and SP, leaving the subscription as it was?
**Expected Answer:** Yes, with the documented caveat that KV and SA are soft-deleted (not purged) by default.
**Failure Diagnosis:** Orphaned RBAC or SP. Inspect with `az ad sp list` and `az role assignment list`.
**Owner Agent:** 🔧
**Executable:** `tests/scripts/D6_4-teardown.ps1`

## Test: D6.5 — Teardown refuses to violate immutability

**Component:** deploy/teardown.ps1
**Question:** If immutability policy retention has not expired, does teardown refuse to proceed without an explicit override flag?
**Expected Answer:** Yes. Default behavior: print "Cannot teardown: immutability retention not expired. Pass -ForceTearDownExpiredPolicy to override." Exit non-zero.
**Failure Diagnosis:** Override check missing. Add to teardown script.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/D6_5-teardown-immutability.ps1`

## Test: D6.6 — verify.ps1 chains all executable tests

**Component:** deploy/verify.ps1
**Question:** Does verify run every `tests/scripts/*.ps1` and produce one structured report?
**Expected Answer:** Yes. Output is a table: test ID, status, duration, error (if any).
**Failure Diagnosis:** New test scripts not added to verify's discovery glob. verify should glob `tests/scripts/*.ps1` rather than hard-code.
**Owner Agent:** 🔧
**Executable:** `tests/scripts/D6_6-verify-coverage.ps1`

---

**Total tests in this file:** 6.
