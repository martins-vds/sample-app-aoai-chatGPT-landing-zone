param storageAccountName string
param location string
param fileName string
param fileContent string
param containerName string
param scriptRunnerIdentityId string
param scriptSubnetId string

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' existing = {
  parent: storageAccount
  name: 'default'
}

resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' existing = {
  parent: blobService
  name: containerName
}

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'upload-file-${storageAccount.name}'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'    
    userAssignedIdentities: {
      '${scriptRunnerIdentityId}': {}
    }
  }
  properties: {
    azCliVersion: '2.57.0'
    timeout: 'PT5M'
    retentionInterval: 'PT1H'
    storageAccountSettings: {
      storageAccountName: storageAccount.name
    }
    containerSettings: {
      subnetIds: [
        {
          id: scriptSubnetId
        }
      ]
    }
    environmentVariables: [  
      {
        name: 'AZURE_STORAGE_ACCOUNT'
        value: storageAccount.name
      }
      {
        name: 'AZURE_STORAGE_KEY'
        secureValue: storageAccount.listKeys().keys[0].value
      }
      {
        name: 'CONTENT'
        value: fileContent
      }
    ]
    scriptContent: 'echo "$CONTENT" > ${fileName} && az storage blob upload --file ${fileName} --container-name ${blobContainer.name} --name ${fileName} --overwrite'
  }
}

output fileUri string = '${storageAccount.properties.primaryEndpoints.blob}${blobContainer.name}/${fileName}'
