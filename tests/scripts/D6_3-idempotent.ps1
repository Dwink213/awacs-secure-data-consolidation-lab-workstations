#Requires -Version 5.1
<#
.SYNOPSIS
  Test D6.3: Re-deploy is idempotent (what-if shows zero changes).
#>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ResourceGroup, [string]$Prefix)
$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/_helpers.psm1" -Force

Write-Host "D6.3 — Bicep redeploy is idempotent"
if (-not $Prefix) { Write-Host "[SKIP] -Prefix required" -ForegroundColor Yellow; exit 0 }

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$bicepPath = Join-Path $repoRoot 'deploy/main.bicep'
if (-not (Test-Path $bicepPath)) { Write-Host "[SKIP] deploy/main.bicep missing" -ForegroundColor Yellow; exit 0 }

# Use what-if; cannot easily re-run full deploy without all parameters, so we
# do a what-if with the parameter file template (operator must adapt).
$paramFile = Join-Path $repoRoot 'out/deploy-params.json'
if (-not (Test-Path $paramFile)) {
  Write-Host "[SKIP] No parameter file at out/deploy-params.json; this test requires post-deploy parameter capture" -ForegroundColor Yellow
  exit 0
}

$result = az deployment group what-if --resource-group $ResourceGroup --template-file $bicepPath --parameters "@$paramFile" --result-format ResourceIdOnly --output json 2>$null | ConvertFrom-Json
$changes = $result.changes | Where-Object { $_.changeType -ne 'Ignore' -and $_.changeType -ne 'NoChange' }
$ok = Test-Assert "Zero non-noop changes in what-if" ($changes.Count -eq 0) "$($changes.Count) changes"
exit ($(if ($ok) { 0 } else { 1 }))
