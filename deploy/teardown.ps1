#Requires -Version 5.1
<#
.SYNOPSIS
  Removes everything Deploy.ps1 created.

.DESCRIPTION
  Refuses to proceed if immutability retention has not expired, unless
  -ForceTearDownExpiredPolicy is passed. KV and SA are soft-deleted, not
  purged, by default.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$Prefix,
  [Parameter(Mandatory=$true)][string]$SubscriptionId,
  [switch]$ForceTearDownExpiredPolicy,
  [switch]$PurgeSoftDeleted
)

$ErrorActionPreference = 'Stop'
$rgName = "$Prefix-rg"
az account set --subscription $SubscriptionId | Out-Null

# 1. Check immutability state on the container
$rg = az group show --name $rgName --output json 2>$null | ConvertFrom-Json
if ($null -eq $rg) { Write-Host "Resource group $rgName not found. Nothing to teardown."; exit 0 }

$saList = az storage account list --resource-group $rgName --output json | ConvertFrom-Json
foreach ($sa in $saList) {
  $containers = az storage container list --account-name $sa.name --auth-mode login --output json 2>$null | ConvertFrom-Json
  foreach ($c in $containers) {
    $policy = az storage container immutability-policy show --account-name $sa.name --container-name $c.name --output json 2>$null | ConvertFrom-Json
    if ($null -ne $policy -and $policy.state -eq 'Locked' -and -not $ForceTearDownExpiredPolicy) {
      Write-Host "Cannot teardown: container '$($c.name)' on '$($sa.name)' has Locked immutability policy." -ForegroundColor Red
      Write-Host "  retention: $($policy.immutabilityPeriodSinceCreationInDays) days"
      Write-Host "  Pass -ForceTearDownExpiredPolicy to override (still subject to Azure's enforcement)."
      exit 1
    }
  }
}

# 2. Find SP by tag (deploy uses a name pattern)
Write-Host "==> Locating Service Principal..." -ForegroundColor Cyan
$sps = az ad sp list --display-name "$Prefix-lab-sp-" --output json 2>$null | ConvertFrom-Json
foreach ($sp in $sps) {
  Write-Host "    Removing SP: $($sp.displayName) ($($sp.appId))"
  az ad app delete --id $sp.appId | Out-Null
}

# 3. Remove resource lock(s)
Write-Host "==> Removing resource locks..." -ForegroundColor Cyan
$locks = az lock list --resource-group $rgName --output json 2>$null | ConvertFrom-Json
foreach ($l in $locks) {
  az lock delete --name $l.name --resource-group $rgName | Out-Null
}

# 4. Delete RG
Write-Host "==> Deleting resource group $rgName..." -ForegroundColor Cyan
az group delete --name $rgName --yes --no-wait

# 5. Optional purge of soft-deleted vault
if ($PurgeSoftDeleted) {
  Write-Host "==> Purging soft-deleted Key Vaults..." -ForegroundColor Cyan
  $deletedKvs = az keyvault list-deleted --output json | ConvertFrom-Json
  foreach ($k in $deletedKvs) {
    if ($k.name -like "$Prefix-kv-*") {
      Write-Host "    Purging $($k.name)"
      az keyvault purge --name $k.name | Out-Null
    }
  }
}

Write-Host "Teardown complete (RG deletion is async; check 'az group show' to confirm)." -ForegroundColor Green
