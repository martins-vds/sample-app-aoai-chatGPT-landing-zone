param apimName string
param allowedOrigins string[] = []

var corsFragmentTemplate = loadTextContent('../../apim/policy_fragments/cors.xml')
var allowedOriginsXml = empty(allowedOrigins)
  ? '<origin>*</origin>'
  : join(map(allowedOrigins, arg => '<origin>${arg}</origin>'), '\n')

var corsXml = replace(corsFragmentTemplate, '{{allowedOrigins}}', allowedOriginsXml)

module corsFragment 'policy-fragment.bicep' = {
  name: 'cors'
  params: {
    apimName: apimName
    fragmentName: 'cors'
    fragmentValue: corsXml
  }
}

output corsFragmentId string = corsFragment.outputs.policyFragmentId
output corsFragmentName string = corsFragment.outputs.policyFragmentName
