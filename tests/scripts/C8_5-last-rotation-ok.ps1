#Requires -Version 5.1
<#
.SYNOPSIS
  Test C8.5: At least one Completed rotation job exists within the last 7 days.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ResourceGroup)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/_helpers.psm1" -Force

Write-Host "C8.5  -  Last rotation job succeeded within 7 days"
$acct = Get-AwacsAutomationAccount -ResourceGroup $ResourceGroup
$jobs = az automation job list --resource-group $ResourceGroup --automation-account-name $acct.name --only-show-errors --output json | ConvertFrom-Json

$cutoff = (Get-Date).ToUniversalTime().AddDays(-7)
$recentCompleted = $jobs | Where-Object {
    $_.status -eq 'Completed' -and
    -not [string]::IsNullOrEmpty($_.endTime) -and
    [datetime]::Parse($_.endTime) -gt $cutoff
}

$hasRecent = Test-Assert -Description "At least 1 Completed job in the last 7 days" -Condition ($recentCompleted.Count -gt 0) -ActualDetail "found=$($recentCompleted.Count); last status=$(($jobs | Select-Object -First 1).status)"
exit ($(if ($hasRecent) { 0 } else { 1 }))
