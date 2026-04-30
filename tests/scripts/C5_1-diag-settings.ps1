#Requires -Version 5.1
<#
.SYNOPSIS
  Test C5.1: Diagnostic settings forward to Log Analytics.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ResourceGroup, [string]$Prefix)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/_helpers.psm1" -Force

Write-Host "C5.1 — Diagnostic settings present"
$sa = Get-AwacsStorageAccount -ResourceGroup $ResourceGroup
$kv = Get-AwacsKeyVault -ResourceGroup $ResourceGroup

$blobScope = "$($sa.id)/blobServices/default"
$saDiag = az monitor diagnostic-settings list --resource $blobScope --output json 2>$null | ConvertFrom-Json
$ok1 = Test-Assert "Storage blob service has diag setting" (($null -ne $saDiag) -and ($saDiag.value.Count -ge 1)) "found $($saDiag.value.Count)"
if ($ok1) {
  $cats = $saDiag.value[0].logs | Where-Object { $_.enabled -eq $true } | ForEach-Object { $_.category }
  $ok2 = Test-Assert "StorageRead enabled" ($cats -contains 'StorageRead')
  $ok3 = Test-Assert "StorageWrite enabled" ($cats -contains 'StorageWrite')
  $ok4 = Test-Assert "StorageDelete enabled" ($cats -contains 'StorageDelete')
}
$kvDiag = az monitor diagnostic-settings list --resource $kv.id --output json 2>$null | ConvertFrom-Json
$ok5 = Test-Assert "Key Vault has diag setting" (($null -ne $kvDiag) -and ($kvDiag.value.Count -ge 1)) "found $($kvDiag.value.Count)"
if ($ok5) {
  $kvCats = $kvDiag.value[0].logs | Where-Object { $_.enabled -eq $true } | ForEach-Object { $_.category }
  $ok6 = Test-Assert "AuditEvent enabled on KV" ($kvCats -contains 'AuditEvent')
}

$all = @($ok1, $ok2, $ok3, $ok4, $ok5, $ok6) | Where-Object { $null -ne $_ }
exit ($(if ($all -contains $false) { 1 } else { 0 }))
