metadata description = 'Assigns ACR Pull permissions to access an Azure Container Registry.'
param containerRegistryName string
param principalId string

var acrPullRole = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '7f951dda-4ed3-4680-a7ca-43fe172d538d'
)

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = if (!empty(containerRegistryName)) {
  name: containerRegistryName
}

resource aksAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(containerRegistryName)) {
  scope: containerRegistry // Use when specifying a scope that is different than the deployment scope
  name: guid(subscription().id, resourceGroup().id, principalId, acrPullRole)
  properties: {
    roleDefinitionId: acrPullRole
    principalType: 'ServicePrincipal'
    principalId: principalId
  }
}
