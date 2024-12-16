@description('The location into which the API Management resources should be deployed.')
param location string

@description('The name of the API Management service instance to create. This must be globally unique.')
param serviceName string

@description('The name of the API publisher. This information is used by API Management.')
param publisherName string

@description('The email address of the API publisher. This information is used by API Management.')
param publisherEmail string

@description('The name of Application Insights')
param aiName string

@description('The name of the SKU to use when creating the API Management service instance. This must be a SKU that supports virtual network integration.')
param skuName string

@description('The number of worker instances of your API Management service that should be provisioned.')
param skuCount int

param tags object = {}

param publicIPName string

param domainNameLabel string

@allowed([
  'External'
  'Internal'
  'None'
])
param virtualNetworkType string

param subnetResourceId string

param enableLoggers bool = false

param zoneRedundant bool = false

param linkPrivateEndpointToPrivateDns bool = true
param privateDnsZoneResourceGroup string

resource parentAi 'Microsoft.Insights/components@2020-02-02' existing = {
  name: aiName
}

resource applicationGatewayPublicIpAddress 'Microsoft.Network/publicIPAddresses@2024-01-01' = if (virtualNetworkType == 'External') {
  name: publicIPName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: zoneRedundant
    ? [
        '1'
        '2'
        '3'
      ]
    : []
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: domainNameLabel
    }
  }
}

resource apiManagementService 'Microsoft.ApiManagement/service@2023-09-01-preview' = {
  name: serviceName
  location: location
  tags: tags
  sku: {
    name: skuName
    capacity: skuCount
  }
  zones: zoneRedundant
    ? [
        '1'
        '2'
        '3'
      ]
    : []
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherName: publisherName
    publisherEmail: publisherEmail
    publicIpAddressId: virtualNetworkType == 'External' ? applicationGatewayPublicIpAddress.id : null
    virtualNetworkConfiguration: virtualNetworkType == 'None'
      ? null
      : {
          subnetResourceId: subnetResourceId
        }
    virtualNetworkType: virtualNetworkType
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = if (virtualNetworkType == 'None') {
  name: '${apiManagementService.name}-endpoint'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: '${apiManagementService.name}-connection'
        properties: {
          privateLinkServiceId: apiManagementService.id
          groupIds: [
            'Gateway'
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
  name: 'privatelink.azure-api.net'
}

resource aiLoggerInstrumentationKeyNamedValue 'Microsoft.ApiManagement/service/namedValues@2023-09-01-preview' = {
  parent: apiManagementService
  name: 'aiLoggerInstrumentationKey'
  properties: {
    value: parentAi.properties.InstrumentationKey
    secret: true    
    displayName: 'ai-logger-credentials'
  }
}

resource aiLoggerWithInstrumenationKey 'Microsoft.ApiManagement/service/loggers@2023-09-01-preview' = if (enableLoggers) {
  name: 'aiLogger'
  parent: apiManagementService
  properties: {
    loggerType: 'applicationInsights'
    description: 'Application Insights logger with connection string'
    resourceId: parentAi.id
    isBuffered: true
    credentials: {
      instrumentationKey: '{{${aiLoggerInstrumentationKeyNamedValue.properties.displayName}}}'
    }
  }
}

output apiManagementResourceId string = apiManagementService.id
output apiManagementServiceName string = apiManagementService.name
output apiManagementPublicIPAddress string = apiManagementService.properties.publicIPAddresses[0]
output apiManagementIdentityPrincipalId string = apiManagementService.identity.principalId
output apiManagementProxyHostName string = apiManagementService.properties.hostnameConfigurations[0].hostName
output apiManagementGatewayUrl string = apiManagementService.properties.gatewayUrl
output apiManagementDeveloperPortalHostName string = replace(
  apiManagementService.properties.developerPortalUrl,
  'https://',
  ''
)
output aiLoggerId string = enableLoggers ? aiLoggerWithInstrumenationKey.id : ''
