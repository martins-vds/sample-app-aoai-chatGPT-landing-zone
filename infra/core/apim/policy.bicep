param apimName string

param policyValue string

param policyFragmentIds string[] = []

var policyFragmentsXml = join(
  map(policyFragmentIds, (fragmentId) => '<include-fragment fragment-id="${fragmentId}" />'),
  '\n'
)

var policyXml = replace(policyValue, '{{policyFragments}}', policyFragmentsXml)

resource parentAPIM 'Microsoft.ApiManagement/service@2023-03-01-preview' existing = {
  name: apimName
}

#disable-next-line BCP179
resource policy 'Microsoft.ApiManagement/service/policies@2023-09-01-preview' = {
  name: 'policy'
  parent: parentAPIM
  properties: {
    format: 'rawxml'
    value: policyXml
  }
}
