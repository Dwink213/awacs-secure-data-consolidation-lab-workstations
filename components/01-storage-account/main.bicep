// Component 01: Storage Account
// Single responsibility: durable, immutable, write-only-from-lab destination.
// See ./README.md for contract. See /threat-model.md §3 for defenses cited below.

@description('Lowercase alphanumeric prefix, 3-8 chars')
@minLength(3)
@maxLength(8)
param prefix string

@description('Azure region')
param location string

@description('Resource ID of the Log Analytics workspace (from component 05)')
param logAnalyticsWorkspaceId string

@description('Soft-delete retention in days for blobs and containers')
@minValue(7)
@maxValue(365)
param softDeleteRetentionDays int = 14

@description('Container name where lab files land')
param containerName string = 'lab-files'

// Deterministic 4-char suffix to make the SA name globally unique
var unique4 = substring(uniqueString(resourceGroup().id), 0, 4)
var storageAccountName = toLower('${prefix}sa${unique4}')

resource sa 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_GRS' // geo-redundant; can be downgraded to LRS for cost-sensitive deploys
  }
  properties: {
    // Defenses for T2 (lifted-cred), T5 (network MITM); CIS 3.1, 3.7
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false // CIS-Custom hardening: account key disabled
    allowCrossTenantReplication: false
    publicNetworkAccess: 'Enabled' // lab PCs are on the open Internet; private endpoint is a future hardening
    networkAcls: {
      defaultAction: 'Allow' // Set to 'Deny' + IP allowlist for Operator-hardened deploys
      bypass: 'AzureServices'
    }
  }
  tags: {
    component: '01-storage-account'
    project: 'awacs-secure-data-consolidation'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: sa
  name: 'default'
  properties: {
    // CIS 3.14
    deleteRetentionPolicy: {
      enabled: true
      days: softDeleteRetentionDays
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: softDeleteRetentionDays
    }
    isVersioningEnabled: true
    changeFeed: {
      enabled: true
    }
  }
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: containerName
  properties: {
    publicAccess: 'None'
  }
}

resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: blobService
  name: 'send-to-la'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    // CIS 3.13
    logs: [
      { category: 'StorageRead', enabled: true }
      { category: 'StorageWrite', enabled: true }
      { category: 'StorageDelete', enabled: true }
    ]
    metrics: [
      { category: 'Transaction', enabled: true }
    ]
  }
}

resource lock 'Microsoft.Authorization/locks@2020-05-01' = {
  scope: sa
  name: 'awacs-no-delete'
  properties: {
    level: 'CanNotDelete'
    notes: 'Component 01 lock; teardown script removes this with explicit confirmation.'
  }
}

output storageAccountName string = sa.name
output storageAccountId string = sa.id
output containerName string = container.name
output blobEndpoint string = sa.properties.primaryEndpoints.blob
