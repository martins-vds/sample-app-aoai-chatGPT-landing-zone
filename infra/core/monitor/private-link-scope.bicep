param applicationInsightsId string
param privateLinkScopeName string
param location string
param privateEndpointSubnetId string
param linkPrivateEndpointToPrivateDns bool = true
param privateDnsZoneResourceGroup string
param tags object = {}

resource privateLinkScope 'microsoft.insights/privateLinkScopes@2021-07-01-preview' = {
  name: privateLinkScopeName
  location: 'global'
  tags: tags
  properties: {
    accessModeSettings: {
      ingestionAccessMode: 'PrivateOnly' 
      queryAccessMode: 'PrivateOnly'
    }    
  }  

  resource resources 'scopedResources' = {
    name: 'ai'
    properties: {
      linkedResourceId: applicationInsightsId
    }
  }
}

resource queuePrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: '${privateLinkScopeName}-endpoint'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${privateLinkScopeName}-connection'
        properties: {
          privateLinkServiceId: privateLinkScope.id
          groupIds: [
            'azuremonitor'
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
          name: 'privatelink-monitor-azure-com'
          properties: {
            privateDnsZoneId: monitorPrivateDnsZone.id
          }
        }
        {
          name: 'privatelink-oms-opinsights-azure-com'
          properties: {
            privateDnsZoneId: omsPrivateDnsZone.id
          }
        }
        {
          name: 'privatelink-ods-opinsights-azure-com'
          properties: {
            privateDnsZoneId: odsPrivateDnsZone.id
          }
        }
        {
          name: 'privatelink-agentsvc-azure-automation-net'
          properties: {
            privateDnsZoneId: agentsvcPrivateDnsZone.id
          }
        }
        {
          name: 'privatelink-blob-core-windows-net'
          properties: {
            privateDnsZoneId: blobPrivateDnsZone.id
          }
        }
      ]
    }
  }
}

resource monitorPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if(linkPrivateEndpointToPrivateDns) {
  scope: resourceGroup(privateDnsZoneResourceGroup)
  name: 'privatelink.monitor.azure.com'
}

resource omsPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if(linkPrivateEndpointToPrivateDns) {
  scope: resourceGroup(privateDnsZoneResourceGroup)
  name: 'privatelink.oms.opinsights.azure.com'
}

resource odsPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if(linkPrivateEndpointToPrivateDns) {
  scope: resourceGroup(privateDnsZoneResourceGroup)
  name: 'privatelink.ods.opinsights.azure.com'
}

resource agentsvcPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if(linkPrivateEndpointToPrivateDns) {
  scope: resourceGroup(privateDnsZoneResourceGroup)
  name: 'privatelink.agentsvc.azure-automation.net'
}

resource blobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if(linkPrivateEndpointToPrivateDns) {
  scope: resourceGroup(privateDnsZoneResourceGroup)
  name: 'privatelink.blob.${environment().suffixes.storage}'
}
