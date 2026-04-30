# Test File 05 — Compliance

Owner: 🛡️ Security Engineer. Each CIS control referenced in `threat-model.md` §5 has a verifying test here.

---

## Test: CIS-3.1 — Secure transfer required (HTTPS only)

**Component:** 01-storage-account
**Question:** Is HTTPS-only enforced on the storage account?
**Expected Answer:** Yes (`supportsHttpsTrafficOnly: true`).
**Failure Diagnosis:** See C1.1.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/CIS-3_1-https-only.ps1`

## Test: CIS-3.7 — Anonymous public access disabled

**Component:** 01-storage-account
**Question:** Is `allowBlobPublicAccess` false?
**Expected Answer:** Yes.
**Failure Diagnosis:** See C1.2.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/CIS-3_7-anon-disabled.ps1`

## Test: CIS-3.13 — Storage logging enabled (read/write/delete)

**Component:** 01-storage-account, 05-log-analytics
**Question:** Are `StorageRead`, `StorageWrite`, and `StorageDelete` log categories enabled in the diag setting?
**Expected Answer:** Yes, all three.
**Failure Diagnosis:** Diag setting incomplete. Re-apply Bicep.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/CIS-3_13-storage-logging.ps1`

## Test: CIS-3.14 — Soft delete enabled for blob

**Component:** 01-storage-account
**Question:** Is `deleteRetentionPolicy.enabled` true with retention ≥7 days?
**Expected Answer:** Yes. Default is 14 days.
**Failure Diagnosis:** See C1.5.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/CIS-3_14-soft-delete.ps1`

## Test: CIS-5.1 — Activity Log forwarded to Log Analytics

**Component:** 05-log-analytics + subscription-level diag
**Question:** Is there a subscription-level diag setting forwarding all Activity Log categories to the workspace?
**Expected Answer:** Yes.
**Failure Diagnosis:** Subscription-level diag missing. Add via deploy.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/CIS-5_1-activity-log.ps1`

## Test: CIS-7.1 — Key Vault recoverable

**Component:** 02-key-vault
**Question:** Soft delete + purge protection both enabled?
**Expected Answer:** Yes.
**Failure Diagnosis:** See C2.1.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/CIS-7_1-kv-recoverable.ps1`

## Test: CIS-Custom — Account key auth disabled

**Component:** 01-storage-account
**Question:** Is `allowSharedKeyAccess` false?
**Expected Answer:** Yes.
**Failure Diagnosis:** See C1.3. (This is not strictly a CIS control — it is a project-specific hardening that exceeds CIS, captured here so future audits see it tested.)
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/CIS-Custom-shared-key.ps1`

---

**Total tests in this file:** 7.
