// Component 03: Custom role + RBAC assignments for the lab-PC SP.
// SP creation itself is imperative in deploy/Deploy.ps1 — see README.md for rationale.

@description('Object ID of the Service Principal (from az ad sp create output)')
param servicePrincipalObjectId string

@description('Resource ID of the storage account (from component 01)')
param storageAccountId string

@description('Name of the container scoped for write')
param containerName string

@description('Resource ID of the key vault secret holding the SAS (from component 02)')
param secretResourceId string

@description('Storage account name (used for scope construction)')
param storageAccountName string

// Custom role: write-only on blobs in the lab-files container.
// We define it at RG scope so teardown removes it with the RG.
resource customRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid('awacs-lab-pc-writer', resourceGroup().id)
  properties: {
    roleName: 'awacs-lab-pc-writer-${uniqueString(resourceGroup().id)}'
    description: 'Write-only on lab-files blobs. No read, no delete, no list.'
    type: 'CustomRole'
    assignableScopes: [
      resourceGroup().id
    ]
    permissions: [
      {
        actions: []
        notActions: []
        dataActions: [
          'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write'
          'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/add/action'
        ]
        notDataActions: []
      }
    ]
  }
}

// Construct the container scope ID
var containerScopeId = '${storageAccountId}/blobServices/default/containers/${containerName}'

// Assign custom role to SP at container scope.
resource writeAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(servicePrincipalObjectId, customRole.id, containerScopeId)
  scope: tenantResourceId('Microsoft.Storage/storageAccounts/blobServices/containers', storageAccountName, 'default', containerName)
  properties: {
    roleDefinitionId: customRole.id
    principalId: servicePrincipalObjectId
    principalType: 'ServicePrincipal'
  }
}

// Assign built-in Key Vault Secrets User to SP at the secret scope.
// 4633458b-17de-408a-b874-0445c86b69e6 == "Key Vault Secrets User"
var kvSecretsUserRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')

resource kvAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(servicePrincipalObjectId, kvSecretsUserRoleId, secretResourceId)
  scope: tenantResourceId('Microsoft.KeyVault/vaults/secrets', split(secretResourceId, '/')[8], split(secretResourceId, '/')[10])
  properties: {
    roleDefinitionId: kvSecretsUserRoleId
    principalId: servicePrincipalObjectId
    principalType: 'ServicePrincipal'
  }
}

output customRoleDefinitionId string = customRole.id
output writeAssignmentId string = writeAssignment.id
output kvAssignmentId string = kvAssignment.id
