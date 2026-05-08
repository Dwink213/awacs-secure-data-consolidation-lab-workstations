#Requires -Version 5.1
<#
.SYNOPSIS
  Test C8.1: Automation Account exists with MSI and correct SKU.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ResourceGroup)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/_helpers.psm1" -Force

Write-Host "C8.1  -  Automation Account exists with MSI"
$acct = Get-AwacsAutomationAccount -ResourceGroup $ResourceGroup
$hasState  = Test-Assert -Description "Automation Account state is Ok" -Condition ($acct.state -eq 'Ok') -ActualDetail $acct.state
$hasMsi    = Test-Assert -Description "System-assigned MSI is enabled (principalId present)" -Condition (-not [string]::IsNullOrEmpty($acct.identity.principalId)) -ActualDetail "$($acct.identity.principalId)"
$hasSku    = Test-Assert -Description "SKU is Free or Basic (Free maps to Basic in API)" -Condition ($acct.sku.name -in 'Free','Basic') -ActualDetail $acct.sku.name
$ok = $hasState -and $hasMsi -and $hasSku
exit ($(if ($ok) { 0 } else { 1 }))
