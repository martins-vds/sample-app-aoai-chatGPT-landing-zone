targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Prefix for all resources')
param appName string

@minLength(1)
@maxLength(64)
@allowed([
  'dev'
  'uat'
  'prd'
])
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string = 'dev'

@minLength(1)
@description('Primary location for all resources')
param location string

param vnetName string
param vnetResourceGroupName string
param vnetResourceGroupLocation string = location
param vnetAddressRange string
param vnetSubnetPrefixLength int = 27
param vnetHasCustomDnsServers bool = false

param privateDnsZonesResourceGroupName string = vnetResourceGroupName

param apimRouteTableName string
param appGatewayRouteTableName string

param apimServiceName string = ''
param apimEnableLoggers bool = false
param apimRateLimitCalls int = 100
param apimRateLimitPeriod int = 60

param eventHubNamespaceName string = ''
param eventHubName string = ''

param containerRegistryName string = ''
param containerRegistryResourceGroupName string = ''
param containerRegistryAdminUserEnabled bool = true

param backendAppServicePlanName string = ''
param backendServiceName string = ''
param backendOpenApiSpecJson string = ''

param indexingFunctionAppServicePlanName string = ''
param indexingFunctionAppName string = ''
param indexingFunctionAppStorageAccountName string = ''

param resourceGroupName string = ''

param gatewayName string = ''
param gatewayAllowedIps array = []
param gatewayPreventionMode bool = false
param gatewayPublicUrl string = ''
@secure()
param gatewayBase64EncodedCertificate string = ''
@secure()
param gatewayCertificatePassword string = ''

param logAnalyticsName string = ''
param applicationInsightsName string = ''
param applicationInsightsDashboardName string = ''

param keyVaultName string = ''

param searchServiceName string = ''
param searchServiceResourceGroupName string = ''
param searchServiceResourceGroupLocation string = location
param searchServiceSkuName string = ''
param searchIndexName string = 'gptkbindex'
param searchFeedbackIndexName string = 'gptkbindex'
param searchFeedbackIndexAnalyzerName string = 'gptkbindexanalyzer'
param searchUseSemanticSearch bool = true
param searchUsePromptFlow bool = false
param searchSemanticSearchConfig string = 'default'
param searchTopK int = 5
param searchEnableInDomain bool = false
param searchContentColumns string = 'chunk'
param searchFilenameColumn string = 'filename'
param searchTitleColumn string = 'title'
param searchUrlColumn string = 'location_url'
param searchVectorColumns string = 'vector'
param searchIndexPreChunked bool = false
param searchPermittedGroupsColumn string = ''
param searchQueryType string = 'vector_semantic_hybrid'
param searchStrictness string = '3'

param storageAccountName string = ''
param storageResourceGroupName string = ''
param storageResourceGroupLocation string = location
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Premium_LRS'
])
param storageSkuName string = 'Standard_LRS'

param deployOpenAi bool = true

param openAiResourceName string = ''
param openAiResourceGroupName string = ''
param openAiResourceGroupLocation string = location

param openAiResourceNameSecondary string = ''
param openAiResourceGroupNameSecondary string = ''
param openAiResourceGroupLocationSecondary string = location

param openAiSkuName string = ''
param openAIModelDeploymentName string = 'turbo16k'
@allowed([
  'gpt-35-turbo-16k'
  'gpt-4o'
])
param openAIModelName string = 'gpt-35-turbo-16k'
param openAIModelVersion string = '0613'
param openAIModelSkuTier string = 'Standard'
param openAIModelCapacity int = 30

param openAIModelSkuTierSecondary string = 'Standard'
param openAIModelCapacitySecondary int = 30

param openAITemperature int = 0
param openAITopP int = 1
param openAIMaxTokens int = 1000
param openAIStopSequence string = ''
param openAISystemMessage string = 'You are an AI assistant that helps people find information.'
param openAIApiVersion string = '2024-06-01'
param openAIStream bool = true
param openAIEmbeddingDeploymentName string = 'embedding'
param openAIEmbeddingModelName string = 'text-embedding-3-large'
param openAIEmbeddingModelVersion string = ''
param openAIEmbeddingModelCapacity int = 350
param openAIEmbeddingModelSkuTier string = 'Standard'
param openAIModelMaxTokens string = 'None'
param openAIModelStopSequence string = '\\n'
param openAIModelStream bool = false

param openAIEmbeddingDeploymentSecondaryEnabled bool = false

param formRecognizerServiceName string = ''
param formRecognizerResourceGroupName string = ''
param formRecognizerResourceGroupLocation string = location
param formRecognizerSkuName string = ''
param formRecognizerApiVersion string = '2023-07-31'

param languageServiceName string = ''
param languageServiceResourceGroupName string = ''
param languageServiceResourceGroupLocation string = location
param languageServiceSkuName string = ''

// Used for the Azure AD application
param authClientId string = ''
@secure()
param authClientSecret string = ''

// Used for Cosmos DB
param cosmosAccountName string = ''
param cosmosSecondaryRegion string = ''

@description('Id of the user or app to assign application roles')
param principalId string = ''

param assignRbacRoles bool = true
param assignApimRoles bool = true

param tags object = {}

var abbrs = loadJsonContent('abbreviations.json')
var resourceName = '${appName}-${environmentName}'
var resourceToken = toLower(uniqueString(subscription().id, resourceName, location))

var mainResourceGroupName = !empty(resourceGroupName)
  ? resourceGroupName
  : '${abbrs.resourcesResourceGroups}${resourceName}'

var unionTags = union(tags, {
  'azd-env-name': resourceName
})

// The application backend
var authIssuerUri = '${environment().authentication.loginEndpoint}${tenant().tenantId}/v2.0'

var backendApiDefinitionJson = empty(backendOpenApiSpecJson)
  ? loadTextContent('../infra/apim/api_definitions/BackendApi_OpenAPI.json', 'utf-8')
  : backendOpenApiSpecJson
var backendApiPoliciesXml = loadTextContent('../infra/apim/apim_policies/backend_api.xml', 'utf-8')

var isDev = environmentName != 'prd'
var isProd = environmentName == 'prd'
var backendAppServiceName = !empty(backendServiceName)
  ? backendServiceName
  : '${abbrs.webSitesAppService}backend-${resourceToken}'
var backendAppServicePlan = !empty(backendAppServicePlanName)
  ? backendAppServicePlanName
  : '${abbrs.webServerFarms}backend-${resourceToken}'

// Organize resources in a resource group
resource mainResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: mainResourceGroupName
  location: location
  tags: unionTags
}

resource vnetResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: vnetResourceGroupName
  location: vnetResourceGroupLocation
  tags: unionTags
}

resource languageServiceResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' existing = if (!empty(languageServiceResourceGroupName)) {
  name: !empty(languageServiceResourceGroupName) ? languageServiceResourceGroupName : mainResourceGroupName
}

resource formRecognizerResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' existing = if (!empty(formRecognizerResourceGroupName)) {
  name: !empty(formRecognizerResourceGroupName) ? formRecognizerResourceGroupName : mainResourceGroupName
}

resource containerRegistryResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' existing = if (!empty(containerRegistryResourceGroupName)) {
  name: !empty(containerRegistryResourceGroupName) ? containerRegistryResourceGroupName : mainResourceGroupName
}

resource openAiResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' existing = if (!empty(openAiResourceGroupName)) {
  name: !empty(openAiResourceGroupName) ? openAiResourceGroupName : mainResourceGroupName
}

resource openAiResourceGroupSecondary 'Microsoft.Resources/resourceGroups@2024-03-01' existing = if (!empty(openAiResourceGroupNameSecondary) && isProd) {
  name: !empty(openAiResourceGroupNameSecondary) ? openAiResourceGroupNameSecondary : mainResourceGroupName
}

resource searchServiceResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' existing = if (!empty(searchServiceResourceGroupName)) {
  name: !empty(searchServiceResourceGroupName) ? searchServiceResourceGroupName : mainResourceGroupName
}

resource storageResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' existing = if (!empty(storageResourceGroupName)) {
  name: !empty(storageResourceGroupName) ? storageResourceGroupName : mainResourceGroupName
}

module backendIdentity 'core/security/identity.bicep' = {
  name: 'backend-identity'
  scope: mainResourceGroup
  params: {
    tags: unionTags
    managedIdentityName: !empty(backendServiceName)
      ? backendServiceName
      : '${abbrs.managedIdentityUserAssignedIdentities}backend-${resourceToken}'
  }
}

module indexingFunctionIdentity 'core/security/identity.bicep' = {
  name: 'indexing-function-identity'
  scope: mainResourceGroup
  params: {
    tags: unionTags
    managedIdentityName: !empty(indexingFunctionAppName)
      ? indexingFunctionAppName
      : '${abbrs.managedIdentityUserAssignedIdentities}function-${resourceToken}'
  }
}

module network 'core/network/network.bicep' = {
  scope: vnetResourceGroup
  name: 'network'
  params: {
    tags: unionTags
    location: vnetResourceGroup.location
    vnetAddressRange: vnetAddressRange
    vnetName: vnetName
    subnetPrefixLength: vnetSubnetPrefixLength
    apimSubnetExistingRouteTableName: apimRouteTableName
    appGatewayExistingRouteTableName: appGatewayRouteTableName
    hasCustomDnsServers: vnetHasCustomDnsServers
    createDnsZones: isDev
  }
}

module vault 'core/security/vault.bicep' = {
  scope: mainResourceGroup
  name: 'keyvault'
  params: {
    tags: unionTags
    privateEndpointSubnetId: network.outputs.defaultSubnetResourceId
    linkPrivateEndpointToPrivateDns: isDev
    keyVaultName: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    privateDnsZoneResourceGroup: privateDnsZonesResourceGroupName
  }
}

// Monitor application with Azure Monitor
module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: mainResourceGroup
  params: {
    location: location
    tags: unionTags
    logAnalyticsName: !empty(logAnalyticsName)
      ? logAnalyticsName
      : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName)
      ? applicationInsightsName
      : '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: !empty(applicationInsightsDashboardName)
      ? applicationInsightsDashboardName
      : '${abbrs.portalDashboards}${resourceToken}'
    privateLinkScopeName: '${abbrs.networkPrivateLinkServices}${resourceToken}'
    privateDnsZoneResourceGroup: privateDnsZonesResourceGroupName
    privateEndpointSubnetId: network.outputs.apiManagementSubnetResourceId // TODO: Fix this. It have its own subnet
    linkPrivateEndpointToPrivateDns: isDev
  }
}

module storage 'core/storage/storage-account.bicep' = {
  name: 'storage'
  scope: storageResourceGroup
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    location: storageResourceGroupLocation
    tags: unionTags
    publicNetworkAccess: 'Disabled'
    privateEndpointSubnetId: network.outputs.defaultSubnetResourceId
    linkPrivateEndpointToPrivateDns: isDev
    privateDnsZoneResourceGroup: privateDnsZonesResourceGroupName
    keyVaultName: vault.outputs.keyVaultName
    sku: {
      name: storageSkuName
    }
    deleteRetentionPolicy: {
      enabled: true
      days: 2
    }
    virtualNetworkRules: [
      {
        id: network.outputs.deploymentScriptSubnetResourceId
        action: 'Allow'
        state: 'Succeeded'
      }
      {
        id: network.outputs.webAppSubnetResourceId
        action: 'Allow'
        state: 'Succeeded'
      }
    ]
  }
}

// Create an App Service Plan to group applications under the same payment plan and SKU

module backend 'core/host/appservice.bicep' = {
  name: 'web'
  scope: mainResourceGroup
  params: {
    runFromPackage: true
    sku: isProd ? 'P0V3' : 'B2'
    functionAppScaleLimit: isProd ? 5 : -1
    minimumElasticInstanceCount: isProd ? 3 : -1
    numberOfWorkers: isProd ? 3 : -1
    zoneRedundant: isProd
    keyVaultName: vault.outputs.keyVaultName
    identityType: 'UserAssigned'
    identityName: backendIdentity.outputs.name
    authClientSecret: authClientSecret
    authClientId: authClientId
    authIssuerUri: authIssuerUri
    authUnauthenticatedAction: 'Return401'
    authAllowedRedirectUrls: union(
      [
        appGateway.outputs.fqdn
      ],
      empty(gatewayPublicUrl) ? [] : [gatewayPublicUrl]
    )
    appServiceName: backendAppServiceName
    appServicePlanName: backendAppServicePlan
    location: location
    tags: union(unionTags, { 'azd-service-name': 'backend' })
    scmDoBuildDuringDeployment: true
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    inboundSubnetResourceId: network.outputs.defaultSubnetResourceId
    outboundSubnetResourceId: network.outputs.webAppSubnetResourceId
    linkPrivateEndpointToPrivateDns: isDev
    privateDnsZoneResourceGroup: privateDnsZonesResourceGroupName
    appSettings: {
      AZURE_COSMOSDB_ACCOUNT: cosmos.outputs.accountName
      AZURE_COSMOSDB_ACCOUNT_KEY: '@Microsoft.KeyVault(SecretUri=${cosmos.outputs.accountKeySecretUri})'
      AZURE_COSMOSDB_CONVERSATIONS_CONTAINER: 'conversations'
      AZURE_COSMOSDB_DATABASE: 'db_conversation_history'
      AZURE_COSMOSDB_ENABLE_FEEDBACK: 'True'
      AZURE_FEEDBACK_SEARCH_INDEX: searchFeedbackIndexName
      AZURE_FEEDBACK_SEARCH_INDEX_ANALYZER: searchFeedbackIndexAnalyzerName
      AZURE_FORM_RECOGNIZER_API_VERSION: formRecognizerApiVersion
      AZURE_FORM_RECOGNIZER_SERVICE: formRecognizer.outputs.name
      AZURE_OPEN_AI_BASE: apim.outputs.apiManagementGatewayUrl
      AZURE_OPENAI_API_KEY: '@Microsoft.KeyVault(SecretUri=${apim.outputs.openAiApiSubscriptionSecretUri})'
      AZURE_OPENAI_API_VERSION: openAIApiVersion
      AZURE_OPENAI_CHATGPT3_5_DEPLOYMENT: ''
      AZURE_OPENAI_CHATGPT3_5_MODEL_NAME: ''
      AZURE_OPENAI_CHATGPT4_DEPLOYMENT: openAIModelDeploymentName
      AZURE_OPENAI_CHATGPT4_MODEL_NAME: openAIModelName
      AZURE_OPENAI_CHOICES_COUNT: 1
      AZURE_OPENAI_EMBEDDING_API_VERSION: openAIApiVersion
      AZURE_OPENAI_EMBEDDING_DEPLOYMENT_NAME: openAIEmbeddingDeploymentName
      AZURE_OPENAI_EMBEDDING_ENDPOINT: apim.outputs.apiManagementGatewayUrl
      AZURE_OPENAI_EMBEDDING_KEY: '@Microsoft.KeyVault(SecretUri=${apim.outputs.openAiApiSubscriptionSecretUri})'
      AZURE_OPENAI_EMBEDDING_MODEL_NAME: openAIEmbeddingModelName
      AZURE_OPENAI_EMBEDDING_NAME: openAIEmbeddingDeploymentName
      AZURE_OPENAI_ENDPOINT: apim.outputs.apiManagementGatewayUrl
      AZURE_OPENAI_FREQUENCY_PENALTY: 0
      AZURE_OPENAI_KEY: '@Microsoft.KeyVault(SecretUri=${apim.outputs.openAiApiSubscriptionSecretUri})'
      AZURE_OPENAI_LOGIT_BIAS: ''
      AZURE_OPENAI_MAX_TOKENS: openAIMaxTokens
      AZURE_OPENAI_MODEL: openAIModelName
      AZURE_OPENAI_MODEL_DEPLOYMENT_NAME: openAIModelDeploymentName
      AZURE_OPENAI_MODEL_MAX_TOKENS: openAIModelMaxTokens
      AZURE_OPENAI_MODEL_NAME: openAIModelName
      AZURE_OPENAI_MODEL_STOP_SEQUENCE: openAIModelStopSequence
      AZURE_OPENAI_MODEL_STREAM: openAIModelStream
      AZURE_OPENAI_MODEL_TEMPERATURE: openAITemperature
      AZURE_OPENAI_MODEL_TOP_P: openAITopP
      AZURE_OPENAI_PRESENCE_PENALTY: 0
      AZURE_OPENAI_PREVIEW_API_VERSION: '2024-05-01-preview'
      AZURE_OPENAI_RESOURCE: openAi.?outputs.name ?? ''
      AZURE_OPENAI_SEED: ''
      AZURE_OPENAI_SERVICE: openAi.outputs.name
      AZURE_OPENAI_STOP_SEQUENCE: openAIStopSequence
      AZURE_OPENAI_STREAM: openAIStream
      AZURE_OPENAI_SYSTEM_MESSAGE: openAISystemMessage
      AZURE_OPENAI_TEMPERATURE: openAITemperature
      AZURE_OPENAI_TOOL_CHOICE: ''
      AZURE_OPENAI_TOOLS: ''
      AZURE_OPENAI_TOP_P: openAITopP
      AZURE_OPENAI_USER: ''
      AZURE_SEARCH_CONTENT_COLUMNS: searchContentColumns
      AZURE_SEARCH_ENABLE_IN_DOMAIN: searchEnableInDomain
      AZURE_SEARCH_FILENAME_COLUMN: searchFilenameColumn
      AZURE_SEARCH_INDEX: searchIndexName
      AZURE_SEARCH_INDEX_IS_PRECHUNKED: searchIndexPreChunked
      AZURE_SEARCH_KEY: '@Microsoft.KeyVault(SecretUri=${searchService.outputs.adminKeySecretUri})'
      AZURE_SEARCH_PERMITTED_GROUPS_COLUMN: searchPermittedGroupsColumn
      AZURE_SEARCH_QUERY_TYPE: searchQueryType
      AZURE_SEARCH_SEMANTIC_SEARCH_CONFIG: searchSemanticSearchConfig
      AZURE_SEARCH_SERVICE: searchService.outputs.name
      AZURE_SEARCH_STRICTNESS: searchStrictness
      AZURE_SEARCH_TITLE_COLUMN: searchTitleColumn
      AZURE_SEARCH_TOP_K: searchTopK
      AZURE_SEARCH_URL: searchService.outputs.endpoint
      AZURE_SEARCH_URL_COLUMN: searchUrlColumn
      AZURE_SEARCH_USE_SEMANTIC_SEARCH: searchUseSemanticSearch
      AZURE_SEARCH_VECTOR_COLUMNS: searchVectorColumns
      AZURE_STORAGE_ACCOUNT: storage.outputs.name
      CREATE_INDEX_ON_START: true
      DATASOURCE_TYPE: 'AzureCognitiveSearch'
      DEBUG: isDev
      DOTENV_PATH: '.env'
      ENABLE_VECTOR_EMBEDDING: true
      KB_FIELDS_CONTENT: ''
      KB_FIELDS_SOURCEPAGE: ''
      OPEN_API_VERSION: openAIApiVersion
      OPENAI_API_KEY: '@Microsoft.KeyVault(SecretUri=${apim.outputs.openAiApiSubscriptionSecretUri})'
      OPENAI_CONTEXT_WINDOW: 120000
      OPENAI_EMBEDDING_DEPLOYMENT: openAIEmbeddingDeploymentName
      OPENAI_EMBEDDING_MODEL: openAIEmbeddingModelName
      SEARCH_ENABLE_IN_DOMAIN: searchEnableInDomain
      SEARCH_STRICTNESS: searchStrictness
      SEARCH_TOP_K: searchTopK
      SERVER_SOFTWARE: 'gunicorn'
      USE_PROMPTFLOW: searchUsePromptFlow
    }
  }
}

module languageService 'core/ai/cognitiveservices.bicep' = {
  scope: languageServiceResourceGroup
  name: 'language-service'
  params: {
    name: !empty(languageServiceName) ? languageServiceName : '${abbrs.cognitiveServicesAccounts}language-${resourceToken}'
    tags: unionTags
    sku: {
      name: !empty(languageServiceSkuName) ? languageServiceSkuName : 'S0'
    }
    keyVaultName: vault.outputs.keyVaultName
    kind: 'TextAnalytics'
    location: languageServiceResourceGroupLocation
    publicNetworkAccess: 'Disabled'
    privateEndpointLocation: vnetResourceGroupLocation
    privateEndpointSubnetId: network.outputs.defaultSubnetResourceId
    linkPrivateEndpointToPrivateDns: isDev
    privateDnsZoneResourceGroup: privateDnsZonesResourceGroupName
  }
}

module openAi 'core/ai/cognitiveservices.bicep' = if (deployOpenAi) {
  name: 'openai'
  scope: openAiResourceGroup
  params: {
    name: !empty(openAiResourceName) ? openAiResourceName : '${abbrs.cognitiveServicesAccounts}aoai-${resourceToken}'
    location: openAiResourceGroupLocation
    tags: unionTags
    sku: {
      name: !empty(openAiSkuName) ? openAiSkuName : 'S0'
    }
    keyVaultName: vault.outputs.keyVaultName
    kind: 'OpenAI'
    publicNetworkAccess: 'Disabled'
    privateEndpointLocation: location
    privateEndpointSubnetId: network.outputs.defaultSubnetResourceId
    linkPrivateEndpointToPrivateDns: isDev
    privateDnsZoneResourceGroup: privateDnsZonesResourceGroupName
    deployments: [
      {
        name: openAIModelDeploymentName
        model: {
          format: 'OpenAI'
          name: openAIModelName
          version: openAIModelVersion
        }
        capacity: openAIModelCapacity
        skuName: openAIModelSkuTier
      }
      {
        name: openAIEmbeddingDeploymentName
        model: {
          format: 'OpenAI'
          name: openAIEmbeddingModelName
          version: openAIEmbeddingModelVersion
        }
        capacity: openAIEmbeddingModelCapacity
        skuName: openAIEmbeddingModelSkuTier
      }
    ]
  }
}

module openAiSecondary 'core/ai/cognitiveservices.bicep' = if (deployOpenAi && isProd) {
  name: 'openai-secondary'
  scope: openAiResourceGroupSecondary
  params: {
    name: !empty(openAiResourceNameSecondary)
      ? openAiResourceNameSecondary
      : '${abbrs.cognitiveServicesAccounts}aoai-sec-${resourceToken}'
    location: openAiResourceGroupLocationSecondary
    tags: unionTags
    sku: {
      name: !empty(openAiSkuName) ? openAiSkuName : 'S0'
    }
    keyVaultName: vault.outputs.keyVaultName
    kind: 'OpenAI'
    publicNetworkAccess: 'Disabled'
    privateEndpointLocation: location
    privateEndpointSubnetId: network.outputs.defaultSubnetResourceId
    linkPrivateEndpointToPrivateDns: isDev
    privateDnsZoneResourceGroup: privateDnsZonesResourceGroupName
    deployments: union(
      [
        {
          name: openAIModelDeploymentName
          model: {
            format: 'OpenAI'
            name: openAIModelName
            version: openAIModelVersion
          }
          capacity: openAIModelCapacitySecondary
          skuName: openAIModelSkuTierSecondary
        }
      ],
      openAIEmbeddingDeploymentSecondaryEnabled
        ? [
            {
              name: openAIEmbeddingDeploymentName
              model: {
                format: 'OpenAI'
                name: openAIEmbeddingModelName
                version: openAIEmbeddingModelVersion
              }
              capacity: openAIEmbeddingModelCapacity
              skuName: openAIEmbeddingModelSkuTier
            }
          ]
        : []
    )
  }
}

module eventHub 'core/event-hub.bicep' = {
  name: 'event-hub'
  scope: mainResourceGroup
  params: {
    location: location
    tags: unionTags
    eventHubNamespaceName: !empty(eventHubNamespaceName)
      ? eventHubNamespaceName
      : '${abbrs.eventHubNamespaces}${resourceToken}'
    eventHubName: !empty(eventHubName) ? eventHubName : '${abbrs.eventHubNamespacesEventHubs}${resourceToken}'
    privateEndpointSubnetId: network.outputs.defaultSubnetResourceId
    linkPrivateEndpointToPrivateDns: isDev
    privateDnsZoneResourceGroup: privateDnsZonesResourceGroupName
  }
}

module apim 'apim.bicep' = {
  scope: mainResourceGroup
  name: 'apim'
  params: {
    tags: unionTags
    apiManagementServiceName: !empty(apimServiceName)
      ? apimServiceName
      : '${abbrs.apiManagementService}${resourceToken}'
    apiManagmentSubnetResourceId: network.outputs.apiManagementSubnetResourceId
    apiManagementSku: isProd ? 'Premium' : 'Developer'
    apiManagementSkuCount: isProd ? 3 : 1
    eventHubNamespaceName: eventHub.outputs.namespaceName
    azureOpenAiRegionType: isProd ? 'Multi' : 'Single'
    apiServiceNamePrimary: openAi.?outputs.name ?? ''
    apiServiceRgPrimary: openAiResourceGroup.name
    apiServiceNameSecondary: isProd ? openAiSecondary.?outputs.name : ''
    apiServiceRgSecondary: isProd ? openAiResourceGroupSecondary.name : ''
    enableRetryPolicy: isProd
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    allowedOrigins: union(
      [
        'http://${resourceName}.${mainResourceGroup.location}.cloudapp.azure.com'
        'https://${!empty(backendServiceName) ? backendServiceName : '${abbrs.webSitesAppService}backend-${resourceToken}'}.azurewebsites.net'
      ],
      !empty(gatewayPublicUrl) ? [gatewayPublicUrl] : []
    )
    backendApiUrl: 'https://${!empty(backendServiceName) ? backendServiceName : '${abbrs.webSitesAppService}backend-${resourceToken}'}.azurewebsites.net'
    backendApiDefinitionJson: backendApiDefinitionJson
    backendApiPoliciesXml: backendApiPoliciesXml
    backendApiSubscriptionRequired: isProd
    enableAzureOpenAiSupport: deployOpenAi
    assignRbacRoles: assignRbacRoles && assignApimRoles
    enableLoggers: apimEnableLoggers
    keyVaultName: vault.outputs.keyVaultName
    autoScale: isProd
    zoneRedundant: isProd
    rateLimitCalls: apimRateLimitCalls
    rateLimitPeriod: apimRateLimitPeriod
    linkPrivateEndpointToPrivateDns: isDev
    privateDnsZonesResourceGroup: privateDnsZonesResourceGroupName
  }
}

// The application database
module cosmos 'db.bicep' = {
  name: 'cosmos'
  scope: mainResourceGroup
  params: {
    accountName: !empty(cosmosAccountName) ? cosmosAccountName : '${abbrs.documentDBDatabaseAccounts}${resourceToken}'
    location: location
    secondaryLocation: isProd ? cosmosSecondaryRegion : ''
    tags: unionTags
    principalIds: [principalId, backendIdentity.outputs.principalId, indexingFunctionIdentity.outputs.principalId]
    privateEndpointSubnetId: network.outputs.defaultSubnetResourceId
    linkPrivateEndpointToPrivateDns: isDev
    privateDnsZonesResourceGroup: privateDnsZonesResourceGroupName
    enableServerless: environmentName != 'prd'
    keyVaultName: vault.outputs.keyVaultName
  }
}

module formRecognizer 'core/ai/cognitiveservices.bicep' = {
  name: 'formrecognizer${resourceToken}'
  scope: formRecognizerResourceGroup
  params: {
    name: !empty(formRecognizerServiceName)
      ? formRecognizerServiceName
      : '${abbrs.cognitiveServicesFormRecognizer}${resourceToken}'
    kind: 'FormRecognizer'
    autoScaleEnabled: isProd
    location: formRecognizerResourceGroupLocation
    tags: unionTags
    sku: {
      name: !empty(formRecognizerSkuName) ? formRecognizerSkuName : 'S0'
    }
    privateEndpointSubnetId: network.outputs.defaultSubnetResourceId
    publicNetworkAccess: 'Disabled'
    keyVaultName: vault.outputs.keyVaultName
    linkPrivateEndpointToPrivateDns: isDev
    privateDnsZoneResourceGroup: privateDnsZonesResourceGroupName
    privateEndpointLocation: vnetResourceGroupLocation
  }

  dependsOn: [
    cosmos
  ]
}

module containerRegistry 'core/host/container-registry.bicep' = {
  name: 'container-registry'
  scope: containerRegistryResourceGroup
  params: {
    name: !empty(containerRegistryName) ? containerRegistryName : '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    adminUserEnabled: containerRegistryAdminUserEnabled
    tags: unionTags
    publicNetworkAccess: 'Disabled'
    privateEndpointSubnetId: network.outputs.defaultSubnetResourceId
    linkPrivateEndpointToPrivateDns: isDev
    privateDnsZoneResourceGroup: privateDnsZonesResourceGroupName
    sku: {
      name: 'Premium'
    }
  }
}

module indexingFunction 'core/host/function.bicep' = {
  scope: mainResourceGroup
  name: 'index-function-app'
  params: {
    location: location
    runFromPackage: true
    zoneRedundant: isProd
    keyVaultName: vault.outputs.keyVaultName
    identityType: 'UserAssigned'
    identityName: indexingFunctionIdentity.outputs.name
    appServicePlanName: !empty(indexingFunctionAppServicePlanName)
      ? indexingFunctionAppServicePlanName
      : '${abbrs.webServerFarms}function-${resourceToken}'
    functionAppName: !empty(indexingFunctionAppName)
      ? indexingFunctionAppName
      : '${abbrs.webSitesFunctions}${resourceToken}'
    tags: union(unionTags, { 'azd-service-name': 'function' })
    inboundSubnetResourceId: network.outputs.defaultSubnetResourceId
    outboundSubnetResourceId: network.outputs.webAppSubnetResourceId
    linkPrivateEndpointToPrivateDns: isDev
    privateDnsZoneResourceGroup: privateDnsZonesResourceGroupName
    storageAccountName: !empty(indexingFunctionAppStorageAccountName)
      ? indexingFunctionAppStorageAccountName
      : '${abbrs.storageStorageAccounts}function${resourceToken}'
    applicationInsightsName: monitoring.outputs.applicationInsightsName
  }
}

module searchService 'core/search/search-services.bicep' = {
  name: 'search-service'
  scope: searchServiceResourceGroup
  params: {
    name: !empty(searchServiceName) ? searchServiceName : '${abbrs.searchSearchServices}${resourceToken}'
    location: searchServiceResourceGroupLocation
    privateEndpointSubnetId: network.outputs.defaultSubnetResourceId
    linkPrivateEndpointToPrivateDns: isDev
    privateDnsZoneResourceGroup: privateDnsZonesResourceGroupName
    tags: unionTags
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    sku: {
      name: !empty(searchServiceSkuName) ? searchServiceSkuName : 'standard'
    }
    semanticSearch: isProd ? 'standard' : 'free'
    keyVaultName: vault.outputs.keyVaultName
    replicas: isProd ? 3 : 1
  }
}

module appGateway 'core/network/app-gateway.bicep' = {
  name: 'app-gateway'
  scope: mainResourceGroup
  params: {
    location: location
    gatewaySubnetResourceId: network.outputs.appGatewaySubnetResourceId
    aiName: monitoring.outputs.applicationInsightsName
    apimName: apim.outputs.apiManagementServiceName
    gatewayName: !empty(gatewayName) ? gatewayName : '${abbrs.networkApplicationGateways}${resourceToken}'
    tags: unionTags
    publicIPName: '${abbrs.networkPublicIPAddresses}${resourceToken}'
    domainNameLabel: resourceName
    frontendAppName: backendAppServiceName
    gatewayBase64EncodedCertificate: gatewayBase64EncodedCertificate
    gatewayCertificatePassword: gatewayCertificatePassword
    maxCapacity: isProd ? 5 : 2
    enableZoneRedundancy: isProd
    enablePreventionMode: gatewayPreventionMode
    allowedIps: gatewayAllowedIps
  }
}

var azureRoles = loadJsonContent('azure_roles.json')

// USER ROLES
module openAiRoleUser 'core/security/role.bicep' = if (assignRbacRoles && deployOpenAi && !empty(principalId)) {
  scope: openAiResourceGroup
  name: 'openai-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: azureRoles.CognitiveServicesOpenAIUser
    principalType: 'User'
  }
}

module searchRoleUser 'core/security/role.bicep' = if (assignRbacRoles && !empty(principalId)) {
  scope: searchServiceResourceGroup
  name: 'search-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: azureRoles.SearchIndexDataReader
    principalType: 'User'
  }
}

module storageContribRoleUser 'core/security/role.bicep' = if (assignRbacRoles && !empty(principalId)) {
  scope: storageResourceGroup
  name: 'storage-contrib-role-user'
  params: {
    principalId: principalId
    // Storage Blob Data Contributor
    roleDefinitionId: azureRoles.StorageBlobDataContributor
    principalType: 'User'
  }
}

module searchIndexDataContribRoleUser 'core/security/role.bicep' = if (assignRbacRoles && !empty(principalId)) {
  scope: searchServiceResourceGroup
  name: 'search-index-data-contrib-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: azureRoles.SearchIndexDataContributor
    principalType: 'User'
  }
}

module searchServiceContribRoleUser 'core/security/role.bicep' = if (assignRbacRoles && !empty(principalId)) {
  scope: searchServiceResourceGroup
  name: 'search-service-contrib-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: azureRoles.SearchServiceContributor
    principalType: 'User'
  }
}

module formRecognizerRoleUser 'core/security/role.bicep' = if (assignRbacRoles && !empty(principalId)) {
  scope: formRecognizerResourceGroup
  name: 'form-recognizer-role-user'
  params: {
    principalId: principalId
    roleDefinitionId: azureRoles.CognitiveServicesUser
    principalType: 'User'
  }
}

// SYSTEM IDENTITIES

module containerRegistryBackendRole 'core/security/registry-access.bicep' = if (assignRbacRoles) {
  scope: containerRegistryResourceGroup
  name: 'container-registry-backend-role'
  params: {
    principalId: backend.outputs.identityPrincipalId
    containerRegistryName: containerRegistry.outputs.name
  }
}

module openAiRoleBackend 'core/security/role.bicep' = if (assignRbacRoles && deployOpenAi) {
  scope: openAiResourceGroup
  name: 'openai-role-backend'
  params: {
    principalId: backend.outputs.identityPrincipalId
    roleDefinitionId: azureRoles.CognitiveServicesOpenAIUser
    principalType: 'ServicePrincipal'
  }
}

module openAiRoleFunction 'core/security/role.bicep' = if (assignRbacRoles && deployOpenAi) {
  scope: openAiResourceGroup
  name: 'openai-role-function'
  params: {
    principalId: indexingFunction.outputs.identityPrincipalId
    roleDefinitionId: azureRoles.CognitiveServicesOpenAIUser
    principalType: 'ServicePrincipal'
  }
}

module storageRoleBackend 'core/security/role.bicep' = if (assignRbacRoles) {
  scope: storageResourceGroup
  name: 'storage-role-backend'
  params: {
    principalId: backend.outputs.identityPrincipalId
    // Storage Blob Data Reader
    roleDefinitionId: azureRoles.StorageBlobDataReader
    principalType: 'ServicePrincipal'
  }
}

module storageContributorRoleBackend 'core/security/role.bicep' = if (assignRbacRoles) {
  scope: storageResourceGroup
  name: 'storage-contributor-role-backend'
  params: {
    principalId: backend.outputs.identityPrincipalId
    // Storage Blob Data Contributor
    roleDefinitionId: azureRoles.StorageBlobDataContributor
    principalType: 'ServicePrincipal'
  }
}

module queueContributorRoleBackend 'core/security/role.bicep' = if (assignRbacRoles) {
  scope: storageResourceGroup
  name: 'queue-contributor-role-backend'
  params: {
    principalId: backend.outputs.identityPrincipalId
    // Storage Blob Data Contributor
    roleDefinitionId: azureRoles.StorageQueueDataContributor
    principalType: 'ServicePrincipal'
  }
}

module queueContributorRoleFunction 'core/security/role.bicep' = if (assignRbacRoles) {
  scope: storageResourceGroup
  name: 'queue-contributor-role-function'
  params: {
    principalId: indexingFunction.outputs.identityPrincipalId
    // Storage Blob Data Contributor
    roleDefinitionId: azureRoles.StorageQueueDataContributor
    principalType: 'ServicePrincipal'
  }
}

module queueDataProcessorRoleFunction 'core/security/role.bicep' = if (assignRbacRoles) {
  scope: storageResourceGroup
  name: 'queue-data-proc-role-function'
  params: {
    principalId: indexingFunction.outputs.identityPrincipalId
    // Storage Blob Data Contributor
    roleDefinitionId: azureRoles.StorageQueueDataMessageProcessor
    principalType: 'ServicePrincipal'
  }
}

module queueDataSenderRoleFunction 'core/security/role.bicep' = if (assignRbacRoles) {
  scope: storageResourceGroup
  name: 'queue-data-sender-role-function'
  params: {
    principalId: indexingFunction.outputs.identityPrincipalId
    // Storage Blob Data Contributor
    roleDefinitionId: azureRoles.StorageQueueDataMessageSender
    principalType: 'ServicePrincipal'
  }
}

module storageContributorRoleFunction 'core/security/role.bicep' = if (assignRbacRoles) {
  scope: storageResourceGroup
  name: 'storage-contributor-role-function'
  params: {
    principalId: indexingFunction.outputs.identityPrincipalId
    // Storage Blob Data Contributor
    roleDefinitionId: azureRoles.StorageBlobDataContributor
    principalType: 'ServicePrincipal'
  }
}

module searchIndexReaderRoleBackend 'core/security/role.bicep' = if (assignRbacRoles) {
  scope: searchServiceResourceGroup
  name: 'search-role-backend'
  params: {
    principalId: backend.outputs.identityPrincipalId
    roleDefinitionId: azureRoles.SearchIndexDataReader
    principalType: 'ServicePrincipal'
  }
}

module searchIndexContributorRoleBackend 'core/security/role.bicep' = if (assignRbacRoles) {
  scope: searchServiceResourceGroup
  name: 'search-index-contributor-role-backend'
  params: {
    principalId: backend.outputs.identityPrincipalId
    roleDefinitionId: azureRoles.SearchIndexDataContributor
    principalType: 'ServicePrincipal'
  }
}

module searchContributorRoleBackend 'core/security/role.bicep' = if (assignRbacRoles) {
  scope: searchServiceResourceGroup
  name: 'search-contributor-role-backend'
  params: {
    principalId: backend.outputs.identityPrincipalId
    roleDefinitionId: azureRoles.SearchServiceContributor
    principalType: 'ServicePrincipal'
  }
}

module searchContributorRoleFunction 'core/security/role.bicep' = if (assignRbacRoles) {
  scope: searchServiceResourceGroup
  name: 'search-contributor-role-function'
  params: {
    principalId: indexingFunction.outputs.identityPrincipalId
    roleDefinitionId: azureRoles.SearchServiceContributor
    principalType: 'ServicePrincipal'
  }
}

module searchOpenAiContribRoleBackend 'core/security/role.bicep' = if (assignRbacRoles) {
  scope: searchServiceResourceGroup
  name: 'search-openai-contrib-role'
  params: {
    principalId: searchService.outputs.identityPrincipalId
    roleDefinitionId: azureRoles.CognitiveServicesOpenAIContributor
    principalType: 'ServicePrincipal'
  }
}

module searchOpenAiContribRoleFunction 'core/security/role.bicep' = if (assignRbacRoles) {
  scope: searchServiceResourceGroup
  name: 'search-openai-contrib-role-function'
  params: {
    principalId: indexingFunction.outputs.identityPrincipalId
    roleDefinitionId: azureRoles.CognitiveServicesOpenAIContributor
    principalType: 'ServicePrincipal'
  }
}

module openAiSearchIndexRoleBackend 'core/security/role.bicep' = if (assignRbacRoles) {
  scope: searchServiceResourceGroup
  name: 'openai-search-index-role'
  params: {
    principalId: openAi.outputs.identityPrincipalId
    roleDefinitionId: azureRoles.SearchIndexDataReader
    principalType: 'ServicePrincipal'
  }

  dependsOn: [
    searchService
  ]
}

module openAiSearchContributorRoleBackend 'core/security/role.bicep' = if (assignRbacRoles) {
  scope: searchServiceResourceGroup
  name: 'openai-search-contrib-role'
  params: {
    principalId: openAi.outputs.identityPrincipalId
    roleDefinitionId: azureRoles.SearchServiceContributor
    principalType: 'ServicePrincipal'
  }

  dependsOn: [
    searchService
  ]
}

module keyvaultRoleBackend 'core/security/role.bicep' = if (assignRbacRoles) {
  scope: mainResourceGroup
  name: 'keyvault-role-backend'
  params: {
    principalId: backend.outputs.identityPrincipalId
    roleDefinitionId: azureRoles.KeyVaultSecretsUser
    principalType: 'ServicePrincipal'
  }
}

module keyvaultRoleFunction 'core/security/role.bicep' = if (assignRbacRoles) {
  scope: mainResourceGroup
  name: 'keyvault-role-function'
  params: {
    principalId: indexingFunction.outputs.identityPrincipalId
    roleDefinitionId: azureRoles.KeyVaultSecretsUser
    principalType: 'ServicePrincipal'
  }
}

module searchIndexDataContribRoleFunction 'core/security/role.bicep' = if (assignRbacRoles) {
  scope: searchServiceResourceGroup
  name: 'search-index-data-contrib-role-function'
  params: {
    principalId: indexingFunction.outputs.identityPrincipalId
    roleDefinitionId: azureRoles.SearchIndexDataContributor
    principalType: 'ServicePrincipal'
  }
}

module formrecognizerRoleBackend 'core/security/role.bicep' = if (assignRbacRoles) {
  scope: formRecognizerResourceGroup
  name: 'form-recognizer-user-role-backend'
  params: {
    principalId: backend.outputs.identityPrincipalId
    roleDefinitionId: azureRoles.CognitiveServicesUser
    principalType: 'ServicePrincipal'
  }
}

module cognitiveUserRoleFunction 'core/security/role.bicep' = if (assignRbacRoles) {
  scope: formRecognizerResourceGroup
  name: 'cognitive-user-role-function'
  params: {
    principalId: indexingFunction.outputs.identityPrincipalId
    roleDefinitionId: azureRoles.CognitiveServicesUser
    principalType: 'ServicePrincipal'
  }
}

module cosmosContributorRoleBackend 'core/security/role.bicep' = if (assignRbacRoles) {
  scope: mainResourceGroup
  name: 'cosmos-role-backend'
  params: {
    principalId: backend.outputs.identityPrincipalId
    roleDefinitionId: azureRoles.CosmosDBOperator
    principalType: 'ServicePrincipal'
  }
}

module cosmosContributorRoleFunction 'core/security/role.bicep' = if (assignRbacRoles) {
  scope: mainResourceGroup
  name: 'cosmos-role-function'
  params: {
    principalId: indexingFunction.outputs.identityPrincipalId
    roleDefinitionId: azureRoles.CosmosDBOperator
    principalType: 'ServicePrincipal'
  }
}

output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = mainResourceGroup.name

output BACKEND_URI string = backend.outputs.uri

// search
output AZURE_SEARCH_INDEX string = searchIndexName
output AZURE_SEARCH_SERVICE string = searchService.outputs.name
output AZURE_SEARCH_SERVICE_RESOURCE_GROUP string = searchServiceResourceGroup.name
output AZURE_SEARCH_SKU_NAME string = searchService.outputs.skuName
output AZURE_SEARCH_USE_SEMANTIC_SEARCH bool = searchUseSemanticSearch
output AZURE_SEARCH_SEMANTIC_SEARCH_CONFIG string = searchSemanticSearchConfig
output AZURE_SEARCH_TOP_K int = searchTopK
output AZURE_SEARCH_ENABLE_IN_DOMAIN bool = searchEnableInDomain
output AZURE_SEARCH_CONTENT_COLUMNS string = searchContentColumns
output AZURE_SEARCH_FILENAME_COLUMN string = searchFilenameColumn
output AZURE_SEARCH_TITLE_COLUMN string = searchTitleColumn
output AZURE_SEARCH_URL_COLUMN string = searchUrlColumn

// openai
output AZURE_OPENAI_RESOURCE string = openAi.outputs.name
output AZURE_OPENAI_RESOURCE_GROUP string = openAiResourceGroup.name
output AZURE_OPENAI_ENDPOINT string = openAi.outputs.endpoint
output AZURE_OPENAI_MODEL string = openAIModelDeploymentName
output AZURE_OPENAI_MODEL_NAME string = openAIModelName
output AZURE_OPENAI_SKU_NAME string = openAi.outputs.skuName
output AZURE_OPENAI_EMBEDDING_NAME string = openAIEmbeddingDeploymentName
output AZURE_OPENAI_TEMPERATURE int = openAITemperature
output AZURE_OPENAI_TOP_P int = openAITopP
output AZURE_OPENAI_MAX_TOKENS int = openAIMaxTokens
output AZURE_OPENAI_STOP_SEQUENCE string = openAIStopSequence
output AZURE_OPENAI_SYSTEM_MESSAGE string = openAISystemMessage
output AZURE_OPENAI_STREAM bool = openAIStream

// Used by prepdocs.py:
output AZURE_FORMRECOGNIZER_SERVICE string = formRecognizer.outputs.name
output AZURE_FORMRECOGNIZER_RESOURCE_GROUP string = formRecognizer.outputs.resourceGroup
output AZURE_FORMRECOGNIZER_SKU_NAME string = formRecognizer.outputs.skuName

// cosmos
output AZURE_COSMOSDB_ACCOUNT string = cosmos.outputs.accountName
output AZURE_COSMOSDB_DATABASE string = cosmos.outputs.databaseName
output AZURE_COSMOSDB_CONVERSATIONS_CONTAINER string = cosmos.outputs.containerName

output AUTH_ISSUER_URI string = authIssuerUri
