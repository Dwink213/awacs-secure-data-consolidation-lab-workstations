#Requires -Version 5.1
<#
.SYNOPSIS
  Test C8.6: KV secret contains a SAS with future expiry within the 7-day Azure cap.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ResourceGroup)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/_helpers.psm1" -Force

Write-Host "C8.6  -  SAS token expiry is valid (future, within 7-day cap)"
$kv  = Get-AwacsKeyVault -ResourceGroup $ResourceGroup
$sas = az keyvault secret show --vault-name $kv.name --name 'current-write-sas' --query value -o tsv 2>$null

if ([string]::IsNullOrWhiteSpace($sas)) {
    Write-Host "  [FAIL] current-write-sas secret is empty or not found" -ForegroundColor Red; exit 1
}

$nowUtc  = (Get-Date).ToUniversalTime()
$cap7d   = $nowUtc.AddDays(7)

if ($sas -notmatch 'se=([^&]+)') {
    Write-Host "  [FAIL] SAS token does not contain se= expiry parameter" -ForegroundColor Red; exit 1
}
$expiryStr = [uri]::UnescapeDataString($matches[1])
$expiry    = [datetime]::Parse($expiryStr, $null, [System.Globalization.DateTimeStyles]::RoundtripKind)

$isFuture  = Test-Assert -Description "SAS expiry is in the future" -Condition ($expiry -gt $nowUtc) -ActualDetail "expiry=$expiryStr now=$($nowUtc.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
$isWithin7 = Test-Assert -Description "SAS expiry is within 7-day Azure cap" -Condition ($expiry -le $cap7d) -ActualDetail "expiry=$expiryStr cap=$($cap7d.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
$hasAcw    = Test-Assert -Description "SAS permissions include acw (no read/delete)" -Condition ($sas -match 'sp=acw') -ActualDetail "$(if ($sas -match 'sp=([^&]+)') { $matches[1] } else { 'sp param not found' })"
$isHttps   = Test-Assert -Description "SAS is HTTPS-only (spr=https)" -Condition ($sas -match 'spr=https') -ActualDetail "$(if ($sas -match 'spr=([^&]+)') { $matches[1] } else { 'spr param not found' })"

$ok = $isFuture -and $isWithin7 -and $hasAcw -and $isHttps
exit ($(if ($ok) { 0 } else { 1 }))
