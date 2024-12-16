param apimName string

param rateLimitCalls int = 20
param rateLimitPeriod int = 60

var rateFragmentTemplate = loadTextContent('../../apim/policy_fragments/rate_throttle.xml')

var rateLimitXml = replace(
  replace(rateFragmentTemplate, '{{rateLimitCalls}}', string(rateLimitCalls)),
  '{{rateLimitPeriod}}',
  string(rateLimitPeriod)
)

module rateFragment 'policy-fragment.bicep' = {
  name: 'rate-throttle'
  params: {
    apimName: apimName
    fragmentName: 'rate-throttle'
    fragmentValue: rateLimitXml
  }
}

output rateFragmentId string = rateFragment.outputs.policyFragmentId
output rateFragmentName string = rateFragment.outputs.policyFragmentName
