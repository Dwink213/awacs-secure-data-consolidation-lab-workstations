// Component 08: SAS Rotator — Azure Automation Account with system-assigned MSI.
// Schedule: every 6 days (1-day buffer before 7-day Azure user-delegation SAS cap).
//
// NOTE: Originally designed as an Azure Function (Consumption plan). Pivoted to Azure
// Automation because personal/PAYG subscriptions frequently have Dynamic VM quota = 0,
// which blocks Consumption plan creation. Automation Account is free tier, no Dynamic
// VM quota required, same MSI model. See ADR-008 for full rationale.
//
// MSI is granted three tightly-scoped roles:
//   - Storage Blob Delegator on SA     → call GetUserDelegationKey
//   - Storage Blob Data Contributor on container → embed acw perms in the delegated SAS
//   - Key Vault Secrets Officer on the specific secret → write new secret versions only

targetScope = 'resourceGroup'

@description('Lowercase alphanumeric prefix, 3-8 chars — must match the rest of the deployment')
param prefix string

@description('Azure region')
param location string = resourceGroup().location

@description('Name of the data storage account (awdustsaybmh)')
param storageAccountName string

@description('Name of the blob container to generate SAS for')
param containerName string

@description('Name of the Key Vault')
param keyVaultName string

@description('Full resource ID of the current-write-sas secret in Key Vault')
param secretResourceId string

@description('Log Analytics workspace resource ID for diagnostic settings')
param logAnalyticsWorkspaceId string

// Role definition IDs (built-in, subscription-scoped)
var blobDelegatorRoleId    = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'db58b8e5-c6ad-4a2a-8342-4190687cbf4a') // Storage Blob Delegator
var blobContributorRoleId  = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
var kvSecretsOfficerRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7') // Key Vault Secrets Officer

var uniqueSuffix  = take(uniqueString(resourceGroup().id), 4)
var autoAcctName  = '${prefix}-auto-${uniqueSuffix}'  // e.g. awdust-auto-ybmh

// Azure Automation Account — Free SKU, system-assigned MSI
resource autoAcct 'Microsoft.Automation/automationAccounts@2023-11-01' = {
  name: autoAcctName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Free'
    }
  }
}

// Diagnostic settings — Automation job logs → Log Analytics
resource autoDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'send-to-la'
  scope: autoAcct
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { category: 'JobLogs',    enabled: true }
      { category: 'JobStreams', enabled: true }
    ]
  }
}

// Existing references for RBAC scoping
resource dataStorageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource containerRef 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' existing = {
  name: '${storageAccountName}/default/${containerName}'
}

var kvSecretName = split(secretResourceId, '/')[10]
resource secretRef 'Microsoft.KeyVault/vaults/secrets@2023-07-01' existing = {
  name: '${keyVaultName}/${kvSecretName}'
}

// RBAC 1: Storage Blob Delegator on the data storage account
resource blobDelegatorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(autoAcct.id, blobDelegatorRoleId, dataStorageAccount.id)
  scope: dataStorageAccount
  properties: {
    roleDefinitionId: blobDelegatorRoleId
    principalId: autoAcct.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// RBAC 2: Storage Blob Data Contributor on the container
resource blobContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(autoAcct.id, blobContributorRoleId, containerRef.id)
  scope: containerRef
  properties: {
    roleDefinitionId: blobContributorRoleId
    principalId: autoAcct.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// RBAC 3: Key Vault Secrets Officer scoped to the single secret
resource kvOfficerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(autoAcct.id, kvSecretsOfficerRoleId, secretResourceId)
  scope: secretRef
  properties: {
    roleDefinitionId: kvSecretsOfficerRoleId
    principalId: autoAcct.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Automation Variables — runbook reads these at runtime via Get-AutomationVariable.
// String values must be JSON-encoded (extra double-quote layer) per Automation API contract.
resource varStorageAccount 'Microsoft.Automation/automationAccounts/variables@2023-11-01' = {
  parent: autoAcct
  name: 'StorageAccountName'
  properties: {
    value: '"${storageAccountName}"'
    isEncrypted: false
    description: 'Name of the data storage account'
  }
}

resource varContainer 'Microsoft.Automation/automationAccounts/variables@2023-11-01' = {
  parent: autoAcct
  name: 'ContainerName'
  properties: {
    value: '"${containerName}"'
    isEncrypted: false
    description: 'Blob container to generate SAS for'
  }
}

resource varKeyVault 'Microsoft.Automation/automationAccounts/variables@2023-11-01' = {
  parent: autoAcct
  name: 'KeyVaultName'
  properties: {
    value: '"${keyVaultName}"'
    isEncrypted: false
    description: 'Key Vault that holds the current-write-sas secret'
  }
}

resource varSecretName 'Microsoft.Automation/automationAccounts/variables@2023-11-01' = {
  parent: autoAcct
  name: 'SecretName'
  properties: {
    value: '"${kvSecretName}"'
    isEncrypted: false
    description: 'Name of the KV secret being rotated'
  }
}

output autoAcctName     string = autoAcct.name
output autoAcctId       string = autoAcct.id
output autoMsiPrincipal string = autoAcct.identity.principalId
