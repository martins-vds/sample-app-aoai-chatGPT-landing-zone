param apimName string
param aiLoggerId string = ''

resource parentAPIM 'Microsoft.ApiManagement/service@2023-03-01-preview' existing = {
  name: apimName
}

resource diagnostic 'Microsoft.ApiManagement/service/diagnostics@2023-09-01-preview' = if (!empty(aiLoggerId)) {
  parent: parentAPIM
  name: 'applicationinsights'
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'Legacy'
    verbosity: 'information'
    logClientIp: true
    loggerId: aiLoggerId
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: {
        headers: []
        body: {
          bytes: 0
        }
      }
      response: {
        headers: []
        body: {
          bytes: 0
        }
      }
    }
    backend: {
      request: {
        headers: []
        body: {
          bytes: 0
        }
      }
      response: {
        headers: []
        body: {
          bytes: 0
        }
      }
    }
  }
}
