param apimName string
param apiName string
param apiPath string
param apiBackendUrl string
param apiBackendDescription string = 'Enter description here'
param apiSubscriptionName string
param apiSubscriptionRequired bool = true
param apiBackendName string
param openApiJson string
param openApiXml string
param keyVaultName string
param policyFragmentIds string[] = []

var policyFragmentsXml = join(
  map(policyFragmentIds, (fragmentId) => '<include-fragment fragment-id="${fragmentId}" />'),
  '\n'
)

var policyXml = replace(openApiXml, '{{policyFragments}}', policyFragmentsXml)

resource parentAPIM 'Microsoft.ApiManagement/service@2023-09-01-preview' existing = {
  name: apimName
}

resource primarybackend 'Microsoft.ApiManagement/service/backends@2023-09-01-preview' = {
  name: apiBackendName
  parent: parentAPIM
  properties: {
    description: apiBackendDescription
    protocol: 'http'
    url: apiBackendUrl
  }
}

resource api 'Microsoft.ApiManagement/service/apis@2023-09-01-preview' = {
  parent: parentAPIM
  name: apiName
  properties: {
    format: 'openapi+json'
    value: openApiJson
    path: apiPath
    protocols: [
      'https'
      'http'
    ]
    subscriptionRequired: apiSubscriptionRequired
    subscriptionKeyParameterNames: {
      header: 'api-key'
    }
  }
}

resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-09-01-preview' = {
  parent: api
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: policyXml
  }
}

resource apiSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-09-01-preview' = {
  name: apiSubscriptionName
  parent: parentAPIM
  properties: {
    allowTracing: false
    displayName: apiSubscriptionName
    scope: api.id
    state: 'active'
  }
}

module apiSubscriptionKey '../security/vault-secret.bicep' = {
  name: '${api.name}-subscription-secret'
  params: {
    keyVaultName: keyVaultName
    keyVaultSecretName: '${api.name}-subscription-key'
    keyVaultSecretValue: apiSubscription.listSecrets().primaryKey
  }
}

output apiSubscriptionSecretUri string = apiSubscriptionKey.outputs.secretUri
