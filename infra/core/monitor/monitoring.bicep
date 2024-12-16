metadata description = 'Creates an Application Insights instance and a Log Analytics workspace.'
param logAnalyticsName string
param applicationInsightsName string
param applicationInsightsDashboardName string = ''
param privateLinkScopeName string
param privateEndpointSubnetId string
param linkPrivateEndpointToPrivateDns bool = true
param privateDnsZoneResourceGroup string
param location string = resourceGroup().location
param tags object = {}

module logAnalytics 'loganalytics.bicep' = {
  name: 'loganalytics'
  params: {
    name: logAnalyticsName
    location: location
    tags: tags
  }
}

module applicationInsights 'applicationinsights.bicep' = {
  name: 'applicationinsights'
  params: {
    name: applicationInsightsName
    location: location
    tags: tags
    dashboardName: applicationInsightsDashboardName
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

module privateLinkScope 'private-link-scope.bicep' = {
  name: privateLinkScopeName
  params: {
    location: location
    privateDnsZoneResourceGroup: privateDnsZoneResourceGroup 
    privateEndpointSubnetId: privateEndpointSubnetId
    privateLinkScopeName: privateLinkScopeName
    applicationInsightsId: applicationInsights.outputs.id
    linkPrivateEndpointToPrivateDns: linkPrivateEndpointToPrivateDns
    tags: tags
  }
}

output applicationInsightsConnectionString string = applicationInsights.outputs.connectionString
output applicationInsightsInstrumentationKey string = applicationInsights.outputs.instrumentationKey
output applicationInsightsName string = applicationInsights.outputs.name
output logAnalyticsWorkspaceId string = logAnalytics.outputs.id
output logAnalyticsWorkspaceName string = logAnalytics.outputs.name
