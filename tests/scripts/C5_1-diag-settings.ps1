#Requires -Version 5.1
<#
.SYNOPSIS
  Test C5.1: Diagnostic settings forward to Log Analytics.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ResourceGroup, [string]$Prefix)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/_helpers.psm1" -Force

Write-Host "C5.1  -  Diagnostic settings present"
$sa = Get-AwacsStorageAccount -ResourceGroup $ResourceGroup
$kv = Get-AwacsKeyVault -ResourceGroup $ResourceGroup

$blobScope = "$($sa.id)/blobServices/default"
$saDiagRaw = az monitor diagnostic-settings list --resource $blobScope --output json 2>$null | ConvertFrom-Json
# az CLI returns raw array on some versions, OData-wrapped on others
$saDiag = if ($saDiagRaw -is [System.Array]) { $saDiagRaw } elseif ($null -ne $saDiagRaw.value) { @($saDiagRaw.value) } else { @() }
$ok1 = Test-Assert "Storage blob service has diag setting" ($saDiag.Count -ge 1) "found $($saDiag.Count)"
if ($ok1) {
  $cats = $saDiag[0].logs | Where-Object { $_.enabled -eq $true } | ForEach-Object { $_.category }
  $ok2 = Test-Assert "StorageRead enabled" ($cats -contains 'StorageRead')
  $ok3 = Test-Assert "StorageWrite enabled" ($cats -contains 'StorageWrite')
  $ok4 = Test-Assert "StorageDelete enabled" ($cats -contains 'StorageDelete')
}
$kvDiagRaw = az monitor diagnostic-settings list --resource $kv.id --output json 2>$null | ConvertFrom-Json
$kvDiag = if ($kvDiagRaw -is [System.Array]) { $kvDiagRaw } elseif ($null -ne $kvDiagRaw.value) { @($kvDiagRaw.value) } else { @() }
$ok5 = Test-Assert "Key Vault has diag setting" ($kvDiag.Count -ge 1) "found $($kvDiag.Count)"
if ($ok5) {
  $kvCats = $kvDiag[0].logs | Where-Object { $_.enabled -eq $true } | ForEach-Object { $_.category }
  $ok6 = Test-Assert "AuditEvent enabled on KV" ($kvCats -contains 'AuditEvent')
}

$all = @($ok1, $ok2, $ok3, $ok4, $ok5, $ok6) | Where-Object { $null -ne $_ }
exit ($(if ($all -contains $false) { 1 } else { 0 }))
