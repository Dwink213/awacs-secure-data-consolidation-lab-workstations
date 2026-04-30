#Requires -Version 5.1
<#
.SYNOPSIS
  Test C1.1: Storage Account is HTTPS-only.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ResourceGroup, [string]$Prefix)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/_helpers.psm1" -Force

Write-Host "C1.1 — Storage Account HTTPS-only"
$sa = Get-AwacsStorageAccount -ResourceGroup $ResourceGroup
$ok = Test-Assert -Description "supportsHttpsTrafficOnly is true on $($sa.name)" -Condition ($sa.enableHttpsTrafficOnly -eq $true) -ActualDetail "$($sa.enableHttpsTrafficOnly)"
exit ($(if ($ok) { 0 } else { 1 }))
