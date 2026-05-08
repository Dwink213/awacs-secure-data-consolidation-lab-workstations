# SAS Rotator — Azure Automation PowerShell runbook
# Schedule: 'every-6-days' (noon UTC, NCRONTAB equivalent: 0 0 12 */6 * *)
# Identity: system-assigned MSI (no credentials stored anywhere)
#
# Required RBAC on MSI (assigned by main.bicep):
#   Storage Blob Delegator       — storage account scope  → GetUserDelegationKey
#   Storage Blob Data Contributor — container scope        → SAS can embed acw perms
#   Key Vault Secrets Officer    — secret resource scope  → write new secret version
#
# Config is read from Automation Variables (set by main.bicep at deploy time):
#   StorageAccountName, ContainerName, KeyVaultName, SecretName

Connect-AzAccount -Identity -ErrorAction Stop | Out-Null

$saName        = Get-AutomationVariable -Name 'StorageAccountName'
$containerName = Get-AutomationVariable -Name 'ContainerName'
$kvName        = Get-AutomationVariable -Name 'KeyVaultName'
$secretName    = Get-AutomationVariable -Name 'SecretName'

# 6d 23h validity — issued every 6 days, so 23h overlap if a run fires late.
# Azure hard cap for user-delegation SAS is 7 days; we stay 1h inside that.
$expiryUtc = (Get-Date).ToUniversalTime().AddDays(7).AddHours(-1)

Write-Output "INFO  rotate-sas: generating SAS for $saName/$containerName, expiry $expiryUtc UTC"

try {
    $ctx = New-AzStorageContext -StorageAccountName $saName -UseConnectedAccount -ErrorAction Stop

    $sas = New-AzStorageContainerSASToken `
        -Context    $ctx `
        -Name       $containerName `
        -Permission 'acw' `
        -ExpiryTime $expiryUtc `
        -Protocol   HttpsOnly `
        -ErrorAction Stop

    # New-AzStorageContainerSASToken sometimes prepends '?' — strip it
    $sas = $sas.TrimStart('?')

    if ([string]::IsNullOrWhiteSpace($sas)) {
        throw "Generated SAS token is empty — MSI may lack required roles."
    }

    Write-Output "INFO  rotate-sas: SAS generated, length=$($sas.Length) chars, permissions=acw"

    $secureVal = ConvertTo-SecureString $sas -AsPlainText -Force
    Set-AzKeyVaultSecret `
        -VaultName   $kvName `
        -Name        $secretName `
        -SecretValue $secureVal `
        -ErrorAction Stop | Out-Null

    Write-Output "INFO  rotate-sas: secret '$secretName' updated in vault '$kvName'"
    Write-Output "INFO  rotate-sas: rotation complete. Next fire in ~6 days. Expiry: $expiryUtc UTC"

} catch {
    # Write-Error marks the Automation job as Failed — surfaces in Log Analytics alert
    Write-Error "CRITICAL rotate-sas: rotation failed. Workstation pushes will break at expiry. Error: $_"
    throw
}
