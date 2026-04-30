#Requires -Version 5.1
<#
.SYNOPSIS
  Runs the executable test battery against a deployed environment.

.DESCRIPTION
  Discovers all tests/scripts/*.ps1 files, dot-sources them, and executes the
  Test-* function each defines. Produces a structured report.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$ResourceGroup,
  [string]$Prefix
)

$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptsDir = Join-Path $repoRoot 'tests/scripts'

if (-not (Test-Path $scriptsDir)) {
  Write-Host "No test scripts directory at $scriptsDir" -ForegroundColor Yellow
  Write-Host "Tests are spec-only at this stage of the project."
  exit 0
}

$testFiles = Get-ChildItem -Path $scriptsDir -Filter '*.ps1' -File | Sort-Object Name
if ($testFiles.Count -eq 0) {
  Write-Host "No test scripts found in $scriptsDir" -ForegroundColor Yellow
  exit 0
}

$results = @()
foreach ($f in $testFiles) {
  $start = Get-Date
  $passed = $false
  $detail = ''
  try {
    & $f.FullName -ResourceGroup $ResourceGroup -Prefix $Prefix
    if ($LASTEXITCODE -eq 0) { $passed = $true; $detail = 'OK' }
    else { $detail = "exit code $LASTEXITCODE" }
  } catch {
    $detail = $_.Exception.Message
  }
  $duration = ((Get-Date) - $start).TotalSeconds
  $results += [pscustomobject]@{
    Test = $f.BaseName
    Status = if ($passed) { 'PASS' } else { 'FAIL' }
    DurationSec = [math]::Round($duration, 2)
    Detail = $detail
  }
}

$results | Format-Table -AutoSize
$failed = ($results | Where-Object { $_.Status -eq 'FAIL' }).Count
if ($failed -gt 0) {
  Write-Host ""
  Write-Host "$failed test(s) failed." -ForegroundColor Red
  exit 1
}
Write-Host ""
Write-Host "All $($results.Count) tests passed." -ForegroundColor Green
exit 0
