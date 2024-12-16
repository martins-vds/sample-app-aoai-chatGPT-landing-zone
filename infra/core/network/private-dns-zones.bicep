param vnetId string
param tags object = {}

var zones = [
  'privatelink.adf.azure.com'
  'privatelink.afs.azure.net'
  'privatelink.agentsvc.azure-automation.net'
  'privatelink.analysis.windows.net'
  'privatelink.analytics.cosmos.azure.com'
  'privatelink.api.azureml.ms'
  'privatelink.attest.azure.net'
  'privatelink.azconfig.io'
  'privatelink.azure.com'
  'privatelink.azure-api.net'
  'privatelink.azure-automation.net'
  'privatelink.azurecr.io'
  'privatelink.azuredatabricks.net'
  'privatelink.azurehdinsight.net'
  'privatelink.azurestaticapps.net'
  'privatelink.azuresynapse.net'
  'privatelink.azurewebsites.net'  
  'privatelink.batch.azure.com'
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.cassandra.cosmos.azure.com'
  'privatelink.cognitiveservices.azure.com'
  'privatelink${environment().suffixes.sqlServerHostname}'
  'privatelink.datafactory.azure.net'
  'privatelink.dev.azuresynapse.net'
  'privatelink.dfs.${environment().suffixes.storage}'
  'privatelink.dicom.azurehealthcareapis.com'
  'privatelink.directline.botframework.com'
  'privatelink.documents.azure.com'
  'privatelink.eventgrid.azure.net'
  'privatelink.fhir.azurehealthcareapis.com'
  'privatelink.file.${environment().suffixes.storage}'
  'privatelink.grafana.azure.com'
  'privatelink.gremlin.cosmos.azure.com'
  'privatelink.managedhsm.azure.net'
  'privatelink.mariadb.database.azure.com'
  'privatelink.mongo.cosmos.azure.com'
  'privatelink.monitor.azure.com'
  'privatelink.mysql.database.azure.com'
  'privatelink.notebooks.azure.net'
  'privatelink.ods.opinsights.azure.com'
  'privatelink.oms.opinsights.azure.com'
  'privatelink.openai.azure.com'
  'privatelink.pbidedicated.windows.net'
  'privatelink.postgres.cosmos.azure.com'
  'privatelink.postgres.database.azure.com'
  'privatelink.prod.migration.windowsazure.com'
  'privatelink.purview.azure.com'
  'privatelink.purviewstudio.azure.com'
  'privatelink.queue.${environment().suffixes.storage}'
  'privatelink.redis.cache.windows.net'
  'privatelink.redisenterprise.cache.azure.net'
  'privatelink.search.windows.net'
  'privatelink.service.signalr.net'
  'privatelink.servicebus.windows.net'
  'privatelink.siterecovery.windowsazure.com'
  'privatelink.sql.azuresynapse.net'
  'privatelink.table.${environment().suffixes.storage}'
  'privatelink.table.cosmos.azure.com'
  'privatelink.tip1.powerquery.microsoft.com'
  'privatelink.token.botframework.com'
  'privatelink.ts.eventgrid.azure.net'
  'privatelink.vaultcore.azure.net'
  'privatelink.web.${environment().suffixes.storage}'
  'privatelink.workspace.azurehealthcareapis.com'
  'privatelink.wvd.microsoft.com'
  'privatelink-global.wvd.microsoft.com'
  'scm.privatelink.azurewebsites.net'
]

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = [
  for zone in zones: {
    name: zone
    location: 'global'
    tags: tags
    properties: {}
  }
]

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [
  for (zone, index) in zones: {
    parent: privateDnsZone[index]
    name: '${zone}-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnetId
      }
    }
  }
]
