param eventHubNamespaceName string
param eventHubName string
param skuName string = 'Standard'
param skuCapacity int = 1
param location string = resourceGroup().location
param privateEndpointSubnetId string
param linkPrivateEndpointToPrivateDns bool = true
param privateDnsZoneResourceGroup string
param tags object = {}

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2024-01-01' = {
  name: eventHubNamespaceName
  location: location
  tags: tags
  sku: {
    name: skuName
    capacity: skuCapacity    
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = {
  parent: eventHubNamespace
  name: eventHubName  
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: '${eventHubNamespace.name}-endpoint'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${eventHubNamespace.name}-connection'
        properties: {
          privateLinkServiceId: eventHubNamespace.id
          groupIds: [
            'namespace'
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
  name: 'privatelink.servicebus.windows.net'
}

output namespaceId string = eventHubNamespace.id
output namespaceName string = eventHubNamespaceName
output eventHubId string = eventHub.id
output eventHubName string = eventHubName
