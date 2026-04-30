#Requires -Version 5.1
<#
.SYNOPSIS
  Test C4.1: Immutability policy applied to lab-files container.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ResourceGroup, [string]$Prefix)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/_helpers.psm1" -Force

Write-Host "C4.1 — Immutability policy applied"
$sa = Get-AwacsStorageAccount -ResourceGroup $ResourceGroup
$policy = az storage container immutability-policy show --account-name $sa.name --container-name 'lab-files' --output json 2>$null | ConvertFrom-Json
$ok1 = Test-Assert "Policy resource exists on lab-files" ($null -ne $policy) "null"
if (-not $ok1) { exit 1 }
$ok2 = Test-Assert "retention period > 0 days" ($policy.immutabilityPeriodSinceCreationInDays -gt 0) "$($policy.immutabilityPeriodSinceCreationInDays)"
$ok3 = Test-Assert "state is Locked or Unlocked (not absent)" (@('Locked','Unlocked') -contains $policy.state) "$($policy.state)"
exit ($(if (($ok1 -and $ok2 -and $ok3)) { 0 } else { 1 }))
