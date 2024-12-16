param apimName string

param fragmentName string
param fragmentValue string
param fragmentNamedValues namedValue[] = []

type namedValue = {
  name: string
  value: string
}

resource parentAPIM 'Microsoft.ApiManagement/service@2023-09-01-preview' existing = {
  name: apimName
}

@batchSize(1)
resource namedValueResources 'Microsoft.ApiManagement/service/namedValues@2023-09-01-preview' = [
  for namedValue in fragmentNamedValues: {
    name: namedValue.name
    parent: parentAPIM
    properties: {
      displayName: namedValue.name
      value: namedValue.value
    }
  }
]

resource policyFragment 'Microsoft.ApiManagement/service/policyFragments@2023-09-01-preview' = {
  parent: parentAPIM
  name: fragmentName
  properties: {
    format: 'rawxml'
    value: fragmentValue
  }

  dependsOn: [
    namedValueResources
  ]
}

output policyFragmentId string = policyFragment.id
output policyFragmentName string = policyFragment.name
