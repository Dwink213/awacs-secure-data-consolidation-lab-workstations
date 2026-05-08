# Test File 02 — Component Contracts

Owner: 🏗️ Architect. Each Atomic Lego must do what its README claims. These tests verify that.

---

## Test: C1.1 — Storage Account: HTTPS only

**Component:** 01-storage-account
**Question:** Is `supportsHttpsTrafficOnly` set to true?
**Expected Answer:** Yes.
**Failure Diagnosis:** Bicep template missing the property or set to false. Fix in `components/01-storage-account/main.bicep`.
**Owner Agent:** 🏗️
**Executable:** `tests/scripts/C1_1-https-only.ps1`

## Test: C1.2 — Storage Account: Public network access disabled

**Component:** 01-storage-account
**Question:** Is `allowBlobPublicAccess` false and `publicNetworkAccess` set as expected (default off, opt-in via parameter)?
**Expected Answer:** `allowBlobPublicAccess: false`. `publicNetworkAccess` defaults to `Enabled` (since lab PCs are on the open Internet) but no public *anonymous* container access permitted.
**Failure Diagnosis:** Verify Bicep values. If `allowBlobPublicAccess` is true, immediately remediate.
**Owner Agent:** 🏗️
**Executable:** `tests/scripts/C1_2-public-access.ps1`

## Test: C1.3 — Storage Account: Account key auth disabled

**Component:** 01-storage-account
**Question:** Is `allowSharedKeyAccess` false?
**Expected Answer:** Yes. The account key kill-switch must be disabled per threat-model §3.
**Failure Diagnosis:** Update Bicep `allowSharedKeyAccess: false` and redeploy.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/C1_3-shared-key-disabled.ps1`

## Test: C1.4 — Storage Account: TLS 1.2 minimum

**Component:** 01-storage-account
**Question:** Is `minimumTlsVersion` set to `TLS1_2`?
**Expected Answer:** Yes.
**Failure Diagnosis:** As C1.1 — fix Bicep.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/C1_4-tls-minimum.ps1`

## Test: C1.5 — Storage Account: Soft delete and versioning enabled

**Component:** 01-storage-account
**Question:** Are `deleteRetentionPolicy.enabled`, `containerDeleteRetentionPolicy.enabled`, and `isVersioningEnabled` all true?
**Expected Answer:** Yes. Default retention 14 days for both delete-retention policies.
**Failure Diagnosis:** Verify the `blobServices` resource in Bicep.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/C1_5-soft-delete-versioning.ps1`

---

## Test: C2.1 — Key Vault: Soft delete + purge protection on

**Component:** 02-key-vault
**Question:** Are `enableSoftDelete` and `enablePurgeProtection` both true?
**Expected Answer:** Yes. Once purge protection is enabled, it cannot be disabled — this is intentional.
**Failure Diagnosis:** Bicep parameter incorrect. Note that purge protection cannot be turned off after enabling.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/C2_1-kv-soft-delete-purge.ps1`

## Test: C2.2 — Key Vault: RBAC mode, not access policies

**Component:** 02-key-vault
**Question:** Is `enableRbacAuthorization` true?
**Expected Answer:** Yes. Access policy mode is the older model; we use Azure RBAC.
**Failure Diagnosis:** Bicep parameter `enableRbacAuthorization: true` missing.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/C2_2-kv-rbac-mode.ps1`

## Test: C2.3 — Key Vault: SP has Get-only on the named secret

**Component:** 02-key-vault, 03-service-principal-auth
**Question:** Does the SP have exactly `Key Vault Secrets User` on the *secret-scoped* resource ID, no broader role?
**Expected Answer:** Yes, scoped to `/subscriptions/.../vaults/<kv>/secrets/current-write-sas`.
**Failure Diagnosis:** Inspect role assignments; over-broad scope or wrong role.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/C2_3-kv-sp-scope.ps1`

---

## Test: C3.1 — Service Principal: cert authn only, no client secret

**Component:** 03-service-principal-auth
**Question:** Does the SP have any password-based credentials?
**Expected Answer:** No. Only certificate credentials.
**Failure Diagnosis:** Run `az ad app credential list --id <appId>`. Remove any `passwordCredentials`.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/C3_1-sp-cert-only.ps1`

## Test: C3.2 — Service Principal: custom role write-only

**Component:** 03-service-principal-auth
**Question:** Does the custom role definition include exactly the write-required actions and no others?
**Expected Answer:** Permitted actions = `{…/blobs/write, …/add/action}`. NotActions empty. DataActions same.
**Failure Diagnosis:** Inspect role JSON. Tighten if extra actions present.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/C3_2-sp-custom-role.ps1`

---

## Test: C4.1 — Immutability policy applied with documented retention

**Component:** 04-immutability-policy
**Question:** Does the container have a time-based retention policy with the parameter-specified retention period?
**Expected Answer:** Yes. State is `Unlocked` after first deploy (allows extension during initial 30-day window); manual lock procedure documented.
**Failure Diagnosis:** Policy missing or in wrong state. Re-apply via `az storage container immutability-policy create`.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/C4_1-immutability-applied.ps1`

## Test: C4.2 — Versioning + immutability stack correctly

**Component:** 04-immutability-policy, 01-storage-account
**Question:** Does writing a blob with the same name twice produce a version, with both versions retention-locked?
**Expected Answer:** Yes. Both blob versions exist; neither is deletable.
**Failure Diagnosis:** Versioning not enabled, or immutability policy is per-blob not per-container.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/C4_2-version-immutability.ps1`

---

## Test: C5.1 — Log Analytics workspace receives diag streams

**Component:** 05-log-analytics
**Question:** Are diag settings on storage and KV pointing to the workspace, with all log categories enabled?
**Expected Answer:** Yes. `StorageRead`, `StorageWrite`, `StorageDelete` enabled on the storage account; `AuditEvent` enabled on KV.
**Failure Diagnosis:** Diag settings missing or incomplete categories. Re-apply via Bicep.
**Owner Agent:** 🔧
**Executable:** `tests/scripts/C5_1-diag-settings.ps1`

---

## Test: C6.1 — Consumer group has Reader, no other RBAC

**Component:** 06-rbac-consumer-access
**Question:** Does the consumer security group have exactly `Storage Blob Data Reader` on the container scope?
**Expected Answer:** Yes.
**Failure Diagnosis:** Inspect `az role assignment list --assignee <group-id>`. Remove anything else.
**Owner Agent:** 🏗️
**Executable:** `tests/scripts/C6_1-consumer-rbac.ps1`

---

## Test: C7.1 — Workstation push script: code-signed (or signing path documented)

**Component:** 07-workstation-push-script
**Question:** Is `push-files.ps1` Authenticode-signed, or is the signing procedure documented in the component README?
**Expected Answer:** Either signed, or `Sign-PushScript.ps1` exists with operator-runnable instructions.
**Failure Diagnosis:** Sign the script per the procedure. Group Policy enforcement of signed scripts is the production hardening.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/C7_1-script-signed.ps1` (returns OK if signature OR signing-procedure file present)

## Test: C7.2 — Workstation push script: produces structured logs

**Component:** 07-workstation-push-script
**Question:** After a single test run, does the script produce a transcript log with timestamped INFO/ERROR lines?
**Expected Answer:** Yes. File at `C:\ProgramData\AwacsBackup\logs\push-YYYY-MM-DD.log` with at least one structured line per file pushed.
**Failure Diagnosis:** `Start-Transcript` missing in the script, or log path wrong.
**Owner Agent:** 🔧
**Executable:** `tests/scripts/C7_2-log-output.ps1`

---

## Test: C8.1 — SAS Rotator: Automation Account exists with MSI and Free SKU

**Component:** 08-sas-rotator
**Question:** Does the Automation Account `{prefix}-auto-{suffix}` exist in the correct state with a system-assigned MSI principal?
**Expected Answer:** `az automation account show` returns `state: Ok`, `sku: Free` (or Basic — Free maps to Basic in the API), and a non-empty `identity.principalId`.
**Failure Diagnosis:** Bicep deploy may have failed or drifted. Re-run deploy or check ARM for partial state.
**Owner Agent:** 🏗️
**Executable:** `tests/scripts/C8_1-auto-acct-exists.ps1`

## Test: C8.2 — SAS Rotator: Three RBAC assignments exist at correct scopes

**Component:** 08-sas-rotator
**Question:** Does the Automation MSI hold exactly three role assignments: Storage Blob Delegator on the SA, Storage Blob Data Contributor on the container, and Key Vault Secrets Officer scoped to the single secret resource?
**Expected Answer:** `az role assignment list --assignee {msiPrincipalId} --all` returns all three roles at the stated scopes. No broader scope (e.g., resource group or subscription level).
**Failure Diagnosis:** Bicep RBAC resources may not have deployed. Check Bicep output or run `az role assignment list` and compare against `main.bicep` scope expressions.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/C8_2-rbac-correct.ps1`

## Test: C8.3 — SAS Rotator: Runbook is in Published state

**Component:** 08-sas-rotator
**Question:** Does the `rotate-sas` runbook exist in the Automation Account and have state `Published` (not Draft)?
**Expected Answer:** `az automation runbook show` returns `state: Published` and `runbookType: PowerShell`.
**Failure Diagnosis:** Deploy.ps1 Step 5b may have skipped the publish step. Run `az automation runbook publish` manually. Check if runbook content was uploaded before publishing.
**Owner Agent:** 🔧
**Executable:** `tests/scripts/C8_3-runbook-published.ps1`

## Test: C8.4 — SAS Rotator: Schedule exists with correct interval and is enabled

**Component:** 08-sas-rotator
**Question:** Does the `every-6-days` schedule exist, have `frequency: Day`, `interval: 6`, and `isEnabled: true`?
**Expected Answer:** All three conditions met. `nextRun` is within the next 6 days.
**Failure Diagnosis:** Schedule not created — Deploy.ps1 Step 5b may have failed at `az automation schedule create`. Create manually: `az automation schedule create --frequency Day --interval 6 ...`
**Owner Agent:** 🔧
**Executable:** `tests/scripts/C8_4-schedule-exists.ps1`

## Test: C8.5 — SAS Rotator: Last rotation succeeded within 7 days

**Component:** 08-sas-rotator
**Question:** Does the Automation Account have at least one Completed job for `rotate-sas` within the last 7 days?
**Expected Answer:** `az automation job list` returns a job with `status: Completed` and `endTime` within 7 days of today.
**Failure Diagnosis:** Check Automation Account Jobs blade. If status is Failed, read job output stream for error. Most common: RBAC not propagated at time of run, or `Get-AutomationVariable` returned null. Trigger manually and observe.
**Owner Agent:** 🔧
**Executable:** `tests/scripts/C8_5-last-rotation-ok.ps1`

## Test: C8.6 — SAS Rotator: KV secret expiry is future and within 7-day window

**Component:** 08-sas-rotator
**Question:** Does the `current-write-sas` secret contain a token with an `se=` expiry that is in the future and ≤ 7 days from now?
**Expected Answer:** Parsed expiry is between now and now+7d. Confirms the rotator wrote a valid token (not empty, not expired, not over the Azure cap).
**Failure Diagnosis:** If expired: rotation failed or didn't run. Trigger manually. If expiry > 7d: SAS was generated with account key (not user-delegation), bypassing the 7-day cap — investigate how it was generated.
**Owner Agent:** 🛡️
**Executable:** `tests/scripts/C8_6-sas-expiry-valid.ps1`

---

**Total tests in this file:** 20.
