// Component 06: Consumer RBAC — Read-only access for the lab analyst group.

@description('Object ID of the Entra ID security group')
param consumerGroupObjectId string

@description('Storage account name (from component 01)')
param storageAccountName string

@description('Container name (from component 01)')
param containerName string

// 2a2b9908-6ea1-4ae2-8e65-a410df84e7d1 == "Storage Blob Data Reader"
// (ba92f5b4 is Contributor -- wrong role, caught by C6.1 test)
var blobReaderRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')

// existing reference so role assignment scope resolves to the correct subscription-scoped ID
resource containerRef 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' existing = {
  name: '${storageAccountName}/default/${containerName}'
}

resource readerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(consumerGroupObjectId, blobReaderRoleId, storageAccountName, containerName)
  scope: containerRef
  properties: {
    roleDefinitionId: blobReaderRoleId
    principalId: consumerGroupObjectId
    principalType: 'Group'
  }
}

output roleAssignmentId string = readerAssignment.id
