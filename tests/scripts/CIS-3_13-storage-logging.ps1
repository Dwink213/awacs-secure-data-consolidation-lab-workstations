#Requires -Version 5.1
<#
.SYNOPSIS
  Test CIS-3.13: Storage logging enabled (read/write/delete).
  This is a thin wrapper around C5.1  -  same diag setting check.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ResourceGroup, [string]$Prefix)
$ErrorActionPreference = 'Stop'
& "$PSScriptRoot/C5_1-diag-settings.ps1" -ResourceGroup $ResourceGroup -Prefix $Prefix
exit $LASTEXITCODE
