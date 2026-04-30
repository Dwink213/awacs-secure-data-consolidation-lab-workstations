#Requires -Version 5.1
<#
.SYNOPSIS
  Test C3.1: Service Principal has cert credentials only, no client secret.
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ResourceGroup, [string]$Prefix)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/_helpers.psm1" -Force

Write-Host "C3.1 — SP: cert credentials only"
if (-not $Prefix) { Write-Host "[SKIP] -Prefix required to locate SP" -ForegroundColor Yellow; exit 0 }
$sps = az ad sp list --display-name "$Prefix-lab-sp-" --output json | ConvertFrom-Json
$ok1 = Test-Assert "Found SP matching '$Prefix-lab-sp-*'" ($sps.Count -ge 1) "$($sps.Count) SPs"
if (-not $ok1) { exit 1 }
$sp = $sps[0]
$creds = az ad app credential list --id $sp.appId --output json | ConvertFrom-Json
# az ad app credential list returns *certificate* credentials only (passwordCredentials are listed via show)
$app = az ad app show --id $sp.appId --output json | ConvertFrom-Json
$ok2 = Test-Assert "No passwordCredentials" (($null -eq $app.passwordCredentials) -or ($app.passwordCredentials.Count -eq 0)) "$($app.passwordCredentials.Count) password credentials present"
$ok3 = Test-Assert "At least one keyCredential (cert)" (($null -ne $app.keyCredentials) -and ($app.keyCredentials.Count -ge 1)) "$($app.keyCredentials.Count) key credentials"
exit ($(if (($ok1 -and $ok2 -and $ok3)) { 0 } else { 1 }))
