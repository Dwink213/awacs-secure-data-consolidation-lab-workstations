#Requires -Version 5.1
<#
.SYNOPSIS
  Cleanly removes the AWACS workstation backup install.

.DESCRIPTION
  - Unregisters scheduled task
  - Backs up the cert to ProgramData\AwacsBackup\removed-certs\<timestamp> (forensic continuity)
  - Removes cert from CurrentUser\My
  - Optionally removes ProgramData\AwacsBackup\ entirely
#>
[CmdletBinding()]
param(
  [string]$ConfigPath = 'C:\ProgramData\AwacsBackup\config.json',
  [switch]$KeepLogs
)

$ErrorActionPreference = 'Continue'
$progDataDir = 'C:\ProgramData\AwacsBackup'

# 1. Scheduled task
$task = Get-ScheduledTask -TaskName 'AwacsBackupPush' -ErrorAction SilentlyContinue
if ($task) {
  Unregister-ScheduledTask -TaskName 'AwacsBackupPush' -Confirm:$false
  Write-Host "Scheduled task removed." -ForegroundColor Green
} else {
  Write-Host "No scheduled task found." -ForegroundColor DarkGray
}

# 2. Cert
if (Test-Path $ConfigPath) {
  $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
  $cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Thumbprint -eq $config.certThumbprint }
  if ($cert) {
    $backupDir = Join-Path $progDataDir "removed-certs/$(Get-Date -Format yyyyMMddHHmmss)"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    $exportPath = Join-Path $backupDir "$($cert.Thumbprint).cer"
    [System.IO.File]::WriteAllBytes($exportPath, $cert.RawData)
    Write-Host "Cert public part backed up to $exportPath" -ForegroundColor Green
    Remove-Item -Path "Cert:\CurrentUser\My\$($cert.Thumbprint)"
    Write-Host "Cert removed from CurrentUser\My" -ForegroundColor Green
  } else {
    Write-Host "No matching cert found in store." -ForegroundColor DarkGray
  }
} else {
  Write-Host "No config.json found; skipping cert removal." -ForegroundColor Yellow
}

# 3. ProgramData
if ($KeepLogs) {
  Write-Host "Keeping $progDataDir per -KeepLogs flag." -ForegroundColor DarkGray
} else {
  if (Test-Path $progDataDir) {
    # Preserve removed-certs subfolder; clean everything else
    Get-ChildItem -Path $progDataDir -Exclude 'removed-certs' | Remove-Item -Recurse -Force
    Write-Host "$progDataDir cleaned (removed-certs/ preserved)." -ForegroundColor Green
  }
}

Write-Host ""
Write-Host "Uninstall complete." -ForegroundColor Green
Write-Host "Note: Az PowerShell modules are NOT removed (other apps may depend on them)."
Write-Host "      To remove manually: Uninstall-Module Az.Accounts, Az.Storage, Az.KeyVault"
