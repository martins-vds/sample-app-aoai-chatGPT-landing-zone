param name string
param location string = resourceGroup().location
param tags object = {}

@allowed(['Hot', 'Cool', 'Premium'])
param accessTier string = 'Hot'
param allowBlobPublicAccess bool = false
param allowCrossTenantReplication bool = true
param allowSharedKeyAccess bool = true
param defaultToOAuthAuthentication bool = false
param deleteRetentionPolicy object = {}
@allowed(['AzureDnsZone', 'Standard'])
param dnsEndpointType string = 'Standard'
param kind string = 'StorageV2'
param minimumTlsVersion string = 'TLS1_2'
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Disabled'
param sku object = { name: 'Standard_LRS' }
param privateEndpointSubnetId string
param linkPrivateEndpointToPrivateDns bool = true
param privateDnsZoneResourceGroup string

param containers array = []
param shares array = []
param queues array = []
param virtualNetworkRules array = []

param keyVaultName string = ''

var storageFileDataPrivilegedContributorRoleId = '69566ab7-960f-475b-8e7c-b3118f30c6bd'
var abbrs = loadJsonContent('../../abbreviations.json')

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  sku: sku
  properties: {
    accessTier: accessTier
    allowBlobPublicAccess: allowBlobPublicAccess
    allowCrossTenantReplication: allowCrossTenantReplication
    allowSharedKeyAccess: allowSharedKeyAccess
    defaultToOAuthAuthentication: defaultToOAuthAuthentication
    dnsEndpointType: dnsEndpointType
    minimumTlsVersion: minimumTlsVersion
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: virtualNetworkRules
      defaultAction: 'Deny'
    }
    publicNetworkAccess: empty(virtualNetworkRules) ? publicNetworkAccess : 'Enabled'
  }

  resource blobServices 'blobServices' = if (!empty(containers)) {
    name: 'default'
    properties: {
      deleteRetentionPolicy: deleteRetentionPolicy
    }
    resource container 'containers' = [
      for container in containers: {
        name: container.name
        properties: {
          publicAccess: container.?publicAccess ?? 'None'
        }
      }
    ]
  }

  resource fileServices 'fileServices' = if (!empty(shares)) {
    name: 'default'

    resource share 'shares' = [
      for share in shares: {
        name: share.name
      }
    ]
  }

  resource queueServices 'queueServices' = if (!empty(queues)){
    name: 'default'

    resource queue 'queues' = [
      for queue in queues: {
        name: queue.name
      }
    ]
  }
}

module connectionStringSecret '../security/vault-secret.bicep' = if(!empty(keyVaultName)) {
  name: '${storage.name}-cs-secret'
  params: {
    keyVaultName: keyVaultName
    keyVaultSecretName: '${storage.name}-cs'
    keyVaultSecretValue: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${storage.listkeys().keys[0].value}'
  }
}

resource blobPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: '${storage.name}-endpoint'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${storage.name}-connection'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [
            'blob'
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
            privateDnsZoneId: blobPrivateDnsZone.id
          }
        }
      ]
    }
  }
}

resource blobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if(linkPrivateEndpointToPrivateDns) {
  scope: resourceGroup(privateDnsZoneResourceGroup)
  name: 'privatelink.blob.${environment().suffixes.storage}'
}

resource filePrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: '${storage.name}-file-endpoint'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${storage.name}-file-connection'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [
            'file'
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
            privateDnsZoneId: filePrivateDnsZone.id
          }
        }
      ]
    }
  }
}

resource filePrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if(linkPrivateEndpointToPrivateDns) {
  scope: resourceGroup(privateDnsZoneResourceGroup)
  name: 'privatelink.file.${environment().suffixes.storage}'
}

resource tablePrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: '${storage.name}-table-endpoint'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${storage.name}-table-connection'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [
            'table'
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
            privateDnsZoneId: tablePrivateDnsZone.id
          }
        }
      ]
    }
  }
}

resource tablePrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if(linkPrivateEndpointToPrivateDns) {
  scope: resourceGroup(privateDnsZoneResourceGroup)
  name: 'privatelink.table.${environment().suffixes.storage}'
}

resource queuePrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: '${storage.name}-queue-endpoint'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${storage.name}-queue-connection'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [
            'queue'
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
            privateDnsZoneId: queuePrivateDnsZone.id
          }
        }
      ]
    }
  }
}

resource queuePrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if(linkPrivateEndpointToPrivateDns) {
  scope: resourceGroup(privateDnsZoneResourceGroup)
  name: 'privatelink.queue.${environment().suffixes.storage}'
}

resource deploymentScriptRunnerIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${abbrs.managedIdentityUserAssignedIdentities}${name}-scriptrunner'
  location: location
}

resource storageFileDataPrivilegedContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storage
  name: guid(
    subscription().id,
    resourceGroup().id,
    deploymentScriptRunnerIdentity.id,
    storageFileDataPrivilegedContributorRoleId
  )
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      storageFileDataPrivilegedContributorRoleId
    )
    principalType: 'ServicePrincipal'
    principalId: deploymentScriptRunnerIdentity.properties.principalId
  }
}

output name string = storage.name
output primaryEndpoints object = storage.properties.primaryEndpoints
output connectionStringSecretUri string = empty(keyVaultName) ? '' : connectionStringSecret.outputs.secretUri
output scriptRunnerIdentityId string = deploymentScriptRunnerIdentity.id
output scriptRunnerPrincipalId string = deploymentScriptRunnerIdentity.properties.principalId
output scriptRunnerClientId string = deploymentScriptRunnerIdentity.properties.clientId
