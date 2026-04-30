// Top-level Bicep orchestrator.
// Composes the six cloud-side Atomic Legos (01, 02, 03, 04, 05, 06).
// SP creation is imperative in Deploy.ps1 (see component 03 README + ADR-003).

targetScope = 'resourceGroup'

@description('Lowercase alphanumeric prefix, 3-8 chars')
@minLength(3)
@maxLength(8)
param prefix string

@description('Azure region')
param location string = resourceGroup().location

@description('Object ID of the Service Principal created by Deploy.ps1')
param servicePrincipalObjectId string

@description('Object ID of the Entra ID security group containing data consumers')
param consumerGroupObjectId string

@description('Soft-delete retention for blobs (days)')
param softDeleteRetentionDays int = 14

@description('Immutability retention (days)')
param immutabilityRetentionDays int = 90

@description('Log Analytics retention (days)')
param logRetentionDays int = 90

@description('Email for staleness alerts (optional)')
param alertEmail string = ''

// Component 05 first — everyone diags to it
module la '../components/05-log-analytics/main.bicep' = {
  name: 'deploy-05-la'
  params: {
    prefix: prefix
    location: location
    retentionDays: logRetentionDays
    alertEmail: alertEmail
  }
}

// Component 01 — storage account
module sa '../components/01-storage-account/main.bicep' = {
  name: 'deploy-01-sa'
  params: {
    prefix: prefix
    location: location
    logAnalyticsWorkspaceId: la.outputs.workspaceId
    softDeleteRetentionDays: softDeleteRetentionDays
  }
}

// Component 02 — key vault
module kv '../components/02-key-vault/main.bicep' = {
  name: 'deploy-02-kv'
  params: {
    prefix: prefix
    location: location
    logAnalyticsWorkspaceId: la.outputs.workspaceId
  }
}

// Component 04 — immutability policy on the container
module imm '../components/04-immutability-policy/main.bicep' = {
  name: 'deploy-04-imm'
  params: {
    storageAccountName: sa.outputs.storageAccountName
    containerName: sa.outputs.containerName
    retentionDays: immutabilityRetentionDays
  }
  dependsOn: [
    sa
  ]
}

// Component 03 — RBAC for SP
module sp '../components/03-service-principal-auth/main.bicep' = {
  name: 'deploy-03-sp-rbac'
  params: {
    servicePrincipalObjectId: servicePrincipalObjectId
    storageAccountId: sa.outputs.storageAccountId
    storageAccountName: sa.outputs.storageAccountName
    containerName: sa.outputs.containerName
    secretResourceId: kv.outputs.secretResourceId
  }
}

// Component 06 — consumer reader RBAC
module rbac '../components/06-rbac-consumer-access/main.bicep' = {
  name: 'deploy-06-rbac'
  params: {
    consumerGroupObjectId: consumerGroupObjectId
    storageAccountName: sa.outputs.storageAccountName
    containerName: sa.outputs.containerName
  }
}

// Outputs surface what Deploy.ps1 needs to build the workstation config
output storageAccountName string = sa.outputs.storageAccountName
output containerName string = sa.outputs.containerName
output blobEndpoint string = sa.outputs.blobEndpoint
output keyVaultName string = kv.outputs.keyVaultName
output keyVaultUri string = kv.outputs.keyVaultUri
output secretName string = kv.outputs.secretName
output workspaceId string = la.outputs.workspaceId
output workspaceCustomerId string = la.outputs.workspaceCustomerId
