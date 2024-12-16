param name string
param location string = resourceGroup().location
param privateEndpointSubnetId string
param linkPrivateEndpointToPrivateDns bool = true
param privateDnsZoneResourceGroup string
param tags object = {}

param ipRules IpRule[] = []

param replicas int = 1

param sku object = {
  name: 'standard'
}

param authOptions object = {}
param semanticSearch string = 'disabled'

param keyVaultName string

type IpRule = {
  value: string
}

resource search 'Microsoft.Search/searchServices@2024-06-01-preview' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    authOptions: authOptions
    disableLocalAuth: false
    disabledDataExfiltrationOptions: []
    encryptionWithCmk: {
      enforcement: 'Unspecified'
    }
    hostingMode: 'default'
    networkRuleSet: {
      bypass: 'AzureServices'
      ipRules: ipRules
    }
    partitionCount: 1
    publicNetworkAccess: 'Disabled'
    replicaCount: replicas
    semanticSearch: semanticSearch
  }
  sku: sku
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: '${search.name}-endpoint'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${search.name}-connection'
        properties: {
          privateLinkServiceId: search.id
          groupIds: [
            'searchService'
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
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if(linkPrivateEndpointToPrivateDns) {
  scope: resourceGroup(privateDnsZoneResourceGroup)
  name: 'privatelink.search.windows.net'
}

module adminKeySecret '../security/vault-secret.bicep' = {
  name: 'accountKeySecret-${search.name}'
  params: {
    keyVaultName: keyVaultName
    keyVaultSecretName: '${search.name}-key'
    keyVaultSecretValue: search.listAdminKeys().primaryKey
  }
}

output id string = search.id
output endpoint string = 'https://${name}.search.windows.net/'
output name string = search.name
output skuName string = sku.name
output adminKeySecretUri string = adminKeySecret.outputs.secretUri
output identityPrincipalId string = search.identity.principalId
