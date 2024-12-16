@description('Specifies the name of the key vault.')
param keyVaultName string = 'kv${uniqueString(resourceGroup().id)}'

@description('Specifies the SKU to use for the key vault.')
param keyVaultSku object = {
  name: 'standard'
  family: 'A'
}

@description('Specifies the Azure location where the resources should be created.')
param location string = resourceGroup().location

param privateEndpointSubnetId string
param linkPrivateEndpointToPrivateDns bool = true
param privateDnsZoneResourceGroup string

param accessPolicies keyVaultAccessPolicy[] = []

param tags object = {}

type keyVaultAccessPolicy = {
  objectId: string
  permissions: {
    keys: string[]
    secrets: string[]
    certificates: string[]
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    enableRbacAuthorization: true
    tenantId: tenant().tenantId
    sku: keyVaultSku
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    accessPolicies: [
      for policy in accessPolicies: {
        tenantId: tenant().tenantId
        objectId: policy.objectId
        permissions: policy.permissions
      }
    ]
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: '${keyVaultName}-endpoint'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${keyVaultName}-connection'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
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
  name: 'privatelink.vaultcore.azure.net'
}

output keyVaultName string = keyVault.name
