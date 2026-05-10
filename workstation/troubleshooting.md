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

## 10. Azure CLI fails with "SSL: CERTIFICATE_VERIFY_FAILED" (Antivirus TLS Interception)

**Symptom:** `az keyvault secret show` (or any Azure CLI call) fails with:
```
[SSL: CERTIFICATE_VERIFY_FAILED] unable to get local issuer certificate
```
PowerShell (`Invoke-WebRequest`) succeeds to the same endpoints. The `az account show` command may return cached credentials and appear to succeed even when SSL is broken.

**Diagnosis:** An endpoint protection product (Norton, Zscaler, Netskope, Symantec BlueCoat) is intercepting HTTPS traffic and re-signing it with a self-generated root CA. Windows trusts this cert because the AV pushed it to the Windows Certificate Store during installation. Azure CLI's bundled Python uses its own `certifi` CA bundle — which knows nothing about the AV root. Two trust stores, one host, different answers.

**Distinguish it from a real cert problem:**
```powershell
# Check what cert is being presented to an Azure endpoint via .NET (Windows store)
$req = [System.Net.HttpWebRequest]::Create("https://login.microsoftonline.com")
$req.Timeout = 10000; $req.AllowAutoRedirect = $false
try { $req.GetResponse().Close() } catch {}
$cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]$req.ServicePoint.Certificate
Write-Host "Issuer: $($cert.Issuer)"
# If issuer shows "Norton Web/Mail Shield Root" or your AV vendor name — confirmed interception
```

**Fix (quickest — add exclusions to the AV SSL scanner):**

Add the following domains to your antivirus product's SSL scanning exclusion list:
1. `login.microsoftonline.com`
2. `*.vault.azure.net`
3. `management.azure.com`
4. `*.blob.core.windows.net`
5. `*.core.windows.net`

After adding exclusions, restart any open terminals and retry.

**Fix (alternative — disable SSL scanning entirely for Azure CLI scope):**

If your AV product doesn't support per-domain exclusions, disabling SSL scanning for the Azure CLI Python process is the fallback. In Norton: Settings → Firewall → Advanced Settings → Smart Firewall → SSL → disable for affected scope.

**Why this happens on the workstation but not the deploy host:** The deploy host may not have endpoint protection installed, or its AV product may not intercept the Azure CLI process. Lab workstations with managed AV policies hit this frequently.

**Note:** This was encountered on DESKTOP-0DBOTVV on 2026-05-08 (Norton 360 Web/Mail Shield). The incident delayed SAS rotation by 6+ hours. This gotcha is documented in `daily-captures/AWACS_daily-capture_2026-05-08_norton-tls-interception.md`.

## When in doubt

- `Get-Content C:\ProgramData\AwacsBackup\logs\push-$(Get-Date -Format yyyy-MM-dd).log -Tail 50`
- `Get-ScheduledTaskInfo -TaskName AwacsBackupPush`
- Then check the cloud-side audit chain via `tests/scripts/I3_3-audit-chain.ps1`.
