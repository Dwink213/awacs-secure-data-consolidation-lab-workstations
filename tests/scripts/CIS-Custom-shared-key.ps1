#Requires -Version 5.1
<#
.SYNOPSIS
  Test CIS-Custom: Shared-key auth disabled.
  Wrapper around C1.3.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ResourceGroup, [string]$Prefix)
$ErrorActionPreference = 'Stop'
& "$PSScriptRoot/C1_3-shared-key-disabled.ps1" -ResourceGroup $ResourceGroup -Prefix $Prefix
exit $LASTEXITCODE
