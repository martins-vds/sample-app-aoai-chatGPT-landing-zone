param availabilityZones array = []
param location string = resourceGroup().location
param containerName string = 'main'

param imageName string = ''

@allowed([
  'Linux'
  'Windows'
])
param osType string = 'Linux'
param containerCpuCoreCount int = 2
param containerMemory int = 4

@allowed([
  'OnFailure'
  'Always'
  'Never'
])
param restartPolicy string = 'OnFailure'

@allowed([
  'Standard'
  'Confidential'
])
param sku string = 'Standard'
@description('The name of the container registry')
param containerRegistryName string = ''

@allowed([
  'Public'
  'Private'
  'None'
])
param ipAddressType string = 'Private'
param ports array = [
  {
    port: 80
    protocol: 'TCP'
  }
  {
    port: '443'
    protocol: 'TCP'
  }
]
param subnetId string

@secure()
param runnerDnsServerPrimary string = ''
@secure()
param runnerDnsServerSecondary string = ''

@description('The environment variables for the container')
param env array = []

@description('The type of identity for the resource')
@allowed(['None', 'SystemAssigned', 'UserAssigned'])
param identityType string = 'None'

@description('The name of the user-assigned identity')
param identityName string = ''

param tags object = {}

// Private registry support requires both an ACR name and a User Assigned managed identity
var usePrivateRegistry = !empty(identityName) && !empty(containerRegistryName)

// Automatically set to `UserAssigned` when an `identityName` has been set
var normalizedIdentityType = !empty(identityName) ? 'UserAssigned' : identityType

var imageRegistryLoginServer = usePrivateRegistry ? '${containerRegistryName}.azurecr.io' : ''

resource userIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = if (!empty(identityName)) {
  name: identityName
}

module containerRegistryAccess '../security/registry-access.bicep' = if (usePrivateRegistry) {
  name: '${deployment().name}-registry-access'
  params: {
    containerRegistryName: containerRegistryName
    principalId: usePrivateRegistry ? userIdentity.properties.principalId : ''
  }
}

resource container 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  location: location
  name: containerName
  zones: availabilityZones
  tags: tags
  identity: {
    type: normalizedIdentityType
    userAssignedIdentities: !empty(identityName) && normalizedIdentityType == 'UserAssigned'
      ? { '${userIdentity.id}': {} }
      : null
  }
  properties: {
    dnsConfig: {
      nameServers: [
        runnerDnsServerPrimary
        runnerDnsServerSecondary
      ]
    }
    containers: [
      {
        name: containerName
        properties: {
          image: !empty(imageName) ? '${imageRegistryLoginServer}/${imageName}' : 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          environmentVariables: env
          resources: {
            requests: {
              cpu: containerCpuCoreCount
              memoryInGB: containerMemory
            }
          }
          ports: ports
        }
      }
    ]
    restartPolicy: restartPolicy
    osType: osType
    sku: sku
    imageRegistryCredentials: usePrivateRegistry
      ? [
          {
            server: imageRegistryLoginServer
            identity: userIdentity.id
          }
        ]
      : []
    ipAddress: {
      type: ipAddressType
      ports: ports
    }
    subnetIds: [
      {
        id: subnetId
      }
    ]
  }

  dependsOn: usePrivateRegistry ? [containerRegistryAccess] : []
}
