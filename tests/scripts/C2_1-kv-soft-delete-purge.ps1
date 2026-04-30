#Requires -Version 5.1
<#
.SYNOPSIS
  Test C2.1: Key Vault has soft delete and purge protection enabled.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ResourceGroup, [string]$Prefix)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/_helpers.psm1" -Force

Write-Host "C2.1 — Key Vault: soft delete + purge protection"
$kv = Get-AwacsKeyVault -ResourceGroup $ResourceGroup
$results = @(
  Test-Assert "enableSoftDelete is true" ($kv.properties.enableSoftDelete -eq $true) "$($kv.properties.enableSoftDelete)"
  Test-Assert "enablePurgeProtection is true" ($kv.properties.enablePurgeProtection -eq $true) "$($kv.properties.enablePurgeProtection)"
)
exit ($(if ($results -contains $false) { 1 } else { 0 }))
