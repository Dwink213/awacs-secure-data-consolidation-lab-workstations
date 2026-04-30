// Component 04: Immutability policy on the lab-files container.

@description('Name of the storage account (from component 01)')
param storageAccountName string

@description('Name of the container (from component 01)')
param containerName string

@description('Retention period in days')
@minValue(1)
@maxValue(146000) // ~400 years; arbitrary upper bound
param retentionDays int = 90

@description('Allow append-blob writes during retention')
param allowProtectedAppendWrites bool = false

resource immutabilityPolicy 'Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies@2023-05-01' = {
  name: '${storageAccountName}/default/${containerName}/default'
  properties: {
    immutabilityPeriodSinceCreationInDays: retentionDays
    allowProtectedAppendWrites: allowProtectedAppendWrites
  }
}

output policyResourceId string = immutabilityPolicy.id
output retentionDays int = retentionDays
