// Component 06: Consumer RBAC — Read-only access for the lab analyst group.

@description('Object ID of the Entra ID security group')
param consumerGroupObjectId string

@description('Storage account name (from component 01)')
param storageAccountName string

@description('Container name (from component 01)')
param containerName string

// ba92f5b4-2d11-453d-a403-e96b0029c9fe == "Storage Blob Data Reader"
var blobReaderRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')

resource readerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(consumerGroupObjectId, blobReaderRoleId, storageAccountName, containerName)
  scope: tenantResourceId('Microsoft.Storage/storageAccounts/blobServices/containers', storageAccountName, 'default', containerName)
  properties: {
    roleDefinitionId: blobReaderRoleId
    principalId: consumerGroupObjectId
    principalType: 'Group'
  }
}

output roleAssignmentId string = readerAssignment.id
