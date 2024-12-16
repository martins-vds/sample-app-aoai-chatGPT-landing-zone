metadata description = 'Creates an Azure Cosmos DB account.'
param accountName string
param location string = resourceGroup().location
param secondaryLocation string = ''
param privateEndpointSubnetId string
param linkPrivateEndpointToPrivateDns bool = true
param privateDnsZoneResourceGroup string
param tags object = {}

@allowed(['GlobalDocumentDB', 'MongoDB', 'Parse'])
param kind string

param enableServerless bool = false

param databaseName string
param containers array = []
param principalIds array = []

@description('The default consistency level of the Cosmos DB account.')
@allowed([
  'Eventual'
  'ConsistentPrefix'
  'Session'
  'BoundedStaleness'
  'Strong'
])
param defaultConsistencyLevel string = 'Session'

@description('Max stale requests. Required for BoundedStaleness. Valid ranges, Single Region: 10 to 2147483647. Multi Region: 100000 to 2147483647.')
@minValue(10)
@maxValue(2147483647)
param maxStalenessPrefix int = 100000

@description('Max lag time (minutes). Required for BoundedStaleness. Valid ranges, Single Region: 5 to 84600. Multi Region: 300 to 86400.')
@minValue(5)
@maxValue(86400)
param maxIntervalInSeconds int = 300

@description('Enable system managed failover for regions')
param systemManagedFailover bool = false

@description('Maximum autoscale throughput for the container')
@minValue(1000)
@maxValue(1000000)
param autoscaleMaxThroughput int = 1000

param keyVaultName string

var consistencyPolicy = {
  Eventual: {
    defaultConsistencyLevel: 'Eventual'
  }
  ConsistentPrefix: {
    defaultConsistencyLevel: 'ConsistentPrefix'
  }
  Session: {
    defaultConsistencyLevel: 'Session'
  }
  BoundedStaleness: {
    defaultConsistencyLevel: 'BoundedStaleness'
    maxStalenessPrefix: maxStalenessPrefix
    maxIntervalInSeconds: maxIntervalInSeconds
  }
  Strong: {
    defaultConsistencyLevel: 'Strong'
  }
}

var locations = union(
  [
    {
      locationName: location
      failoverPriority: 0
      isZoneRedundant: false
    }
  ],
  !empty(secondaryLocation)
    ? [
        {
          locationName: secondaryLocation
          failoverPriority: 1
          isZoneRedundant: false
        }
      ]
    : []
)

var procs = flatten(map(
  range(0, length(containers)),
  i =>
    containers[i].?procs != null
      ? map(containers[i].procs, proc => {
          index: i
          container: containers[i].name
          procName: proc.name
          procBody: proc.body
        })
      : []
))

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
  name: accountName
  kind: kind
  location: location
  tags: tags
  properties: {
    consistencyPolicy: consistencyPolicy[defaultConsistencyLevel]
    locations: locations
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: systemManagedFailover
    enableMultipleWriteLocations: false
    apiProperties: (kind == 'MongoDB') ? { serverVersion: '4.0' } : {}
    capabilities: enableServerless ? [{ name: 'EnableServerless' }] : []
    publicNetworkAccess: 'Disabled'
    networkAclBypass: 'AzureServices'
  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  parent: cosmos
  name: databaseName
  properties: {
    resource: { id: databaseName }
  }

  resource databaseContainers 'containers' = [
    for container in containers: {
      name: container.name
      properties: {
        resource: {
          id: container.id
          partitionKey: { paths: [container.partitionKey] }
        }
        options: enableServerless
          ? {}
          : {
              autoscaleSettings: {
                maxThroughput: autoscaleMaxThroughput
              }
            }
      }
    }
  ]
}

resource storedProcedures 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/storedProcedures@2024-05-15' = [
  for proc in procs: {
    parent: database::databaseContainers[proc.index]
    name: proc.procName
    properties: {
      resource: {
        id: proc.procName
        body: proc.procBody
      }
    }
  }
]

resource roleDefinition 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2024-05-15' = {
  parent: cosmos
  name: guid(cosmos.id, accountName, 'sql-role')
  properties: {
    assignableScopes: [
      cosmos.id
    ]
    permissions: [
      {
        dataActions: [
          'Microsoft.DocumentDB/databaseAccounts/readMetadata'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*'
          'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*'
        ]
        notDataActions: []
      }
    ]
    roleName: 'Reader Writer'
    type: 'CustomRole'
  }
}

resource role 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-05-15' = [
  for principalId in principalIds: if (!empty(principalId)) {
    parent: cosmos
    name: guid(roleDefinition.id, principalId, cosmos.id)
    properties: {
      principalId: principalId
      roleDefinitionId: roleDefinition.id
      scope: cosmos.id
    }
  }
]

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: '${cosmos.name}-endpoint'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${cosmos.name}-connection'
        properties: {
          privateLinkServiceId: cosmos.id
          groupIds: [
            'Sql'
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

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = if (linkPrivateEndpointToPrivateDns) {
  scope: resourceGroup(privateDnsZoneResourceGroup)
  name: 'privatelink.documents.azure.com'
}

module accountKeySecret '../../security/vault-secret.bicep' = {
  name: 'accountKeySecret-${cosmos.name}'
  params: {
    keyVaultName: keyVaultName
    keyVaultSecretName: '${accountName}-key'
    keyVaultSecretValue: cosmos.listKeys().primaryMasterKey
  }
}

output endpoint string = cosmos.properties.documentEndpoint
output id string = cosmos.id
output name string = cosmos.name
output accountKeySecretUri string = accountKeySecret.outputs.secretUri
