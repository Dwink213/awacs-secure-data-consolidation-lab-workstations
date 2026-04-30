#Requires -Version 5.1
<#
.SYNOPSIS
  One-shot installer for the AWACS Secure Lab Backup workstation side.

.DESCRIPTION
  Idempotent. Installs Az modules at pinned versions, imports the SP cert,
  copies push-files.ps1, registers the scheduled task, and writes config.

.PARAMETER ConfigPath
  Path to the workstation config JSON emitted by Deploy.ps1.

.PARAMETER CertPath
  Path to the SP cert PEM/PFX.

.PARAMETER CertPassword
  PFX password (only required if cert is .pfx).

.PARAMETER ServiceAccountUser
  Local user the scheduled task runs as. Defaults to current user.

.EXAMPLE
  ./bootstrap.ps1 -ConfigPath ./awacslab-workstation-config.json -CertPath ./awacslab-sp-cert.pem
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$ConfigPath,
  [Parameter(Mandatory=$true)][string]$CertPath,
  [string]$CertPassword,
  [string]$ServiceAccountUser = $env:USERNAME
)

$ErrorActionPreference = 'Stop'
$progDataDir = 'C:\ProgramData\AwacsBackup'
$logsDir = Join-Path $progDataDir 'logs'

function Write-Step {
  param([string]$Message, [ValidateSet('OK','SKIP','WARN','FAIL','INFO')][string]$Status = 'INFO')
  $color = switch ($Status) { 'OK' {'Green'} 'SKIP' {'DarkGray'} 'WARN' {'Yellow'} 'FAIL' {'Red'} default {'Cyan'} }
  Write-Host "[STEP] $Status  -  $Message" -ForegroundColor $color
}

# Step 1: ProgramData dirs
Write-Step "Creating $progDataDir..." 'INFO'
if (-not (Test-Path $progDataDir)) { New-Item -ItemType Directory -Path $progDataDir | Out-Null }
if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir | Out-Null }
Write-Step "ProgramData paths present" 'OK'

# Step 2: Install Az modules at pinned versions
$pinned = @{
  'Az.Accounts' = '2.13.2'
  'Az.Storage'  = '6.1.1'
  'Az.KeyVault' = '5.0.1'
}
foreach ($m in $pinned.Keys) {
  $v = $pinned[$m]
  $existing = Get-Module -ListAvailable -Name $m | Where-Object { $_.Version -eq [version]$v }
  if ($existing) {
    Write-Step "$m $v already installed" 'SKIP'
  } else {
    Write-Step "Installing $m $v from PSGallery..." 'INFO'
    Install-Module -Name $m -RequiredVersion $v -Scope CurrentUser -Force -AllowClobber
    Write-Step "$m $v installed" 'OK'
  }
}

# Step 3: Import cert
$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$expectedThumb = $config.certThumbprint
$existingCert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Thumbprint -eq $expectedThumb }
if ($existingCert) {
  Write-Step "Cert with thumbprint $expectedThumb already in CurrentUser\My" 'SKIP'
} else {
  Write-Step "Importing cert from $CertPath..." 'INFO'
  $ext = [System.IO.Path]::GetExtension($CertPath).ToLower()
  if ($ext -eq '.pfx') {
    if ([string]::IsNullOrEmpty($CertPassword)) { throw "PFX requires -CertPassword" }
    $securePfxPass = ConvertTo-SecureString $CertPassword -AsPlainText -Force
    Import-PfxCertificate -FilePath $CertPath -CertStoreLocation Cert:\CurrentUser\My -Password $securePfxPass -Exportable:$false | Out-Null
  } elseif ($ext -eq '.pem') {
    # PEM import: convert to X509 cert and add via cert store API
    $pemText = Get-Content $CertPath -Raw
    $certBlock = ($pemText -split '-----BEGIN CERTIFICATE-----')[1] -split '-----END CERTIFICATE-----' | Select-Object -First 1
    $certBytes = [Convert]::FromBase64String(($certBlock -replace '\s',''))
    $tempPfx = Join-Path $env:TEMP "awacs-import-$(Get-Random).pfx"
    # PEM with private key requires extracting the key block too  -  best handled by openssl externally
    Write-Step "PEM with private key import requires openssl on this host." 'WARN'
    Write-Step "  Run: openssl pkcs12 -export -out tmp.pfx -in $CertPath" 'INFO'
    Write-Step "  Then re-run this bootstrap with -CertPath tmp.pfx" 'INFO'
    throw "PEM-with-key import not natively supported in PowerShell 5.1; use openssl conversion."
  } else {
    throw "Cert path must be .pfx or .pem"
  }
  Write-Step "Cert imported (non-exportable)" 'OK'
}

# Step 4: Copy push-files.ps1
$pushScriptSrc = Join-Path $PSScriptRoot 'push-files.ps1'
$pushScriptDest = Join-Path $progDataDir 'push-files.ps1'
if (-not (Test-Path $pushScriptSrc)) { throw "push-files.ps1 missing alongside bootstrap.ps1" }
Copy-Item -Path $pushScriptSrc -Destination $pushScriptDest -Force
Write-Step "Copied push-files.ps1 to $pushScriptDest" 'OK'

# Step 5: Write config.json
$configDest = Join-Path $progDataDir 'config.json'
if (Test-Path $configDest) {
  Write-Step "Existing config detected at $configDest; backing up before overwrite" 'WARN'
  Copy-Item $configDest "$configDest.bak.$(Get-Date -Format yyyyMMddHHmmss)"
}
Copy-Item -Path $ConfigPath -Destination $configDest -Force
Write-Step "Config written to $configDest" 'OK'

# Step 6: Register scheduled task
$taskName = 'AwacsBackupPush'
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
  Write-Step "Scheduled task '$taskName' already exists" 'SKIP'
} else {
  Write-Step "Registering scheduled task '$taskName'..." 'INFO'
  $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$pushScriptDest`""
  $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 30)
  $principal = New-ScheduledTaskPrincipal -UserId $ServiceAccountUser -LogonType Interactive -RunLevel Limited
  $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 5)
  Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings | Out-Null
  Write-Step "Scheduled task registered to run every 30 minutes" 'OK'
}

Write-Host ""
Write-Host "Bootstrap complete." -ForegroundColor Green
Write-Host "Test the push manually: powershell.exe -File '$pushScriptDest'"
