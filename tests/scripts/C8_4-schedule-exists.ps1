#Requires -Version 5.1
<#
.SYNOPSIS
  Test C8.4: Schedule every-6-days exists, is enabled, and has correct interval.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ResourceGroup)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/_helpers.psm1" -Force

Write-Host "C8.4  -  Schedule every-6-days exists and is correct"
$acct = Get-AwacsAutomationAccount -ResourceGroup $ResourceGroup
$sched = az automation schedule show --resource-group $ResourceGroup --automation-account-name $acct.name --name 'every-6-days' --only-show-errors --output json | ConvertFrom-Json
if ($null -eq $sched) { Write-Host "  [FAIL] Schedule 'every-6-days' not found in $($acct.name)" -ForegroundColor Red; exit 1 }

$isDay      = Test-Assert -Description "Schedule frequency is Day" -Condition ($sched.frequency -eq 'Day') -ActualDetail $sched.frequency
$is6Days    = Test-Assert -Description "Schedule interval is 6" -Condition ($sched.interval -eq 6) -ActualDetail "$($sched.interval)"
$isEnabled  = Test-Assert -Description "Schedule is enabled" -Condition ($sched.isEnabled -eq $true) -ActualDetail "$($sched.isEnabled)"

$ok = $isDay -and $is6Days -and $isEnabled
exit ($(if ($ok) { 0 } else { 1 }))
