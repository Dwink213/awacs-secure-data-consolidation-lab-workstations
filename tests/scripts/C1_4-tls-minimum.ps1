#Requires -Version 5.1
<#
.SYNOPSIS
  Test C1.4: minimumTlsVersion is TLS1_2.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ResourceGroup, [string]$Prefix)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/_helpers.psm1" -Force

Write-Host "C1.4  -  Storage Account: TLS1_2 minimum"
$sa = Get-AwacsStorageAccount -ResourceGroup $ResourceGroup
$ok = Test-Assert -Description "minimumTlsVersion is TLS1_2 on $($sa.name)" -Condition ($sa.minimumTlsVersion -eq 'TLS1_2') -ActualDetail "$($sa.minimumTlsVersion)"
exit ($(if ($ok) { 0 } else { 1 }))
