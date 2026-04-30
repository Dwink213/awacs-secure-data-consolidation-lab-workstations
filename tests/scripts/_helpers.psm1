# Shared helpers for executable test scripts.
# Each test script imports this module and uses Test-Assert for consistency.

function Get-AwacsStorageAccount {
  param([Parameter(Mandatory)][string]$ResourceGroup)
  $sas = az storage account list --resource-group $ResourceGroup --output json | ConvertFrom-Json
  if ($null -eq $sas -or $sas.Count -eq 0) { throw "No storage account found in $ResourceGroup" }
  return $sas[0]
}

function Get-AwacsKeyVault {
  param([Parameter(Mandatory)][string]$ResourceGroup)
  $kvs = az keyvault list --resource-group $ResourceGroup --output json | ConvertFrom-Json
  if ($null -eq $kvs -or $kvs.Count -eq 0) { throw "No Key Vault found in $ResourceGroup" }
  return $kvs[0]
}

function Get-AwacsLogAnalyticsWorkspace {
  param([Parameter(Mandatory)][string]$ResourceGroup)
  $las = az monitor log-analytics workspace list --resource-group $ResourceGroup --output json | ConvertFrom-Json
  if ($null -eq $las -or $las.Count -eq 0) { throw "No Log Analytics workspace found in $ResourceGroup" }
  return $las[0]
}

function Test-Assert {
  param(
    [Parameter(Mandatory)][string]$Description,
    [Parameter(Mandatory)][bool]$Condition,
    [string]$ActualDetail = ''
  )
  if ($Condition) {
    Write-Host "  [PASS] $Description" -ForegroundColor Green
    return $true
  } else {
    Write-Host "  [FAIL] $Description" -ForegroundColor Red
    if ($ActualDetail) { Write-Host "         actual: $ActualDetail" -ForegroundColor DarkRed }
    return $false
  }
}

Export-ModuleMember -Function Get-AwacsStorageAccount, Get-AwacsKeyVault, Get-AwacsLogAnalyticsWorkspace, Test-Assert
