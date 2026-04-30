#Requires -Version 5.1
<#
.SYNOPSIS
  Test C2.2: Key Vault uses RBAC authorization (not access policies).
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ResourceGroup, [string]$Prefix)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/_helpers.psm1" -Force

Write-Host "C2.2  -  Key Vault: RBAC mode"
$kv = Get-AwacsKeyVault -ResourceGroup $ResourceGroup
$ok = Test-Assert "enableRbacAuthorization is true" ($kv.properties.enableRbacAuthorization -eq $true) "$($kv.properties.enableRbacAuthorization)"
exit ($(if ($ok) { 0 } else { 1 }))
