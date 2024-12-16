param name string
param location string = resourceGroup().location
param tags object = {}
param autoScaleEnabled bool = false
param privateEndpointSubnetId string = ''
param privateEndpointLocation string = location
param linkPrivateEndpointToPrivateDns bool = true
param privateDnsZoneResourceGroup string

param customSubDomainName string = name
param deployments array = []

param keyVaultName string

@allowed([
  'Academic'
  'AnomalyDetector'
  'BingAutosuggest'
  'Bing.Autosuggest.v7'
  'Bing.CustomSearch'
  'Bing.Search'
  'Bing.Search.v7'
  'Bing.Speech'
  'Bing.SpellCheck'
  'Bing.SpellCheck.v7'
  'CognitiveServices'
  'ComputerVision'
  'ContentModerator'
  'ContentSafety'
  'CustomSpeech'
  'CustomVision.Prediction'
  'CustomVision.Training'
  'Emotion'
  'Face'
  'FormRecognizer'
  'ImmersiveReader'
  'LUIS'
  'LUIS.Authoring'
  'MetricsAdvisor'
  'OpenAI'
  'Personalizer'
  'QnAMaker'
  'Recommendations'
  'SpeakerRecognition'
  'Speech'
  'SpeechServices'
  'SpeechTranslation'
  'TextAnalytics'
  'TextTranslation'
  'WebLM'
])
param kind string = 'OpenAI'

@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Disabled'
param sku object = {
  name: 'S0'
}

resource account 'Microsoft.CognitiveServices/accounts@2024-04-01-preview' = {
  name: name
  location: location
  tags: tags
  kind: kind
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: customSubDomainName
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Deny'
    }
    restrictOutboundNetworkAccess: false
    dynamicThrottlingEnabled: kind == 'OpenAI' ? false : autoScaleEnabled
  }
  sku: sku
}

@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = [
  for deployment in deployments: {
    parent: account
    name: deployment.name
    properties: {
      model: deployment.model
      raiPolicyName: deployment.?raiPolicyName ?? null
    }
    sku: {
      name: deployment.?skuName ?? 'Standard'
      capacity: deployment.capacity
    }
  }
]

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = if (!empty(privateEndpointSubnetId)) {
  name: '${account.name}-endpoint'
  location: privateEndpointLocation
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
      properties: {}
    }
    privateLinkServiceConnections: [
      {
        name: '${account.name}-connection'
        properties: {
          privateLinkServiceId: account.id
          groupIds: [
            'account'
          ]
        }
      }
    ]
  }

  resource link 'privateDnsZoneGroups' = if (linkPrivateEndpointToPrivateDns) {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'config'
          properties: {
            privateDnsZoneId: privateDnsZone.id
          }
        }
      ]
    }
  }

  dependsOn: [
    deployment
  ]
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if (linkPrivateEndpointToPrivateDns) {
  scope: resourceGroup(privateDnsZoneResourceGroup)
  name: kind == 'OpenAI' ? 'privatelink.openai.azure.com' : 'privatelink.cognitiveservices.azure.com'
}

module accountKey '../security/vault-secret.bicep' = {
  name: 'accountKeySecret-${account.name}'
  params: {
    keyVaultName: keyVaultName
    keyVaultSecretName: '${account.name}-key'
    keyVaultSecretValue: account.listKeys().key1
  }
}

output endpoint string = account.properties.endpoint
output id string = account.id
output name string = account.name
output skuName string = account.sku.name
output adminKeySecretUri string = accountKey.outputs.secretUri
output identityPrincipalId string = account.identity.principalId
output resourceGroup string = resourceGroup().name
