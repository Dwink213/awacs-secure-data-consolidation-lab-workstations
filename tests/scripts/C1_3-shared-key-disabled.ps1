#Requires -Version 5.1
<#
.SYNOPSIS
  Test C1.3: Storage account shared-key auth is disabled.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ResourceGroup, [string]$Prefix)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/_helpers.psm1" -Force

Write-Host "C1.3 — Storage Account: shared-key disabled"
$sa = Get-AwacsStorageAccount -ResourceGroup $ResourceGroup
$ok = Test-Assert -Description "allowSharedKeyAccess is false on $($sa.name)" -Condition ($sa.allowSharedKeyAccess -eq $false) -ActualDetail "$($sa.allowSharedKeyAccess)"
exit ($(if ($ok) { 0 } else { 1 }))
