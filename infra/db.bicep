param accountName string
param location string = resourceGroup().location
param secondaryLocation string = ''
param tags object = {}

param databaseName string = 'db_conversation_history'
param collectionName string = 'conversations'
param principalIds array = []

param privateEndpointSubnetId string
param linkPrivateEndpointToPrivateDns bool = true
param privateDnsZonesResourceGroup string

param containers container[] = [
  {
    name: collectionName
    id: collectionName
    partitionKey: '/userId'
  }
]

param enableServerless bool = false

param keyVaultName string

type container = {
  name: string
  id: string
  partitionKey: string
  procs: proc[]?
}

type proc = {
  name: string
  body: string
}

module cosmos 'core/database/cosmos/cosmos-account.bicep' = {
  name: 'cosmos-sql'
  params: {
    accountName: accountName
    databaseName: databaseName
    location: location
    secondaryLocation: secondaryLocation
    containers: containers
    tags: tags
    principalIds: principalIds
    kind: 'GlobalDocumentDB'
    privateEndpointSubnetId: privateEndpointSubnetId
    enableServerless: enableServerless
    keyVaultName: keyVaultName
    linkPrivateEndpointToPrivateDns: linkPrivateEndpointToPrivateDns
    privateDnsZoneResourceGroup: privateDnsZonesResourceGroup
  }
}


output databaseName string = databaseName
output containerName string = containers[0].name
output accountName string = accountName
output endpoint string = cosmos.outputs.endpoint
output accountKeySecretUri string = cosmos.outputs.accountKeySecretUri
