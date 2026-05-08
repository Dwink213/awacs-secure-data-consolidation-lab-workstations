#Requires -Version 5.1
<#
.SYNOPSIS
  Test C8.3: Runbook rotate-sas is Published and PowerShell type.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ResourceGroup)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/_helpers.psm1" -Force

Write-Host "C8.3  -  Runbook rotate-sas is Published"
$acct = Get-AwacsAutomationAccount -ResourceGroup $ResourceGroup
$rb = az automation runbook show --resource-group $ResourceGroup --automation-account-name $acct.name --name 'rotate-sas' --only-show-errors --output json | ConvertFrom-Json
if ($null -eq $rb) { Write-Host "  [FAIL] Runbook 'rotate-sas' not found in $($acct.name)" -ForegroundColor Red; exit 1 }

$isPublished = Test-Assert -Description "Runbook state is Published" -Condition ($rb.state -eq 'Published') -ActualDetail $rb.state
$isPowerShell = Test-Assert -Description "Runbook type is PowerShell" -Condition ($rb.runbookType -eq 'PowerShell') -ActualDetail $rb.runbookType
$ok = $isPublished -and $isPowerShell
exit ($(if ($ok) { 0 } else { 1 }))
