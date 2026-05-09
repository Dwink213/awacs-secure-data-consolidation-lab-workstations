# Runbook

Day-2 operations for a deployed AWACS Secure Lab Backup environment. Owner: 🔧 Operator.

## Routine operations

### 1. SAS rotation (automated — verify monthly; manual is fallback only)

The push depends on a fresh SAS in Key Vault. **Rotation is automated** via Azure Automation Account `awdust-auto-ybmh`, runbook `rotate-sas`, schedule `every-6-days` (noon UTC). No operator action is required under normal operation.

**Routine health check (monthly):**

**Command:**
```powershell
# Confirm last rotation job succeeded
az automation job list --resource-group awdust-rg --automation-account-name awdust-auto-ybmh --only-show-errors --query "[0].{id:name, status:status, end:endTime}" -o json

# Confirm current SAS expiry is in the future
az keyvault secret show --vault-name awdust-kv-ybmh --name current-write-sas --query value -o tsv | ForEach-Object {
    if ($_ -match "se=([^&]+)") { "Expiry: $([uri]::UnescapeDataString($matches[1]))" }
}
```
**Expected output:** Last job `status: Completed`; SAS expiry is 4–7 days in the future.

Or run the test suite: `tests/scripts/C8_5-last-rotation-ok.ps1` and `tests/scripts/C8_6-sas-expiry-valid.ps1`.

**SAS rotation — manual fallback (use only if Automation Account job is failing):**

**Command:**
```powershell
# Requires: Storage Blob Delegator role on the storage account for the running identity
$expiry = (Get-Date).ToUniversalTime().AddDays(7).ToString("yyyy-MM-ddTHH:mm:ssZ")
$sas = az storage container generate-sas `
    --account-name awdustsaybmh --name lab-files `
    --permissions acw --expiry $expiry `
    --auth-mode login --as-user --https-only -o tsv

# Write BOM-free UTF-8 to a temp file — az keyvault secret set --value breaks on '&' in SAS
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$env:TEMP\sas-nobom.tmp", $sas.Trim(), $utf8NoBom)
az keyvault secret set --vault-name awdust-kv-ybmh --name current-write-sas --file "$env:TEMP\sas-nobom.tmp"
Remove-Item "$env:TEMP\sas-nobom.tmp"
```
**What it does:** generates a 7-day write-only SAS (maximum Azure allows for user-delegation) and writes it to KV. After manual rotation, investigate why the Automation job failed — check job output in the Automation Account Jobs blade.

**WARNING:** `--value` breaks silently on SAS tokens because the `&` separators confuse the CLI argument parser. Always use `--file` with a BOM-free UTF-8 temp file.

### 2. Cert rotation (every 90 days, with 14-day warning lead time)

The SP cert expires every 90 days. The push script writes a `_health/<host>-cert-expiring.json` blob when the cert is within 14 days; this surfaces in Log Analytics and (recommended) drives a separate alert.

**Procedure:**

1. From the deploy host, run:
   ```
   az ad app credential reset --id <appId> --create-cert --years 0.25
   ```
   This produces a new cert and emits the PEM.
2. Distribute the new PEM/PFX to each lab PC (per ADR-003 distribution channel).
3. On each lab PC, re-run `bootstrap.ps1` with the new cert. Bootstrap detects the old cert by thumbprint and replaces it.
4. After 1 push cycle from each lab PC, verify in LA that all hosts pushed with the new cert. Then revoke the old cert credential:
   ```
   az ad app credential delete --id <appId> --key-id <old-credential-key-id>
   ```

### 3. Lock immutability policy (one-time, post-deploy)

After the initial deploy, the immutability policy is in `Unlocked` state. This allows the operator to extend the retention period during the first 30 days. Once the retention period is correct, **lock it.**

**Command:**
```
$etag = (az storage container immutability-policy show --account-name <sa> --container-name lab-files -o json | ConvertFrom-Json).etag
az storage container immutability-policy lock --account-name <sa> --container-name lab-files --if-match $etag
```
**What it does:** transitions the policy from `Unlocked` to `Locked`. Once locked, retention can only be *extended*, never shortened.
**Expected output:** policy state returns `Locked`.

**Warning:** Locking is one-way. Do not lock until you are certain about the retention period.

### 4. Subscription-level resource lock (recommended)

To defend against threat OOS-4 (Subscription Owner-level rogue), apply a `CanNotDelete` lock at the subscription level (or RG level if subscription-level is too broad).

**Command:**
```
az lock create --name awacs-no-delete --resource-group <prefix>-rg --lock-type CanNotDelete --notes "AWACS backup; do not delete"
```

### 5. Adding a new lab workstation

1. Verify SP cert is current (>14 days remaining).
2. Copy the cert and `<prefix>-workstation-config.json` to the new lab PC.
3. Run `workstation/bootstrap.ps1` as the dedicated service account.
4. Wait for the next scheduled push (≤30 min).
5. Verify in LA: query `StorageBlobLogs | where Properties has '<new-hostname>'`.

### 6. Removing a lab workstation

1. On the lab PC, run `workstation/uninstall.ps1`. This removes the cert, scheduled task, and `C:\ProgramData\AwacsBackup\` (preserving `removed-certs/` for forensic continuity).
2. From the cloud side, the workstation will trigger the staleness alert at 25h. Acknowledge the alert (it's expected).
3. If desired, suppress future alerts for the decommissioned hostname by extending the alert KQL with a hostname-exclusion filter.

## Incident response

### A. Push is failing across all workstations

**First check:** Is the SAS in KV recent (within 7 days) and not expired?
```
az keyvault secret show --vault-name <kv> --name current-write-sas --query attributes.updated -o tsv
```
If older than 7 days, or if the SAS `se=` expiry is in the past, run the manual SAS rotation procedure above.

**Second check:** SP credentials current?
```
az ad app credential list --id <appId>
```
If all credentials are expired, run cert rotation procedure.

**Third check:** Network reachability from lab side. SSH/RDP into one lab PC and run:
```
Test-NetConnection -ComputerName <kv>.vault.azure.net -Port 443
Test-NetConnection -ComputerName <sa>.blob.core.windows.net -Port 443
```

### B. Immutability policy unexpectedly absent

Should not happen, but if it does:

1. Inspect `Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies`:
   ```
   az storage container immutability-policy show --account-name <sa> --container-name lab-files
   ```
2. If empty, re-apply via `components/04-immutability-policy/main.bicep` standalone deploy:
   ```
   az deployment group create -g <rg> --template-file components/04-immutability-policy/main.bicep --parameters storageAccountName=<sa> containerName=lab-files retentionDays=90
   ```

### C. Suspected credential compromise

1. Immediately rotate cert and SAS (per procedures 1 and 2 above).
2. Pull `StorageBlobLogs` and `KeyVaultLogs` for the past 30 days; look for source IPs not matching known lab PC subnets.
3. If active misuse: use Storage account firewall to deny the rogue IP, or temporarily disable the SP (`az ad sp update --id <appId> --set accountEnabled=false`).
4. Captured ledger of what data the rogue could have accessed (SP can only write — no read — so confidentiality of prior backups is intact unless the consumer side is also compromised).

### D. Storage account near quota

`Standard_GRS` has effectively unlimited per-account capacity, but cost grows. Operator periodically reviews via:
```
az monitor metrics list --resource <sa-id> --metric UsedCapacity --aggregation Average
```

If retention extension is needed beyond default 90 days, parameterize at deploy time and redeploy component 04 (extension is allowed even when locked).

## Audit / Compliance review

Quarterly:

1. Run `./deploy/verify.ps1` — every test should pass.
2. Run `tests/scripts/CIS-*.ps1` standalone — capture output for compliance evidence.
3. Inspect the diag setting on each component to confirm it still points at the LA workspace.
4. Review LA retention setting against your compliance regime.
5. Sample `KeyVaultLogs` for any `OperationName = SecretGet` events from non-SP identities — investigate any.

## Known startup behaviors

- **Day-1 staleness alert "always on":** the `>25h since last push` alert evaluates over a 25h sliding window. On a brand-new workspace, no pushes exist yet, so the alert flags every host as stale until first push lands. Suppress for the first 26h, or simply ignore the first day's noise.
- **Bicep deploy of immutability policy may flake on first attempt:** if the container creation API call has not fully propagated when the policy resource is created, the deploy fails. Re-run the deploy; the second attempt succeeds. (Idempotency check D6.3 covers this.)

## When in doubt

Inspect `docs/session-notes/` for context on why something was decided. Inspect `docs/decisions/` (ADRs) for the trade-off rationale on architectural choices.
