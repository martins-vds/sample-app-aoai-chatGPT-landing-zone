param name string
param storageAccountName string
param identityId string
param subnetId string
param location string = resourceGroup().location
param environmentVariables environmentVariable[] = []
param scriptContent string

type environmentVariable = {
  name: string
  value: string?
  secureValue: string?
}

var mountPath = '/mnt/azscripts/azscriptinput'
var containerName = 'azscriptcontainer'
var containerImage = 'mcr.microsoft.com/azuredeploymentscripts-powershell:az12.1'
var scriptFileName = 'script.ps1'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName

  resource fileShare 'fileServices' existing = {
    name: 'default'

    resource scriptShare 'shares' = {
      name: 'scripts'
    }
  }
}

resource uploadScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'upload-file-${storageAccount.name}'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
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
          id: subnetId
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
        value: scriptContent
      }
    ]
    scriptContent: 'echo "$CONTENT" > ${scriptFileName} && az storage file upload -s ${storageAccount::fileShare::scriptShare.name} --source ${scriptFileName}'
  }
}

resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: name
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    subnetIds: [
      {
        id: subnetId
      }
    ]
    containers: [
      {
        name: containerName
        properties: {
          image: containerImage
          resources: {
            requests: {
              cpu: 1
              memoryInGB: json('1.5')
            }
          }
          ports: [
            {
              protocol: 'TCP'
              port: 80
            }
          ]
          volumeMounts: [
            {
              name: 'filesharevolume'
              mountPath: mountPath
            }
          ]
          environmentVariables: environmentVariables
          command: [
            '/bin/sh'
            '-c'
            'pwsh -f ${mountPath}/${scriptFileName}'
          ]
        }
      }
    ]
    osType: 'Linux'
    restartPolicy: 'Never'
    volumes: [
      {
        name: 'filesharevolume'
        azureFile: {
          readOnly: false
          shareName: storageAccount::fileShare::scriptShare.name
          storageAccountName: storageAccountName
          storageAccountKey: storageAccount.listKeys().keys[0].value
        }
      }
    ]
  }

  dependsOn: [
    uploadScript
  ]
}
