// Component 02: Key Vault
// Single responsibility: hold the rotated SAS secret; SP gates by RBAC.

@description('Lowercase alphanumeric prefix')
@minLength(3)
@maxLength(8)
param prefix string

@description('Azure region')
param location string

@description('Resource ID of the Log Analytics workspace')
param logAnalyticsWorkspaceId string

@description('Tenant ID for the Key Vault')
param tenantId string = subscription().tenantId

@description('Name of the secret holding the rotated write-only SAS')
param secretName string = 'current-write-sas'

var unique4 = substring(uniqueString(resourceGroup().id), 0, 4)
var keyVaultName = '${prefix}-kv-${unique4}'

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableSoftDelete: true
    enablePurgeProtection: true
    enableRbacAuthorization: true
    softDeleteRetentionInDays: 90
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
  tags: {
    component: '02-key-vault'
    project: 'awacs-secure-data-consolidation'
  }
}

// Placeholder secret. Replaced post-deploy by the SAS rotator with a real 24h SAS.
resource initialSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: kv
  name: secretName
  properties: {
    value: 'PLACEHOLDER-deploy-script-overwrites-this'
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

resource diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: kv
  name: 'send-to-la'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { category: 'AuditEvent', enabled: true }
      { category: 'AzurePolicyEvaluationDetails', enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true }
    ]
  }
}

output keyVaultName string = kv.name
output keyVaultUri string = kv.properties.vaultUri
output keyVaultId string = kv.id
output secretName string = initialSecret.name
output secretResourceId string = initialSecret.id
