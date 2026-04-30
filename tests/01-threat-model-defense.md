# Test File 01 — Threat Model Defense

Owner: 🛡️ Security Engineer. Each test references an actor (T1–T6) from `/threat-model.md` §3.

---

## Test: T1.1 — Insider analyst cannot read prior backups via the SP credential

**Component:** 03-service-principal-auth, 01-storage-account
**Question:** If an insider analyst extracts the SP cert and uses it to authenticate to the storage account, can they read existing blobs?
**Expected Answer:** No. The SP's custom role grants only `…/blobs/write` and `…/add/action`. Read attempts return 403.
**Failure Diagnosis:** If read succeeds: inspect the SP's role assignments (`az role assignment list --assignee <sp-id>`); the SP has been mistakenly granted `Storage Blob Data Reader` or `Contributor`. Remove the over-broad role.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/T1_1-sp-read-denied.ps1`

---

## Test: T1.2 — Cert is in service-account profile, not interactive analyst profile

**Component:** 07-workstation-push-script, workstation/bootstrap.ps1
**Question:** After bootstrap, is the cert visible to the interactive analyst login?
**Expected Answer:** No. Cert is in the service account's `Cert:\CurrentUser\My`. Interactive analyst logins enumerate their own user store and do not see the cert.
**Failure Diagnosis:** If analyst sees the cert: bootstrap installed it under the wrong user context, or used `LocalMachine` store unintentionally. Re-run bootstrap as the service account.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/T1_2-cert-scope.ps1`

---

## Test: T2.1 — Lifted SAS cannot read existing blobs

**Component:** 01-storage-account, 02-key-vault
**Question:** Given the current SAS (as it would appear if lifted), can a third-party tool use it to GET an existing blob?
**Expected Answer:** No. SAS is generated with `sp=acw` (add, create, write); it does not include `r` or `l`. GET returns 403 (AuthorizationPermissionMismatch).
**Failure Diagnosis:** If GET succeeds: inspect the SAS generation logic in the Key Vault rotation routine. The `sp=` parameter has the wrong flags. Fix the generator to remove `r` and `l`.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/T2_1-sas-read-denied.ps1`

---

## Test: T2.2 — Lifted SAS cannot delete blobs

**Component:** 01-storage-account, 04-immutability-policy
**Question:** Even if a SAS includes delete permission by mistake, does the immutability policy block delete?
**Expected Answer:** Yes. DELETE returns 409 (BlobImmutableDueToPolicy).
**Failure Diagnosis:** If DELETE succeeds: immutability policy is in `Disabled` state, retention period has elapsed, or the policy was never applied. Re-run `az storage container immutability-policy create`.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/T2_2-immutability-blocks-delete.ps1`

---

## Test: T2.3 — Lifted cert cannot escalate to ARM control plane

**Component:** 03-service-principal-auth
**Question:** Using the SP cert, can the holder list resource groups, modify resources, or escalate to higher RBAC?
**Expected Answer:** No. SP has zero ARM role assignments at the subscription, RG, or resource level. Only data-plane RBAC on storage and KV.
**Failure Diagnosis:** If escalation succeeds: SP has been granted Owner or Contributor at some scope. List with `az role assignment list --assignee <sp-id> --all`. Remove non-data-plane assignments.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/T2_3-sp-no-arm-access.ps1`

---

## Test: T5.1 — TLS 1.2+ enforced; TLS 1.0/1.1 refused

**Component:** 01-storage-account, 02-key-vault
**Question:** Does the storage account refuse connections below TLS 1.2?
**Expected Answer:** Yes. Connection at TLS 1.0 or 1.1 returns connection error. TLS 1.2 succeeds.
**Failure Diagnosis:** If TLS 1.0/1.1 succeeds: `minimumTlsVersion` is unset or set to `TLS1_0` on the storage account. Update Bicep to `minimumTlsVersion: 'TLS1_2'`.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/T5_1-tls-floor.ps1`

---

## Test: T6.1 — Consumer cannot delete via RBAC

**Component:** 06-rbac-consumer-access, 04-immutability-policy
**Question:** Using a consumer-group identity, can a user delete a blob?
**Expected Answer:** No. RBAC denies (consumer is `Storage Blob Data Reader`); even if RBAC permitted, immutability would block. Two-layer defense.
**Failure Diagnosis:** If delete succeeds: consumer group is mistakenly assigned `Contributor` or `Storage Blob Data Contributor`. Inspect via `az role assignment list --scope <storage-account-id>`.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/T6_1-consumer-readonly.ps1`

---

**Total tests in this file:** 7. All have executable counterparts.
