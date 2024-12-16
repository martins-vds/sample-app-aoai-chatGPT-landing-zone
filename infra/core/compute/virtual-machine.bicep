@description('The name of your Virtual Machine.')
param vmName string = 'simpleLinuxVM'

@description('Username for the Virtual Machine.')
param adminUsername string

@description('Type of authentication to use on the Virtual Machine. SSH key is recommended.')
@allowed([
  'sshPublicKey'
  'password'
])
param authenticationType string = 'password'

@description('SSH Key or password for the Virtual Machine. SSH key is recommended.')
@secure()
param adminPasswordOrKey string

@description('The Ubuntu version for the VM. This will pick a fully patched image of this given Ubuntu version.')
@allowed([
  'Ubuntu-2004'
  'Ubuntu-2204'
])
param ubuntuOSVersion string = 'Ubuntu-2004'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('The size of the VM')
param vmSize string = 'Standard_D2s_v3'

@description('Name of the subnet in the virtual network')
param subnetId string = 'Subnet'

@description('Id of the Network Security Group')
param networkSecurityGroupId string

param nicName string

@description('Security Type of the Virtual Machine.')
@allowed([
  'Standard'
  'TrustedLaunch'
])
param securityType string = 'TrustedLaunch'

param scriptStorageAccountName string
param scriptUri string
param commandToExecute string = ''
param timestamp int = dateTimeToEpoch(utcNow())
param tags object = {}

var imageReference = {
  'Ubuntu-2004': {
    publisher: 'Canonical'
    offer: '0001-com-ubuntu-server-focal'
    sku: '20_04-lts-gen2'
    version: 'latest'
  }
  'Ubuntu-2204': {
    publisher: 'Canonical'
    offer: '0001-com-ubuntu-server-jammy'
    sku: '22_04-lts-gen2'
    version: 'latest'
  }
}

var osDiskType = 'Standard_LRS'
var linuxConfiguration = {
  disablePasswordAuthentication: true
  ssh: {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrKey
      }
    ]
  }
}
var securityProfileJson = {
  uefiSettings: {
    secureBootEnabled: true
    vTpmEnabled: true
  }
  securityType: securityType
}
var extensionName = 'GuestAttestation'
var extensionPublisher = 'Microsoft.Azure.Security.LinuxAttestation'
var extensionVersion = '1.0'
var maaTenantName = 'GuestAttestation'
var maaEndpoint = substring('emptystring', 0, 0)

resource networkInterface 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'          
        }
      }
    ]
    networkSecurityGroup: {
      id: networkSecurityGroupId
    }
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }
      imageReference: imageReference[ubuntuOSVersion]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      linuxConfiguration: ((authenticationType == 'password') ? null : linuxConfiguration)
    }
    securityProfile: (securityType == 'TrustedLaunch') ? securityProfileJson : null
  }
}

resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = if (securityType == 'TrustedLaunch' && securityProfileJson.uefiSettings.secureBootEnabled && securityProfileJson.uefiSettings.vTpmEnabled) {
  parent: vm
  name: extensionName
  location: location
  properties: {
    publisher: extensionPublisher
    type: extensionName
    typeHandlerVersion: extensionVersion
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    settings: {
      AttestationConfig: {
        MaaSettings: {
          maaEndpoint: maaEndpoint
          maaTenantName: maaTenantName
        }
      }
    }
  }
}

module scriptStorageAccess '../storage/storage-access.bicep' = {
  name: 'scriptStorageAccess'
  params: {
    storageAccountName: scriptStorageAccountName
    principalId: vm.identity.principalId
    roleId: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
  }
}

resource extension 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = if(!empty(commandToExecute)) {
  parent: vm
  name:'config-gh-runner'
  location:location
  properties:{
    publisher: 'Microsoft.Azure.Extensions'
    type:'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      timestamp: timestamp
    }
    protectedSettings:{
      commandToExecute: commandToExecute
      fileUris: [scriptUri]
      managedIdentity: {}
    }
  }

  dependsOn: [
    scriptStorageAccess
  ]
}

output identityPrincipalId string = vm.identity.principalId
