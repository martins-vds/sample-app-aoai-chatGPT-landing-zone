param location string
param vnetName string
param vnetAddressRange string
param subnetPrefixLength int = 27

param apimSubnetExistingRouteTableName string
param appGatewayExistingRouteTableName string

param hasCustomDnsServers bool = false

param createDnsZones bool = false

param tags object = {}

var v4Info = parseCidr(vnetAddressRange)
var octets = split(v4Info.network, '.')
var incrementOctet = subnetPrefixLength <= 8 ? 0 : (subnetPrefixLength <= 16 ? 1 : (subnetPrefixLength <= 24 ? 2 : 3))

var defaultSubnetName = 'defaultSubnet'
var defaultSubnetIPPrefix = cidrSubnet(vnetAddressRange, subnetPrefixLength, int(octets[incrementOctet]))
var defaultNsgName = 'defaultSubnetNsg'

var apimSubnetName = 'apimSubnet'
var apimSubnetIPPrefix = cidrSubnet(vnetAddressRange, subnetPrefixLength, int(octets[incrementOctet]) + 1)
var apimNsgName = 'apimSubnetNsg'

var webAppSubnetName = 'appSubnet'
var webAppSubnetIPPrefix = cidrSubnet(vnetAddressRange, subnetPrefixLength, int(octets[incrementOctet]) + 2)
var webAppNsgName = 'appSubnetNsg'

var deploymentScriptSubnetName = 'containerInstanceSubnet'
var deploymentScriptSubnetIPPrefix = cidrSubnet(vnetAddressRange, subnetPrefixLength, int(octets[incrementOctet]) + 3)

var appGatewaySubnetName = 'appGatewaySubnet'
var appGatewaySubnetIPPrefix = cidrSubnet(vnetAddressRange, subnetPrefixLength, int(octets[incrementOctet]) + 4)
var appGatewayNsgName = 'appGatewaySubnetNsg'

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: vnetName
}

resource apimRouteTableParent 'Microsoft.Network/routeTables@2024-01-01' existing = if (!empty(apimSubnetExistingRouteTableName)) {
  name: apimSubnetExistingRouteTableName
}

resource apimRouteTableInternetRoute 'Microsoft.Network/routeTables/routes@2024-01-01' = if (!empty(apimSubnetExistingRouteTableName)) {
  parent: apimRouteTableParent
  name: 'internetRoute'
  properties: {
    addressPrefix: '0.0.0.0/0'
    nextHopType: 'Internet'
  }
}

resource apimRouteTableManagementRoute 'Microsoft.Network/routeTables/routes@2024-01-01' = if (!empty(apimSubnetExistingRouteTableName)) {
  parent: apimRouteTableParent
  name: 'managementRoute'
  properties: {
    addressPrefix: 'ApiManagement'
    nextHopType: 'Internet'
  }
}

resource appGatewayRouteTableParent 'Microsoft.Network/routeTables@2024-01-01' existing = if (!empty(apimSubnetExistingRouteTableName)) {
  name: appGatewayExistingRouteTableName
}

resource appGatewayRouteTableInternetRoute 'Microsoft.Network/routeTables/routes@2024-01-01' = if (!empty(apimSubnetExistingRouteTableName)) {
  parent: appGatewayRouteTableParent
  name: 'internetRoute'
  properties: {
    addressPrefix: '0.0.0.0/0'
    nextHopType: 'Internet'
  }
}

resource defaultSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  parent: vnet
  name: defaultSubnetName  
  properties: {
    addressPrefix: defaultSubnetIPPrefix
    networkSecurityGroup: {
      id: defaultNsg.id
    }
    serviceEndpoints: [
      {
        service: 'Microsoft.CognitiveServices'
      }
      {
        service: 'Microsoft.AzureCosmosDB'
      }
      {
        service: 'Microsoft.Storage'
      }
      {
        service: 'Microsoft.KeyVault'
      }
      {
        service: 'Microsoft.ContainerRegistry'
      }
      {
        service: 'Microsoft.ServiceBus'
      }
    ]
  }
}

resource apimSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  parent: vnet
  name: apimSubnetName
  properties: {
    addressPrefix: apimSubnetIPPrefix
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
      }
      {
        service: 'Microsoft.Sql'
      }
      {
        service: 'Microsoft.EventHub'
      }
      {
        service: 'Microsoft.ServiceBus'
      }
      {
        service: 'Microsoft.KeyVault'
      }
      {
        service: 'Microsoft.AzureActiveDirectory'
      }
    ]
    networkSecurityGroup: {
      id: apimNsg.id
    }
    routeTable: !empty(apimSubnetExistingRouteTableName)
      ? {
          id: apimRouteTableParent.id
        }
      : null
  }

  dependsOn: [
    defaultSubnet
  ]
}

resource webAppSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  parent: vnet
  name: webAppSubnetName
  properties: {
    addressPrefix: webAppSubnetIPPrefix
    delegations: [
      {
        name: 'delegation'
        properties: {
          serviceName: 'Microsoft.Web/serverfarms'
        }
      }
    ]
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
      }
    ]
    networkSecurityGroup: {
      id: appNsg.id
    }
  }

  dependsOn: [
    apimSubnet
  ]
}

resource deploymentScriptSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  parent: vnet
  name: deploymentScriptSubnetName
  properties: {
    addressPrefix: deploymentScriptSubnetIPPrefix
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
      }
      {
        service: 'Microsoft.KeyVault'
      }
      {
        service: 'Microsoft.CognitiveServices'
      }
      {
        service: 'Microsoft.ContainerRegistry'
      }
    ]
    delegations: [
      {
        name: 'containerDelegation'
        properties: {
          serviceName: 'Microsoft.ContainerInstance/containerGroups'
        }
      }
    ]
  }

  dependsOn: [
    webAppSubnet
  ]
}

resource appGatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  parent: vnet
  name: appGatewaySubnetName
  properties: {
    addressPrefix: appGatewaySubnetIPPrefix
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
      }
      {
        service: 'Microsoft.Sql'
      }
      {
        service: 'Microsoft.EventHub'
      }
      {
        service: 'Microsoft.ServiceBus'
      }
      {
        service: 'Microsoft.KeyVault'
      }
      {
        service: 'Microsoft.AzureActiveDirectory'
      }
    ]
    privateEndpointNetworkPolicies: 'Enabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
    networkSecurityGroup: {
      id: nsgAppGateway.id
    }
    routeTable: {
      id: appGatewayRouteTableParent.id
    }
  }

  dependsOn: [
    deploymentScriptSubnet
  ]
}

resource defaultNsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: defaultNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'SSH'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

resource appNsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: webAppNsgName
  location: location
  tags: tags
}

resource apimNsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: apimNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      // Rules for API Management as documented here: https://docs.microsoft.com/en-us/azure/api-management/api-management-using-with-vnet
      {
        name: 'Client_communication_to_API_Management'
        properties: {
          protocol: 'TCP'
          sourcePortRange: '*'
          priority: 110
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRanges: [
            '80'
            '443'
          ]
        }
      }
      {
        name: 'Management_endpoint_for_Azure_portal_and_PowerShell'
        properties: {
          destinationPortRange: '3443'
          protocol: 'TCP'
          sourcePortRange: '*'
          priority: 120
          sourceAddressPrefix: 'ApiManagement'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRanges: []
        }
      }
      {
        name: 'Dependency_on_Azure_Storage'
        properties: {
          destinationPortRange: '443'
          protocol: 'TCP'
          sourcePortRange: '*'
          priority: 130
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Storage'
          access: 'Allow'
          direction: 'Outbound'
          destinationPortRanges: []
        }
      }
      {
        name: 'Microsoft_Entra_ID_Microsoft_Graph_and_Azure_Key_Vault_dependency'
        properties: {
          destinationPortRange: '443'
          protocol: 'TCP'
          sourcePortRange: '*'
          priority: 140
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureActiveDirectory'
          access: 'Allow'
          direction: 'Outbound'
          destinationPortRanges: []
        }
      }
      {
        name: 'managed_connections_dependency'
        properties: {
          destinationPortRange: '443'
          protocol: 'TCP'
          sourcePortRange: '*'
          priority: 150
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureConnectors'
          access: 'Allow'
          direction: 'Outbound'
          destinationPortRanges: []
        }
      }
      {
        name: 'Access_to_Azure_SQL_endpoints'
        properties: {
          destinationPortRange: '1433'
          protocol: 'TCP'
          sourcePortRange: '*'
          priority: 160
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Sql'
          access: 'Allow'
          direction: 'Outbound'
          destinationPortRanges: []
        }
      }
      {
        name: 'Access_to_Azure_Key_Vault'
        properties: {
          destinationPortRange: '443'
          protocol: 'TCP'
          sourcePortRange: '*'
          priority: 170
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureKeyVault'
          access: 'Allow'
          direction: 'Outbound'
          destinationPortRanges: []
        }
      }
      {
        name: 'Dependency_for_Log_to_Azure_Event_Hubs_policy_and_Azure_Monitor'
        properties: {
          protocol: 'TCP'
          sourcePortRange: '*'
          priority: 180
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'EventHub'
          access: 'Allow'
          direction: 'Outbound'
          destinationPortRanges: [
            '5671'
            '5672'
            '443'
          ]
        }
      }
      {
        name: 'Dependency_on_Azure_File_Share_for_GIT'
        properties: {
          destinationPortRange: '445'
          protocol: 'TCP'
          sourcePortRange: '*'
          priority: 190
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'Storage'
          access: 'Allow'
          direction: 'Outbound'
          destinationPortRanges: []
        }
      }
      {
        name: 'Publish_Diagnostics_Logs_and_Metrics_Resource_Health_and_Application_Insights'
        properties: {
          protocol: 'TCP'
          sourcePortRange: '*'
          priority: 200
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'AzureMonitor'
          access: 'Allow'
          direction: 'Outbound'
          destinationPortRanges: [
            '1886'
            '443'
          ]
        }
      }
      {
        name: 'Access_external_Azure_Cache_for_Redis_service_for_caching_policies_inbound'
        properties: {
          destinationPortRange: '6380'
          protocol: 'TCP'
          sourcePortRange: '*'
          priority: 210
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRanges: []
        }
      }
      {
        name: 'Access_external_Azure_Cache_for_Redis_service_for_caching_policies_outbound'
        properties: {
          destinationPortRange: '6380'
          protocol: 'TCP'
          sourcePortRange: '*'
          priority: 220
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          direction: 'Outbound'
          destinationPortRanges: []
        }
      }
      {
        name: 'Access_internal_Azure_Cache_for_Redis_service_for_caching_policies_inbound'
        properties: {
          destinationPortRange: '6381 - 6383'
          protocol: 'TCP'
          sourcePortRange: '*'
          priority: 230
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRanges: []
        }
      }
      {
        name: 'Access_internal_Azure_Cache_for_Redis_service_for_caching_policies_outbound'
        properties: {
          destinationPortRange: '6381 - 6383'
          protocol: 'TCP'
          sourcePortRange: '*'
          priority: 240
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          direction: 'Outbound'
          destinationPortRanges: []
        }
      }
      {
        name: 'Sync_Counters_for_Rate_Limit_policies_between_machines_Inbound'
        properties: {
          destinationPortRange: '4290'
          protocol: 'UDP'
          sourcePortRange: '*'
          priority: 250
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRanges: []
        }
      }
      {
        name: 'Sync_Counters_for_Rate_Limit_policies_between_machines_Outbound'
        properties: {
          destinationPortRange: '4290'
          protocol: 'UDP'
          sourcePortRange: '*'
          priority: 260
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          direction: 'Outbound'
          destinationPortRanges: []
        }
      }
      {
        name: 'Azure_Infrastructure_Load_Balancer'
        properties: {
          destinationPortRange: '6390'
          protocol: 'TCP'
          sourcePortRange: '*'
          priority: 270
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRanges: []
        }
      }
      {
        name: 'Azure_Traffic_Manager_routing_for_multi_region_deployment'
        properties: {
          destinationPortRange: '443'
          protocol: 'TCP'
          sourcePortRange: '*'
          priority: 280
          sourceAddressPrefix: 'AzureTrafficManager'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRanges: []
        }
      }
      {
        name: 'Monitoring_of_individual_machine_health'
        properties: {
          destinationPortRange: '6391'
          protocol: 'TCP'
          sourcePortRange: '*'
          priority: 290
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRanges: []
        }
      }
    ]
  }
}

resource nsgAppGateway 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: appGatewayNsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'agw-in'
        properties: {
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          description: 'App Gateway inbound'
          priority: 100
          sourceAddressPrefix: 'GatewayManager'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '65200-65535'
        }
      }
      {
        name: 'https-in'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '80'
            '443'
          ]
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
          description: 'Allow HTTPS Inbound'
        }
      }
    ]
  }
}

module dnsZones 'private-dns-zones.bicep' = if (createDnsZones) {
  name: 'dnsZones'
  params: {
    vnetId: vnet.id
    tags: tags
  }

  dependsOn: [
    appGatewaySubnet
  ]
}

output vnetName string = vnetName
output vnetId string = vnet.id
output defaultSubnetResourceId string = resourceId(
  'Microsoft.Network/virtualNetworks/subnets',
  vnetName,
  defaultSubnetName
)

output defaultNsgId string = defaultNsg.id

output apiManagementSubnetResourceId string = resourceId(
  'Microsoft.Network/virtualNetworks/subnets',
  vnetName,
  apimSubnetName
)

output apiManagementSubnetAddressPrefix string = apimSubnetIPPrefix

output webAppSubnetResourceId string = resourceId(
  'Microsoft.Network/virtualNetworks/subnets',
  vnetName,
  webAppSubnetName
)

output webAppSubnetAddressPrefix string = webAppSubnetIPPrefix

output deploymentScriptSubnetName string = deploymentScriptSubnetName

output deploymentScriptSubnetResourceId string = resourceId(
  'Microsoft.Network/virtualNetworks/subnets',
  vnetName,
  deploymentScriptSubnetName
)

output deploymentScriptSubnetAddressPrefix string = deploymentScriptSubnetIPPrefix

output appGatewaySubnetResourceId string = resourceId(
  'Microsoft.Network/virtualNetworks/subnets',
  vnetName,
  appGatewaySubnetName
)

output appGatewaySubnetAddressPrefix string = appGatewaySubnetIPPrefix

output dnsServers string[] = hasCustomDnsServers ? vnet.properties.dhcpOptions.dnsServers : []
