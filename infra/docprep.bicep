targetScope = 'subscription'

param resourceGroupName string
param location string
param tags object = {}
param principalId string = ''
param resourceToken string

param formRecognizerServiceName string = ''
param formRecognizerResourceGroupName string = ''
param formRecognizerResourceGroupLocation string = location
param formRecognizerSkuName string = 'S0'
param formRecognizerPrivateEndpointSubnetId string

param autoScaleEnabled bool = false

param assignRbacRoles bool = false

param linkPrivateEndpointToPrivateDns bool = true
param privateDnsZoneResourceGroup string

param keyVaultName string

var abbrs = loadJsonContent('abbreviations.json')
var azureRoles = loadJsonContent('azure_roles.json')

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: resourceGroupName
}

resource formRecognizerResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' existing = if (!empty(formRecognizerResourceGroupName)) {
  name: !empty(formRecognizerResourceGroupName) ? formRecognizerResourceGroupName : resourceGroup.name
}

module formRecognizer 'core/ai/cognitiveservices.bicep' = {
  name: 'formrecognizer'
  scope: formRecognizerResourceGroup
  params: {
    name: !empty(formRecognizerServiceName)
      ? formRecognizerServiceName
      : '${abbrs.cognitiveServicesFormRecognizer}${resourceToken}'
    kind: 'FormRecognizer'
    autoScaleEnabled: autoScaleEnabled
    location: formRecognizerResourceGroupLocation
    tags: tags
    sku: {
      name: formRecognizerSkuName
    }
    privateEndpointSubnetId: formRecognizerPrivateEndpointSubnetId
    publicNetworkAccess: 'Disabled'
    keyVaultName: keyVaultName
    linkPrivateEndpointToPrivateDns: linkPrivateEndpointToPrivateDns
    privateDnsZoneResourceGroup: privateDnsZoneResourceGroup
  }
}

module formRecognizerRoleUser 'core/security/role.bicep' = if (assignRbacRoles && !empty(principalId)) {
  scope: formRecognizerResourceGroup
  name: 'formrecognizer-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: azureRoles.CognitiveServicesUser
    principalType: 'User'
  }
}

// Used by prepdocs
// Form recognizer
output azureFormrecognizerService string = formRecognizer.outputs.name
output azureFormrecognizerResourceGroup string = formRecognizerResourceGroup.name
output azureFormrecognizerSkuName string = formRecognizerSkuName
