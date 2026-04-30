#Requires -Version 5.1
<#
.SYNOPSIS
  Turnkey deploy of the AWACS Secure Lab Workstation Backup system.

.DESCRIPTION
  - Runs preflight checks
  - Creates the resource group
  - Creates the Service Principal with cert (imperative; see ADR-003)
  - Deploys the orchestrator Bicep (components 01-06)
  - Generates and uploads the initial 24h SAS to Key Vault
  - Emits workstation config + cert location to stdout

.PARAMETER SubscriptionId
  Target subscription.

.PARAMETER Region
  Azure region.

.PARAMETER Prefix
  3-8 lowercase alphanumeric characters; drives all resource naming.

.PARAMETER ConsumerGroupObjectId
  Object ID of the Entra ID security group whose members can read backups.

.PARAMETER AlertEmail
  (Optional) Email for staleness alerts.

.PARAMETER ImmutabilityRetentionDays
  Retention period for immutability policy. Default 90.

.EXAMPLE
  ./Deploy.ps1 -SubscriptionId xxx -Region eastus2 -Prefix awacslab -ConsumerGroupObjectId yyy -AlertEmail ops@example.com
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$SubscriptionId,
  [Parameter(Mandatory=$true)][string]$Region,
  [Parameter(Mandatory=$true)][string]$Prefix,
  [Parameter(Mandatory=$true)][string]$ConsumerGroupObjectId,
  [string]$AlertEmail = '',
  [int]$ImmutabilityRetentionDays = 90
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $repoRoot 'out'
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

# Step 1: preflight
Write-Host "==> Running preflight..." -ForegroundColor Cyan
& "$PSScriptRoot/preflight.ps1" -SubscriptionId $SubscriptionId -Region $Region -Prefix $Prefix
if ($LASTEXITCODE -ne 0) {
  Write-Host "Preflight failed. Aborting deploy." -ForegroundColor Red
  exit 1
}

# Step 2: set subscription, create RG
Write-Host "==> Setting subscription and creating resource group..." -ForegroundColor Cyan
az account set --subscription $SubscriptionId | Out-Null
$rgName = "$Prefix-rg"
az group create --name $rgName --location $Region --tags project=awacs-secure-data-consolidation | Out-Null

# Step 3: create SP with cert (imperative — see ADR-003)
Write-Host "==> Creating Service Principal with cert..." -ForegroundColor Cyan
$spName = "$Prefix-lab-sp-$(Get-Date -Format yyyyMMddHHmm)"
$spJson = az ad sp create-for-rbac --name $spName --create-cert --years 0.25 --skip-assignment --output json | ConvertFrom-Json
if (-not $spJson.appId) { throw "SP creation failed." }

$spAppId = $spJson.appId
$tenantId = $spJson.tenant
# az writes the cert to the user's profile under .azure; locate and copy to ./out
$certSourcePath = Join-Path $env:USERPROFILE ".azure/$($spJson.fileWithCertAndPrivateKey -replace '.*[/\\]','')"
if (-not (Test-Path $certSourcePath)) {
  # az versions vary in where they place the file; fall back to scanning
  $certSourcePath = (Get-ChildItem -Path "$env:USERPROFILE/.azure" -Filter "*.pem" -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
$certDest = Join-Path $outDir "$Prefix-sp-cert-$(Get-Date -Format yyyyMMddHHmm).pem"
Copy-Item -Path $certSourcePath -Destination $certDest -Force

# Resolve principal (object) ID for RBAC
$spObjectId = (az ad sp show --id $spAppId --output json | ConvertFrom-Json).id

# Compute thumbprint from the PEM (for the workstation config)
$pemText = Get-Content $certDest -Raw
$certBlock = ($pemText -split '-----BEGIN CERTIFICATE-----')[1] -split '-----END CERTIFICATE-----' | Select-Object -First 1
$certBytes = [Convert]::FromBase64String(($certBlock -replace '\s',''))
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(,$certBytes)
$thumbprint = $cert.Thumbprint

# Step 4: deploy Bicep
Write-Host "==> Deploying Bicep modules..." -ForegroundColor Cyan
$deployName = "awacs-deploy-$(Get-Date -Format yyyyMMddHHmm)"
$deployResult = az deployment group create `
  --resource-group $rgName `
  --name $deployName `
  --template-file "$PSScriptRoot/main.bicep" `
  --parameters prefix=$Prefix location=$Region servicePrincipalObjectId=$spObjectId consumerGroupObjectId=$ConsumerGroupObjectId immutabilityRetentionDays=$ImmutabilityRetentionDays alertEmail=$AlertEmail `
  --output json | ConvertFrom-Json

if ($null -eq $deployResult) { throw "Bicep deployment failed." }

$saName = $deployResult.properties.outputs.storageAccountName.value
$containerName = $deployResult.properties.outputs.containerName.value
$kvName = $deployResult.properties.outputs.keyVaultName.value
$kvUri = $deployResult.properties.outputs.keyVaultUri.value
$secretName = $deployResult.properties.outputs.secretName.value
$blobEndpoint = $deployResult.properties.outputs.blobEndpoint.value

# Step 5: generate initial 24h SAS, upload to KV
Write-Host "==> Generating initial 24h SAS and uploading to Key Vault..." -ForegroundColor Cyan
$expiry = (Get-Date).ToUniversalTime().AddHours(24).ToString("yyyy-MM-ddTHH:mm:ssZ")

# SAS is generated using user-delegation key (since shared key is disabled).
$udKey = az storage account keys list --account-name $saName --output json 2>$null
# Note: with allowSharedKeyAccess=false, this fails. Use user-delegation SAS.
$sas = az storage container generate-sas `
  --account-name $saName `
  --name $containerName `
  --permissions acw `
  --expiry $expiry `
  --auth-mode login `
  --as-user `
  --https-only `
  --output tsv 2>$null

if ([string]::IsNullOrWhiteSpace($sas)) {
  Write-Host "WARNING: Could not generate user-delegation SAS automatically." -ForegroundColor Yellow
  Write-Host "  This usually means the deploying identity needs Storage Blob Delegator role on the SA."
  Write-Host "  The KV secret currently holds a placeholder. Fill it manually:" -ForegroundColor Yellow
  Write-Host "    az keyvault secret set --vault-name $kvName --name $secretName --value '<sas>'"
} else {
  az keyvault secret set --vault-name $kvName --name $secretName --value $sas | Out-Null
  Write-Host "Initial SAS uploaded to KV secret '$secretName'." -ForegroundColor Green
}

# Step 6: emit workstation config + summary
$configObj = [ordered]@{
  tenantId = $tenantId
  clientId = $spAppId
  certThumbprint = $thumbprint
  keyVaultName = $kvName
  secretName = $secretName
  storageAccountName = $saName
  containerName = $containerName
  watchDirectory = 'C:\labdata'
  logDirectory = 'C:\ProgramData\AwacsBackup\logs'
  ledgerPath = 'C:\ProgramData\AwacsBackup\pushed.json'
  logRetentionDays = 14
}
$configPath = Join-Path $outDir "$Prefix-workstation-config.json"
$configObj | ConvertTo-Json -Depth 5 | Out-File -FilePath $configPath -Encoding utf8

# Portal URL
$portalUrl = "https://portal.azure.com/#@$tenantId/resource/subscriptions/$SubscriptionId/resourceGroups/$rgName/overview"

Write-Host ""
Write-Host "================== DEPLOY COMPLETE ==================" -ForegroundColor Green
Write-Host "Resource Group:     $rgName"
Write-Host "Storage Account:    $saName"
Write-Host "Container:          $containerName"
Write-Host "Key Vault:          $kvName"
Write-Host "Service Principal:  $spName ($spAppId)"
Write-Host "Cert (PEM):         $certDest"
Write-Host "Workstation config: $configPath"
Write-Host "Portal:             $portalUrl"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Run ./deploy/verify.ps1 -ResourceGroup $rgName"
Write-Host "  2. For each lab workstation, run workstation/bootstrap.ps1 with the config above and the cert."
Write-Host "  3. Move $certDest off this deploy host into a secure distribution channel."
Write-Host "===================================================" -ForegroundColor Green
