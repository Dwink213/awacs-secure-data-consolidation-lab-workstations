#Requires -Version 5.1
<#
.SYNOPSIS
  Test C8.2: Automation MSI holds exactly the three required roles at correct scopes.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ResourceGroup)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/_helpers.psm1" -Force

Write-Host "C8.2  -  Automation MSI RBAC assignments"
$acct = Get-AwacsAutomationAccount -ResourceGroup $ResourceGroup
$msiId = $acct.identity.principalId
if ([string]::IsNullOrEmpty($msiId)) { throw "No MSI principal ID on Automation Account." }

$assignments = az role assignment list --assignee $msiId --all --output json | ConvertFrom-Json
$roles = $assignments | Select-Object -ExpandProperty roleDefinitionName

$hasDelegator   = Test-Assert -Description "Storage Blob Delegator assigned to MSI" -Condition ($roles -contains 'Storage Blob Delegator') -ActualDetail ($roles -join ', ')
$hasContributor = Test-Assert -Description "Storage Blob Data Contributor assigned to MSI" -Condition ($roles -contains 'Storage Blob Data Contributor') -ActualDetail ($roles -join ', ')
$hasOfficer     = Test-Assert -Description "Key Vault Secrets Officer assigned to MSI" -Condition ($roles -contains 'Key Vault Secrets Officer') -ActualDetail ($roles -join ', ')

# Verify scopes are container-level or narrower (not subscription or RG)
$subLevel = $assignments | Where-Object { $_.scope -match '^/subscriptions/[^/]+$' }
$rgLevel  = $assignments | Where-Object { $_.scope -match '^/subscriptions/[^/]+/resourceGroups/[^/]+$' }
$noOverBroad = Test-Assert -Description "No subscription-level or RG-level RBAC (tight scoping only)" -Condition ($subLevel.Count -eq 0 -and $rgLevel.Count -eq 0) -ActualDetail "sub=$($subLevel.Count) rg=$($rgLevel.Count)"

$ok = $hasDelegator -and $hasContributor -and $hasOfficer -and $noOverBroad
exit ($(if ($ok) { 0 } else { 1 }))
