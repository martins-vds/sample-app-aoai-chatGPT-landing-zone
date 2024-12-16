param appServiceName string
param appServicePlanName string
param location string = resourceGroup().location
param tags object = {}

param useExistingAppServicePlan bool = false

// Reference Properties
param applicationInsightsName string = ''
param keyVaultName string = ''

@allowed([
  'None'
  'SystemAssigned'
  'UserAssigned'
])
param identityType string = 'None'

param identityName string = ''

// Runtime Properties
@allowed([
  'dotnet'
  'dotnetcore'
  'dotnet-isolated'
  'node'
  'python'
  'java'
  'powershell'
  'custom'
])
param runtimeName string = 'python'
param runtimeVersion string = '3.11'
param runtimeNameAndVersion string = '${runtimeName}|${runtimeVersion}'

param containerRegistryName string = ''
param containerImageName string = ''
param containerImageTag string = ''

// Microsoft.Web/sites Properties
@allowed([
  'functionapp,linux'
  'app,linux'
])
param kind string = 'app,linux'

// Microsoft.Web/sites/config
param allowedOrigins array = []
param alwaysOn bool = true
param appCommandLine string = ''
param appSettings object = {}
param authClientId string = ''
@secure()
param authClientSecret string = ''
param authIssuerUri string = ''
param authAllowedRedirectUrls array = []
@allowed([
  'AllowAnonymous'
  'RedirectToLoginPage'
  'Return401'
  'Return403'
])
param authUnauthenticatedAction string = 'RedirectToLoginPage'
param clientAffinityEnabled bool = false
param enableOryxBuild bool = contains(kind, 'linux')
param functionAppScaleLimit int = -1
param minimumElasticInstanceCount int = -1
param numberOfWorkers int = -1
param elasticWebAppScaleLimit int = functionAppScaleLimit
param scmDoBuildDuringDeployment bool = false
param use32BitWorkerProcess bool = false
param runFromPackage bool = false
param ftpsState string = 'FtpsOnly'
param healthCheckPath string = ''
param inboundSubnetResourceId string
param outboundSubnetResourceId string
param storageAccountName string = ''
param zoneRedundant bool = false
param linkPrivateEndpointToPrivateDns bool = true
param privateDnsZoneResourceGroup string
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Disabled'

@allowed([
  'B1'
  'B2'
  'EP3'
  'P0V3'
  'P1V3'
  'P2V3'
  'P3V3'
  'Y1'
])
param sku string = 'B1'

var containerRegistryServerUrl = empty(containerRegistryName)
  ? 'https://mcr.microsoft.com'
  : 'https://${containerRegistryName}.azurecr.io'

var containerImageNameAndTag = empty(containerImageName) || empty(containerImageTag)
  ? 'azuredocs/containerapps-helloworld:latest'
  : '${containerImageName}:${containerImageTag}'

var linuxFxVersion = empty(containerRegistryName)
  ? runtimeNameAndVersion
  : 'DOCKER|${containerRegistryServerUrl}/${containerImageNameAndTag}'

var appLogCategories = [
  'AppServiceAppLogs'
  'AppServiceConsoleLogs'
  'AppServiceHTTPLogs'
  'AppServicePlatformLogs'
  'AppServiceAuthenticationLogs'
]

var functionAppLogCategories = [
  'FunctionAppLogs'
  'AppServiceAuthenticationLogs'
]

var logCategories = contains(kind, 'functionapp') ? functionAppLogCategories : appLogCategories

var diagSettings = map(logCategories, log => {
  enabled: true
  category: log
})

var allowedAudiences = union(
  [
    'https://${appServiceName}.azurewebsites.net'
  ],
  authAllowedRedirectUrls
)

resource userIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = if (!empty(identityName)) {
  name: identityName
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = if (!empty(containerRegistryName)) {
  name: containerRegistryName
}

resource existingAppServicePlan 'Microsoft.Web/serverfarms@2023-12-01' existing = if (useExistingAppServicePlan) {
  name: appServicePlanName
}

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = if (!useExistingAppServicePlan) {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: sku
    capacity: numberOfWorkers != -1 ? numberOfWorkers : 1
  }
  kind: 'linux'
  properties: {
    reserved: true
    zoneRedundant: zoneRedundant
  }
}

resource appService 'Microsoft.Web/sites@2023-12-01' = {
  name: appServiceName
  location: location
  tags: tags
  kind: kind
  identity: {
    type: identityType
    userAssignedIdentities: !empty(identityName) && identityType == 'UserAssigned' ? { '${userIdentity.id}': {} } : null
  }
  properties: {
    serverFarmId: useExistingAppServicePlan ? existingAppServicePlan.id : appServicePlan.id
    virtualNetworkSubnetId: outboundSubnetResourceId
    reserved: kind == 'functionapp,linux'
    vnetRouteAllEnabled: true
    vnetContentShareEnabled: true
    vnetImagePullEnabled: true
    publicNetworkAccess: publicNetworkAccess
    keyVaultReferenceIdentity: identityType == 'UserAssigned' ? userIdentity.id : null
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      alwaysOn: alwaysOn
      http20Enabled: true
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      ftpsState: ftpsState
      appCommandLine: appCommandLine
      ipSecurityRestrictionsDefaultAction: 'Deny'
      numberOfWorkers: numberOfWorkers != -1 ? numberOfWorkers : null
      minimumElasticInstanceCount: minimumElasticInstanceCount != -1 ? minimumElasticInstanceCount : null
      use32BitWorkerProcess: use32BitWorkerProcess
      functionAppScaleLimit: functionAppScaleLimit != -1 ? functionAppScaleLimit : null
      healthCheckPath: healthCheckPath
      cors: {
        allowedOrigins: union(['https://portal.azure.com', 'https://ms.portal.azure.com'], allowedOrigins)
      }
      elasticWebAppScaleLimit: elasticWebAppScaleLimit != -1 ? elasticWebAppScaleLimit : null
    }
    clientAffinityEnabled: clientAffinityEnabled
    httpsOnly: false
  }

  resource configAppSettings 'config' = {
    name: 'appsettings'
    properties: union(
      appSettings,
      {
        SCM_DO_BUILD_DURING_DEPLOYMENT: string(scmDoBuildDuringDeployment)
        ENABLE_ORYX_BUILD: string(enableOryxBuild)
      },
      !empty(applicationInsightsName)
        ? {
            APPINSIGHTS_INSTRUMENTATIONKEY: applicationInsights.properties.InstrumentationKey
            APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.properties.ConnectionString
            ApplicationInsightsAgent_EXTENSION_VERSION: contains(kind, 'linux') ? '~3' : '~2'
          }
        : {},
      !empty(keyVaultName) ? { AZURE_KEY_VAULT_ENDPOINT: keyVault.properties.vaultUri } : {},
      !empty(authClientSecret) ? { AUTH_CLIENT_SECRET: authClientSecret } : {},
      kind == 'functionapp,linux'
        ? {
            FUNCTIONS_EXTENSION_VERSION: '~4'
            AzureWebJobsStorage: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccount.listkeys().keys[0].value}'
            WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccount.listkeys().keys[0].value}'
          }
        : {},
      kind == 'functionapp,linux' && empty(containerRegistryName)
        ? {
            FUNCTIONS_WORKER_RUNTIME: runtimeName
          }
        : {},
      !empty(containerRegistryName)
        ? {
            WEBSITES_ENABLE_APP_SERVICE_STORAGE: 'false'
            DOCKER_REGISTRY_SERVER_URL: containerRegistryServerUrl
            DOCKER_REGISTRY_SERVER_USERNAME: containerRegistry.properties.adminUserEnabled
              ? containerRegistry.listCredentials().username
              : ''
            DOCKER_REGISTRY_SERVER_PASSWORD: containerRegistry.properties.adminUserEnabled
              ? containerRegistry.listCredentials().passwords[0].value
              : ''
          }
        : {},
      {
        WEBSITE_RUN_FROM_PACKAGE: runFromPackage ? 1 : 0
      },
      !empty(identityName) && identityType == 'UserAssigned'
        ? {
            USER_ASSIGNED_MANAGED_IDENTITY_CLIENT_ID: userIdentity.properties.clientId
          }
        : {}
    )
  }

  resource configLogs 'config' = if (kind == 'app,linux') {
    name: 'logs'
    properties: {
      applicationLogs: { fileSystem: { level: 'Verbose' } }
      detailedErrorMessages: { enabled: true }
      failedRequestsTracing: { enabled: true }
      httpLogs: { fileSystem: { enabled: true, retentionInDays: 1, retentionInMb: 35 } }
    }

    dependsOn: [
      configAppSettings
    ]
  }

  resource configAuth 'config' = if (!(empty(authClientId))) {
    name: 'authsettingsV2'
    properties: {
      httpSettings: {
        requireHttps: true
        forwardProxy: {
          convention: 'Standard'
        }
      }
      globalValidation: {
        requireAuthentication: true
        unauthenticatedClientAction: authUnauthenticatedAction
        redirectToProvider: 'azureactivedirectory'
      }
      identityProviders: {
        azureActiveDirectory: {
          enabled: true
          registration: {
            clientId: authClientId
            clientSecretSettingName: 'AUTH_CLIENT_SECRET'
            openIdIssuer: authIssuerUri
          }
          validation: {
            allowedAudiences: allowedAudiences
          }
        }
      }
      login: {
        preserveUrlFragmentsForLogins: true
        tokenStore: {
          enabled: true
        }
        allowedExternalRedirectUrls: allowedAudiences
      }
    }
  }

  resource networkConfig 'networkConfig' = if (kind == 'functionapp,linux') {
    name: 'virtualNetwork'
    properties: {
      subnetResourceId: outboundSubnetResourceId
      swiftSupported: true
    }
  }
}

resource diagnosticsSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(applicationInsightsName)) {
  name: 'default'
  scope: appService
  properties: {
    workspaceId: applicationInsights.properties.WorkspaceResourceId
    logs: diagSettings
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = if (!(empty(keyVaultName))) {
  name: keyVaultName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if (!empty(applicationInsightsName)) {
  name: applicationInsightsName
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: '${appService.name}-endpoint'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: inboundSubnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: '${appService.name}-connection'
        properties: {
          privateLinkServiceId: appService.id
          groupIds: [
            'sites'
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
  name: 'privatelink.azurewebsites.net'
}

module registryAccess '../security/registry-access.bicep' = if (!empty(containerRegistryName) && identityType != 'None') {
  name: '${deployment().name}-registry-access'
  params: {
    containerRegistryName: containerRegistryName
    principalId: identityType == 'UserAssigned' ? userIdentity.properties.principalId : appService.identity.principalId
  }
}

output identityPrincipalId string = identityType == 'SystemAssigned'
  ? appService.identity.principalId
  : (identityType == 'UserAssigned' ? userIdentity.properties.principalId : '')
output name string = appService.name
output uri string = 'https://${appService.properties.defaultHostName}'
