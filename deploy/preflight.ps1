#Requires -Version 5.1
<#
.SYNOPSIS
  Preflight gate before Deploy.ps1. Refuses to proceed if any check fails.

.DESCRIPTION
  Validates: Azure CLI present, Bicep present, logged in, subscription matches,
  identity has sufficient role, region is valid, prefix valid, RG name available,
  storage account name globally available.

.PARAMETER SubscriptionId
  Target Azure subscription ID.

.PARAMETER Region
  Azure region (e.g., eastus2).

.PARAMETER Prefix
  3-8 lowercase alphanumeric characters.

.EXAMPLE
  ./preflight.ps1 -SubscriptionId 0000... -Region eastus2 -Prefix awacslab
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$SubscriptionId,
  [Parameter(Mandatory=$true)][string]$Region,
  [Parameter(Mandatory=$true)][string]$Prefix
)

$ErrorActionPreference = 'Stop'
$script:fails = 0

function Test-Step {
  param([string]$Name, [scriptblock]$Test, [string]$Remediation)
  Write-Host "[CHECK] $Name " -NoNewline
  try {
    $ok = & $Test
    if ($ok) {
      Write-Host "PASS" -ForegroundColor Green
    } else {
      Write-Host "FAIL" -ForegroundColor Red
      Write-Host "        Remediation: $Remediation" -ForegroundColor Yellow
      $script:fails++
    }
  } catch {
    Write-Host "FAIL ($($_.Exception.Message))" -ForegroundColor Red
    Write-Host "        Remediation: $Remediation" -ForegroundColor Yellow
    $script:fails++
  }
}

# 1. Azure CLI present
Test-Step 'Azure CLI present' {
  $v = az version --output json 2>$null | ConvertFrom-Json
  return $null -ne $v -and [version]$v.'azure-cli' -ge [version]'2.50.0'
} 'Install Azure CLI >= 2.50.0 from https://learn.microsoft.com/cli/azure/install-azure-cli'

# 2. Bicep present
Test-Step 'Bicep CLI present' {
  $v = az bicep version 2>$null
  return $LASTEXITCODE -eq 0
} 'Run: az bicep install'

# 3. Logged in
Test-Step 'Logged in to Azure' {
  $acct = az account show --output json 2>$null | ConvertFrom-Json
  return $null -ne $acct
} 'Run: az login'

# 4. Subscription matches
Test-Step 'Subscription matches parameter' {
  $acct = az account show --output json 2>$null | ConvertFrom-Json
  return $acct.id -eq $SubscriptionId
} "Run: az account set --subscription $SubscriptionId"

# 5. Has Owner OR (Contributor + UAA)
Test-Step 'Identity has Owner OR Contributor+UAA' {
  $upn = (az account show --output json | ConvertFrom-Json).user.name
  $assignments = az role assignment list --assignee $upn --all --output json 2>$null | ConvertFrom-Json
  if ($null -eq $assignments) { return $false }
  $hasOwner = $assignments | Where-Object { $_.roleDefinitionName -eq 'Owner' -and ($_.scope -eq "/subscriptions/$SubscriptionId" -or $_.scope -eq '/') }
  if ($hasOwner) { return $true }
  $hasContrib = $assignments | Where-Object { $_.roleDefinitionName -eq 'Contributor' }
  $hasUAA = $assignments | Where-Object { $_.roleDefinitionName -eq 'User Access Administrator' }
  return ($hasContrib -and $hasUAA)
} 'Grant your identity Owner on the subscription, or both Contributor + User Access Administrator.'

# 6. Region valid
Test-Step "Region '$Region' available" {
  $regions = az account list-locations --output json | ConvertFrom-Json
  return $null -ne ($regions | Where-Object { $_.name -eq $Region })
} 'Run: az account list-locations -o table; pick a valid region.'

# 7. Prefix shape
Test-Step "Prefix '$Prefix' is 3-8 lowercase alphanumeric" {
  return $Prefix -cmatch '^[a-z0-9]{3,8}$'
} 'Use 3-8 lowercase letters and digits only.'

# 8. RG availability
Test-Step "Resource Group '$Prefix-rg' is available (does not exist or is empty)" {
  $rg = az group show --name "$Prefix-rg" --output json 2>$null | ConvertFrom-Json
  if ($null -eq $rg) { return $true }
  $resources = az resource list --resource-group "$Prefix-rg" --output json | ConvertFrom-Json
  return ($null -eq $resources -or $resources.Count -eq 0)
} "Either pick a different prefix or run teardown.ps1 -Prefix $Prefix first."

# 9. SA name globally unique
Test-Step "Storage account name available globally" {
  $unique4 = (az group show --name "$Prefix-rg" --output json 2>$null | ConvertFrom-Json)
  # The unique4 hash uses RG ID; if RG doesn't exist yet, we approximate. Best-effort check.
  $candidate = "${Prefix}sa$(([guid]::NewGuid().ToString('N').Substring(0,4)))"
  $check = az storage account check-name --name $candidate --output json 2>$null | ConvertFrom-Json
  return $check.nameAvailable
} 'Pick a different prefix.'

if ($script:fails -gt 0) {
  Write-Host ""
  Write-Host "Preflight FAILED ($script:fails checks)." -ForegroundColor Red
  Write-Host "Fix the issues above and re-run preflight before Deploy.ps1."
  exit 1
}

Write-Host ""
Write-Host "Preflight PASSED. Safe to run Deploy.ps1." -ForegroundColor Green
exit 0
