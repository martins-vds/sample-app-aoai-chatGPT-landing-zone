@description('The location into which regionally scoped resources should be deployed. Note that Front Door is a global resource.')
param location string = resourceGroup().location

@description('The SKU of the API Management instance.')
@allowed([
  'Premium'
  'Developer'
  'BasicV2'
  'StandardV2'
])
param apiManagementSku string = 'Developer'

param apiManagmentSubnetResourceId string

@description('The name of the API publisher. This information is used by API Management.')
param apiManagementPublisherName string = 'Contoso'

@description('The email address of the API publisher. This information is used by API Management.')
param apiManagementPublisherEmail string = 'admin@contoso.com'

param enableAzureOpenAiSupport bool = false

@description('Provide the Name of the Azure OpenAI service.')
param apiServiceNamePrimary string = 'Insert_Your_Azure_OpenAi_Name_Here'

@description('Provide the Resource Group Name of the Azure OpenAI service.')
param apiServiceRgPrimary string = 'Insert_Resource_Group_Name_Here'

@description('If you want to provide resiliency when single region exceeds quota, then select Multi and provide URL to an additional Azure OpenAI endpoint. Otherwise, maintain default entry of Single and only provide one Azure OpenAI endpoint.')
@allowed([
  'Single'
  'Multi'
])
param azureOpenAiRegionType string = 'Single'

@description('If you select Multi in azureOpenAiRegionType, then you must provide another Azure OpenAI Name here.')
param apiServiceNameSecondary string = 'Maybe-Insert_Your_Secondary_Azure_OpenAi_Name_Here'

@description('If you select Multi in azureOpenAiRegionType, provide the Resource Group Name of the Azure OpenAI service.')
param apiServiceRgSecondary string = 'Maybe-Insert_Resource_Group_Name_Here'

@description('If you want to enable retry policy for the API, set this to true. Otherwise, set this to false.')
param enableRetryPolicy bool = false

param autoScale bool = false

param applicationInsightsName string

param apiManagementServiceName string
param apiManagementSkuCount int = 1

param eventHubNamespaceName string

param assignRbacRoles bool = false
param enableLoggers bool = assignRbacRoles
param allowedOrigins string[] = []

param keyVaultName string

param backendApiUrl string
param backendApiDefinitionJson string
param backendApiPoliciesXml string
param backendApiName string = 'backend-api'
param backendApiPath string = 'backend'
param backendApiSubscriptionName string = 'Backend-Api-Subscription'
param backendApiSubscriptionRequired bool = true

param zoneRedundant bool = false

param rateLimitCalls int = 20
param rateLimitPeriod int = 60

param privateDnsZonesResourceGroup string
param linkPrivateEndpointToPrivateDns bool = true

param tags object = {}

var apiServiceUrlPrimary = 'https://${apiServiceNamePrimary}.openai.azure.com/openai'
var apiServiceUrlSecondary = 'https://${apiServiceNameSecondary}.openai.azure.com/openai'

// The following logic is used to determine the OpenAPI XML policy file to use based on the region type and retry policy setting.
var openApiXmlRetry = enableRetryPolicy
  ? loadTextContent('apim/apim_policies/aoai_retry_singleregion.xml')
  : loadTextContent('apim/apim_policies/aoai_singleregion.xml')
var openApiXml = azureOpenAiRegionType == 'Multi'
  ? loadTextContent('apim/apim_policies/aoai_retry_multiregion.xml')
  : openApiXmlRetry

var openApiJson = loadTextContent('./apim/api_definitions/AzureOpenAI_OpenAPI.json')

var apiNetwork = 'External'

var apiName = 'azure-openai-service-api'
var apiPath = 'openai'
var apiSubscriptionName = 'AzureOpenAI-Consumer-Chat'

var azureRoles = loadJsonContent('azure_roles.json')

resource eventHubNamespaceParent 'Microsoft.EventHub/namespaces@2024-01-01' existing = {
  name: eventHubNamespaceName
}

resource applicationInsightsParent 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

module apiManagement 'core/apim/api-management-private.bicep' = {
  name: 'api-management'
  params: {
    location: location
    zoneRedundant: zoneRedundant
    serviceName: apiManagementServiceName
    publisherName: apiManagementPublisherName
    publisherEmail: apiManagementPublisherEmail
    skuName: apiManagementSku
    skuCount: apiManagementSkuCount
    subnetResourceId: apiManagmentSubnetResourceId
    virtualNetworkType: apiNetwork
    aiName: applicationInsightsParent.properties.Name
    enableLoggers: enableLoggers
    publicIPName: apiNetwork == 'External' ? 'pip-${apiManagementServiceName}' : ''
    domainNameLabel: apiNetwork == 'External' ? apiManagementServiceName : ''
    linkPrivateEndpointToPrivateDns: linkPrivateEndpointToPrivateDns
    privateDnsZoneResourceGroup: privateDnsZonesResourceGroup
    tags: tags
  }
}

module corsFragment 'core/apim/cors-fragment.bicep' = {
  name: 'cors-fragment'
  params: {
    apimName: apiManagement.outputs.apiManagementServiceName
    allowedOrigins: allowedOrigins
  }
}

module rateFragment 'core/apim/rate-fragment.bicep' = {
  name: 'rate-fragment'
  params: {
    apimName: apiManagement.outputs.apiManagementServiceName
    rateLimitCalls: rateLimitCalls
    rateLimitPeriod: rateLimitPeriod
  }

  dependsOn: [
    corsFragment
  ]
}

module globalPolicy 'core/apim/policy.bicep' = {
  name: 'globalPolicy'
  params: {
    apimName: apiManagementServiceName
    policyValue: loadTextContent('apim/apim_policies/global.xml')
    policyFragmentIds: [
      corsFragment.outputs.corsFragmentName
    ]
  }

}

module openAiApi 'core/apim/openai-api.bicep' = if (enableAzureOpenAiSupport) {
  name: 'openAiApi'
  params: {
    apimName: apiManagementServiceName
    apiName: apiName
    apiPath: apiPath
    openApiJson: openApiJson
    openApiXml: openApiXml
    serviceUrlPrimary: apiServiceUrlPrimary
    serviceUrlSecondary: apiServiceUrlSecondary
    azureOpenAiRegionType: azureOpenAiRegionType
    apiSubscriptionName: apiSubscriptionName
    keyVaultName: keyVaultName
    policyFragmentIds: [
      rateFragment.outputs.rateFragmentName
    ]
  }
  dependsOn: [
    globalPolicy
  ]
}

module backendApi 'core/apim/api.bicep' = {
  name: 'backendApi'
  params: {
    apimName: apiManagementServiceName
    apiName: backendApiName
    apiPath: backendApiPath
    openApiJson: backendApiDefinitionJson
    openApiXml: backendApiPoliciesXml
    apiBackendName: 'api-backend'
    apiBackendUrl: backendApiUrl
    apiSubscriptionName: backendApiSubscriptionName
    apiSubscriptionRequired: backendApiSubscriptionRequired
    keyVaultName: keyVaultName
    policyFragmentIds: [
      rateFragment.outputs.rateFragmentName
    ]
  }
  dependsOn: [
    openAiApi
  ]
}

module diagnostic 'core/apim/diagnostics.bicep' = if (enableLoggers) {
  name: 'diagnostic'
  params: {
    apimName: apiManagementServiceName
    aiLoggerId: apiManagement.outputs.aiLoggerId
  }
  dependsOn: [
    backendApi
    openAiApi
  ]
}

resource monitoringMetricsPublisher 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (assignRbacRoles) {
  name: guid(subscription().id, resourceGroup().id, applicationInsightsName)
  scope: applicationInsightsParent
  properties: {
    principalId: apiManagement.outputs.apiManagementIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRoles.MonitoringMetricsPublisher)
  }
  dependsOn: [
    openAiApi
  ]
}

resource azureEventHubsDataSender 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (assignRbacRoles) {
  name: guid(subscription().id, resourceGroup().id, eventHubNamespaceName)
  scope: eventHubNamespaceParent
  properties: {
    principalId: apiManagement.outputs.apiManagementIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRoles.AzureEventHubsDataSender)
  }
  dependsOn: [
    openAiApi
  ]
}

module openAiUserPrimary 'core/apim/role.bicep' = if (assignRbacRoles && enableAzureOpenAiSupport) {
  name: '${apiManagementServiceName}-openAiUserPrimary'
  scope: resourceGroup(apiServiceRgPrimary)
  params: {
    roleName: guid(
      resourceGroup().id,
      apiManagement.outputs.apiManagementIdentityPrincipalId,
      azureRoles.CognitiveServicesOpenAIUser,
      apiServiceNamePrimary
    )
    principalId: apiManagement.outputs.apiManagementIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRoles.CognitiveServicesOpenAIUser)
  }
  dependsOn: [
    azureEventHubsDataSender
  ]
}

module openAiUserSecondary 'core/apim/role.bicep' = if (assignRbacRoles && enableAzureOpenAiSupport && azureOpenAiRegionType == 'Multi' && apiServiceRgPrimary != apiServiceRgSecondary) {
  name: '${apiManagementServiceName}-openAiUserSecondary'
  scope: resourceGroup(apiServiceRgSecondary)
  params: {
    roleName: guid(
      resourceGroup().id,
      apiManagement.outputs.apiManagementIdentityPrincipalId,
      azureRoles.CognitiveServicesOpenAIUser,
      apiServiceNameSecondary
    )
    principalId: apiManagement.outputs.apiManagementIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRoles.CognitiveServicesOpenAIUser)
  }
  dependsOn: [
    openAiUserPrimary
  ]
}

resource autoScaleRule 'Microsoft.Insights/autoscalesettings@2022-10-01' = if (autoScale) {
  name: '${apiManagementServiceName}-autoscale'
  location: location
  properties: {
    enabled: true
    targetResourceUri: apiManagement.outputs.apiManagementResourceId
    profiles: [
      {
        name: 'Auto created default scale condition'
        capacity: {
          default: string(apiManagementSkuCount)
          minimum: string(apiManagementSkuCount)
          maximum: string(apiManagementSkuCount + 1)
        }
        rules: [
          {
            scaleAction: {
              cooldown: 'PT5M'
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
            }
            metricTrigger: {
              metricName: 'Capacity'
              metricNamespace: 'microsoft.apimanagement/service'
              metricResourceUri: apiManagement.outputs.apiManagementResourceId
              operator: 'GreaterThan'
              statistic: 'Average'
              threshold: 70
              timeAggregation: 'Average'
              timeGrain: 'PT1M'
              timeWindow: 'PT10M'
              dividePerInstance: false
            }
          }
        ]
      }
    ]
  }
}

output apiManagementServiceName string = apiManagement.outputs.apiManagementServiceName
output apiManagementProxyHostName string = apiManagement.outputs.apiManagementProxyHostName
output apiManagementPortalHostName string = apiManagement.outputs.apiManagementDeveloperPortalHostName
output apiManagementGatewayUrl string = apiManagement.outputs.apiManagementGatewayUrl

output openAiApiSubscriptionSecretUri string = openAiApi.outputs.apiSubscriptionSecretUri
output backendApiSubscriptionSecretUri string = backendApi.outputs.apiSubscriptionSecretUri
