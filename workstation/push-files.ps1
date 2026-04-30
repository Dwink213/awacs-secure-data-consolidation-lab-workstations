#Requires -Version 5.1
<#
.SYNOPSIS
  Component 07: lab workstation push to immutable Azure blob.

.DESCRIPTION
  Loads config + cert, authenticates as SP, fetches today's SAS from KV,
  pushes new files to the storage container, logs everything.

.NOTES
  Defenses cited: T1, T2, T4 (cert non-exportable), T5 (TLS), F4.* (graceful failure),
  C7.1, C7.2 (contracts).
#>
[CmdletBinding()]
param(
  [string]$ConfigPath = 'C:\ProgramData\AwacsBackup\config.json'
)

$ErrorActionPreference = 'Stop'

# Step 0: load config and start logging
$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$logFile = Join-Path $config.logDirectory "push-$(Get-Date -Format yyyy-MM-dd).log"
if (-not (Test-Path $config.logDirectory)) { New-Item -ItemType Directory -Path $config.logDirectory | Out-Null }
Start-Transcript -Path $logFile -Append -IncludeInvocationHeader | Out-Null

function Write-Log {
  param([string]$Level, [string]$Message)
  $ts = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss')
  Write-Output "[$ts] [$Level] $Message"
}

function Redact-Sas { param([string]$Text) return ($Text -replace 'sig=[^&]+', 'sig=[REDACTED]') }

try {
  Write-Log INFO "Push starting on $env:COMPUTERNAME"
  Write-Log INFO "Cert thumbprint configured: $($config.certThumbprint)"

  # Step 1: cert self-check (expiry warning)
  $cert = Get-ChildItem Cert:\CurrentUser\My | Where-Object { $_.Thumbprint -eq $config.certThumbprint }
  if (-not $cert) { throw "Cert with thumbprint $($config.certThumbprint) not found in CurrentUser\My" }
  $daysToExpiry = ($cert.NotAfter - (Get-Date)).TotalDays
  Write-Log INFO "Cert expires in $([math]::Round($daysToExpiry,1)) days"
  if ($daysToExpiry -lt 14) {
    Write-Log CRITICAL "Cert expiring within 14 days. Initiating health-blob signal."
    $healthDir = Join-Path $config.logDirectory '_health'
    if (-not (Test-Path $healthDir)) { New-Item -ItemType Directory -Path $healthDir | Out-Null }
    @{ hostname=$env:COMPUTERNAME; thumbprint=$config.certThumbprint; expiresUtc=$cert.NotAfter.ToUniversalTime().ToString('o'); daysRemaining=[math]::Round($daysToExpiry,1) } | ConvertTo-Json | Out-File (Join-Path $healthDir "$env:COMPUTERNAME-cert-expiring.json") -Encoding utf8
  }

  # Step 2: AAD authn
  Write-Log INFO "Authenticating to Entra ID as SP $($config.clientId)..."
  Connect-AzAccount -ServicePrincipal -CertificateThumbprint $config.certThumbprint -ApplicationId $config.clientId -Tenant $config.tenantId -WarningAction SilentlyContinue | Out-Null
  Write-Log INFO "AAD auth OK"

  # Step 3: fetch SAS
  Write-Log INFO "Fetching SAS from $($config.keyVaultName) / $($config.secretName)..."
  $sasSecret = (Get-AzKeyVaultSecret -VaultName $config.keyVaultName -Name $config.secretName -AsPlainText).TrimStart([char]0xFEFF).Trim()
  if ([string]::IsNullOrWhiteSpace($sasSecret)) { throw "SAS secret empty or missing" }
  Write-Log INFO "SAS fetched (length: $($sasSecret.Length), starts: $($sasSecret.Substring(0,[Math]::Min(5,$sasSecret.Length))))"

  # Step 4: enumerate new files
  if (-not (Test-Path $config.watchDirectory)) {
    Write-Log WARN "Watch directory $($config.watchDirectory) does not exist; nothing to push"
    Stop-Transcript | Out-Null
    exit 0
  }
  $ledger = if (Test-Path $config.ledgerPath) { Get-Content $config.ledgerPath -Raw | ConvertFrom-Json } else { @() }
  $ledgerSet = @{}
  foreach ($entry in $ledger) { $ledgerSet[$entry.path] = $entry.sha256 }

  $files = Get-ChildItem -Path $config.watchDirectory -File -Recurse
  $toPush = @()
  foreach ($f in $files) {
    $sha = (Get-FileHash -Path $f.FullName -Algorithm SHA256).Hash
    if (-not $ledgerSet.ContainsKey($f.FullName) -or $ledgerSet[$f.FullName] -ne $sha) {
      $toPush += [pscustomobject]@{ Path=$f.FullName; Sha=$sha; Length=$f.Length; RelPath=$f.FullName.Substring($config.watchDirectory.Length).TrimStart('\','/') }
    }
  }
  Write-Log INFO "Files to push: $($toPush.Count) of $($files.Count) total"

  # Step 5: PUT each new file via SAS
  $ctx = New-AzStorageContext -StorageAccountName $config.storageAccountName -SasToken $sasSecret
  $datePart = Get-Date -Format yyyy-MM-dd
  $pushedThisRun = @()
  foreach ($f in $toPush) {
    $blobName = "$env:COMPUTERNAME/$datePart/$($f.RelPath)"
    try {
      Set-AzStorageBlobContent -File $f.Path -Container $config.containerName -Blob $blobName -Context $ctx -Force | Out-Null
      Write-Log INFO "PUT OK: $blobName ($($f.Length) bytes, sha=$($f.Sha.Substring(0,12)))"
      $pushedThisRun += [pscustomobject]@{ path=$f.Path; sha256=$f.Sha; pushedUtc=(Get-Date).ToUniversalTime().ToString('o'); blobName=$blobName }
    } catch {
      $msg = Redact-Sas $_.Exception.Message
      Write-Log ERROR "PUT FAIL: $blobName  -  $msg"
      # continue with next file rather than fail the whole run
    }
  }

  # Step 6: update ledger AFTER successful pushes
  if ($pushedThisRun.Count -gt 0) {
    $newLedger = @($ledger) + $pushedThisRun
    $newLedger | ConvertTo-Json -Depth 5 | Out-File -FilePath $config.ledgerPath -Encoding utf8
    Write-Log INFO "Ledger updated with $($pushedThisRun.Count) new entries"
  }

  # Step 7: rotate old transcripts
  $cutoff = (Get-Date).AddDays(-$config.logRetentionDays)
  Get-ChildItem -Path $config.logDirectory -Filter 'push-*.log' -File | Where-Object { $_.LastWriteTime -lt $cutoff } | Remove-Item -Force -ErrorAction SilentlyContinue

  Write-Log INFO "Push complete: $($pushedThisRun.Count) files pushed."
  Stop-Transcript | Out-Null
  exit 0
} catch {
  $msg = Redact-Sas $_.Exception.Message
  Write-Log ERROR "Push failed: $msg"
  Write-Log ERROR ($_.ScriptStackTrace)
  Stop-Transcript | Out-Null
  exit 1
}
