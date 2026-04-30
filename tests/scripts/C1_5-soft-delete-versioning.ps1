#Requires -Version 5.1
<#
.SYNOPSIS
  Test C1.5: Soft delete and versioning enabled on the blob service.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ResourceGroup, [string]$Prefix)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/_helpers.psm1" -Force

Write-Host "C1.5  -  Soft delete + versioning + container delete retention"
$sa = Get-AwacsStorageAccount -ResourceGroup $ResourceGroup
$bs = az storage account blob-service-properties show --account-name $sa.name --resource-group $ResourceGroup -o json | ConvertFrom-Json
$results = @(
  Test-Assert "deleteRetentionPolicy.enabled" ($bs.deleteRetentionPolicy.enabled -eq $true) "$($bs.deleteRetentionPolicy.enabled)"
  Test-Assert "containerDeleteRetentionPolicy.enabled" ($bs.containerDeleteRetentionPolicy.enabled -eq $true) "$($bs.containerDeleteRetentionPolicy.enabled)"
  Test-Assert "isVersioningEnabled" ($bs.isVersioningEnabled -eq $true) "$($bs.isVersioningEnabled)"
)
exit ($(if ($results -contains $false) { 1 } else { 0 }))
