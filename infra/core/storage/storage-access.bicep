param storageAccountName string
param principalId string
param roleId string

var roleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource storageBlobReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount // Use when specifying a scope that is different than the deployment scope
  name: guid(subscription().id, resourceGroup().id, principalId, roleDefinitionId)
  properties: {
    roleDefinitionId: roleDefinitionId
    principalType: 'ServicePrincipal'
    principalId: principalId
  }
}
