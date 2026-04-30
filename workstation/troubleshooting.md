# Workstation Troubleshooting

Top failure modes and how to diagnose them.

## 1. "Cert not found in CurrentUser\My"

**Symptom:** push-files.ps1 throws on the cert lookup step.
**Diagnosis:**
- The bootstrap was run as a different user than the scheduled task's principal.
- The cert was imported into `LocalMachine\My` instead of `CurrentUser\My`.

**Fix:** Re-run `bootstrap.ps1` as the service account specified in the scheduled task. Verify with:
```
Get-ChildItem Cert:\CurrentUser\My | Where-Object Thumbprint -eq <thumb>
```

## 2. "AADSTS700027: Client assertion contains an invalid signature"

**Symptom:** AAD authn step fails.
**Diagnosis:** The cert in the local store does not match the cert registered with the SP in Entra ID. Either the wrong cert was imported, or the SP's cert was rotated and the new one not yet distributed.

**Fix:** Run `az ad sp show --id <appid>` and compare `keyCredentials[].customKeyIdentifier` (which is the cert thumbprint base64-decoded) against the local cert. Re-import the correct cert.

## 3. "AuthorizationPermissionMismatch" on Get-AzKeyVaultSecret

**Symptom:** SAS fetch fails with 403.
**Diagnosis:** SP does not have `Key Vault Secrets User` on the secret resource ID. RBAC was not applied or applied at the wrong scope.

**Fix:** From the deploy host:
```
az role assignment list --assignee <appid> --all
```
Verify there is an entry scoped to `/subscriptions/.../vaults/<kv>/secrets/current-write-sas`. If not, re-run the component 03 Bicep module.

## 4. Scheduled task runs but no files appear in storage

**Symptom:** Local log shows successful PUTs but the container is empty.
**Diagnosis:** Most likely the SAS in KV is for a different storage account, OR `containerName` in config.json is wrong.

**Fix:** Compare config.json's `storageAccountName` and `containerName` against the actual deployed resources. Inspect a SAS string (manually, after `Get-AzKeyVaultSecret`) — it includes the account name implicitly but the container name is in your script's path construction.

## 5. Bootstrap fails on PEM cert import

**Symptom:** "PEM-with-key import not natively supported in PowerShell 5.1"
**Diagnosis:** Bootstrap requires .pfx for cert+key import on Windows PowerShell 5.1.

**Fix:** Convert with openssl on the deploy host:
```
openssl pkcs12 -export -out awacs.pfx -in awacs-sp-cert.pem
```
Then re-run bootstrap with the .pfx.

## 6. "0x80070534: No mapping between account names and security IDs was done"

**Symptom:** `Register-ScheduledTask` fails.
**Diagnosis:** The `-UserId` passed to bootstrap doesn't match a real local account.

**Fix:** Run `whoami /user` to confirm the service account exists. If not, create it via `New-LocalUser` first.

## 7. Push runs but logs don't appear in Log Analytics

**Symptom:** Local log shows OK, but `StorageBlobLogs` query in LA returns nothing.
**Diagnosis:** Diag setting on the storage account is missing or pointed at the wrong workspace. New workspace ingestion can lag up to 10 minutes.

**Fix:** From the cloud side, run `tests/scripts/C5_1-diag-settings.ps1`. If diag is in place, just wait 10 min and requery.

## 8. Cert expiry warning fires every push

**Symptom:** Every push writes `_health/<host>-cert-expiring.json`.
**Diagnosis:** Cert is genuinely <14 days from expiry, OR you're testing with a short-lived cert.

**Fix:** Rotate the cert. From the deploy host:
1. `az ad app credential reset --id <appid> --create-cert --years 0.25`
2. Re-import on each lab PC.

A future automation hardening: have the cert rotator post a new cert into a side-channel (not the same KV — separate trust zone).

## 9. "Push runs but task scheduler shows last result 0x1"

**Symptom:** Task ran with non-zero exit code; no transcript captured.
**Diagnosis:** Push script crashed before `Start-Transcript`. Usually a config-not-found or PowerShell-not-found situation.

**Fix:** Manually run the script with `-Verbose` to see startup errors:
```
powershell.exe -NoProfile -File C:\ProgramData\AwacsBackup\push-files.ps1 -Verbose
```

## When in doubt

- `Get-Content C:\ProgramData\AwacsBackup\logs\push-$(Get-Date -Format yyyy-MM-dd).log -Tail 50`
- `Get-ScheduledTaskInfo -TaskName AwacsBackupPush`
- Then check the cloud-side audit chain via `tests/scripts/I3_3-audit-chain.ps1`.
