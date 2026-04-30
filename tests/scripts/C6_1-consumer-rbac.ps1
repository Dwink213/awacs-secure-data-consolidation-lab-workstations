#Requires -Version 5.1
<#
.SYNOPSIS
  Test C6.1: Consumer group has Storage Blob Data Reader on the container, no other RBAC.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ResourceGroup, [string]$Prefix)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/_helpers.psm1" -Force

Write-Host "C6.1  -  Consumer RBAC: Reader only"
$sa = Get-AwacsStorageAccount -ResourceGroup $ResourceGroup
$containerScope = "$($sa.id)/blobServices/default/containers/lab-files"
$assignments = az role assignment list --scope $containerScope --output json | ConvertFrom-Json
$readers = $assignments | Where-Object { $_.principalType -eq 'Group' -and $_.roleDefinitionName -eq 'Storage Blob Data Reader' }
$nonReaderGroupAssignments = $assignments | Where-Object { $_.principalType -eq 'Group' -and $_.roleDefinitionName -ne 'Storage Blob Data Reader' }

$ok1 = Test-Assert "At least one Group has Storage Blob Data Reader" ($readers.Count -ge 1) "$($readers.Count)"
$ok2 = Test-Assert "No Group has any non-Reader role on container" ($nonReaderGroupAssignments.Count -eq 0) "$($nonReaderGroupAssignments.Count) extra"
exit ($(if (($ok1 -and $ok2)) { 0 } else { 1 }))
