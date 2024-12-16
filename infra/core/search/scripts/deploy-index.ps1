$ErrorActionPreference = "Stop"

function Ensure_Variables {
    if (-not $env:INDEX_NAME) {
        Write-Host "INDEX_NAME is not set"
        exit 1
    }

    if (-not $env:RESOURCE_GROUP) {
        Write-Host "RESOURCE_GROUP is not set"
        exit 1
    }

    if (-not $env:SEARCH_SERVICE_NAME) {
        Write-Host "SEARCH_SERVICE_NAME is not set"
        exit 1
    }

    if (-not $env:SEARCH_SERVICE_ENDPOINT) {
        Write-Host "SEARCH_SERVICE_ENDPOINT is not set"
        exit 1
    }

    if (-not $env:SEMANTIC_CONFIGURATION_NAME) {
        Write-Host "SEMANTIC_CONFIGURATION_NAME is not set"
        exit 1
    }

    if (-not $env:VECTOR_PROFILE_NAME) {
        Write-Host "VECTOR_PROFILE_NAME is not set"
        exit 1
    }

    if (-not $env:VECTOR_ALGORITHM_NAME) {
        Write-Host "VECTOR_ALGORITHM_NAME is not set"
        exit 1
    }
}

Ensure_Variables

# Constants
$SEARCH_SERVICE_APIVERSION = "2024-05-01-preview"

Write-Host "Updating index file with environment variables..."

$baseIndex = Get-Content -Path "$PSScriptRoot/../config/base-index.json" -Raw

$updatedIndex = $baseIndex -replace "__INDEX_NAME__", $env:INDEX_NAME `
    -replace "__SEMANTIC_CONFIGURATION_NAME__", $env:SEMANTIC_CONFIGURATION_NAME `
    -replace "__VECTOR_PROFILE_NAME__", $env:VECTOR_PROFILE_NAME `
    -replace "__VECTOR_ALGORITHM_NAME__", $env:VECTOR_ALGORITHM_NAME

Write-Host "Authenticating to $env:SEARCH_SERVICE_ENDPOINT..."

$adminKey = Get-AzSearchAdminKeyPair -ResourceGroupName $env:RESOURCE_GROUP -ServiceName $env:SEARCH_SERVICE_NAME | Select-Object -ExpandProperty Primary

Write-Host "Admin key: $($adminKey.Substring(0, 5))...$($adminKey.Substring($adminKey.Length - 5, 5))"

Write-Host "Creating index $env:INDEX_NAME in $env:SEARCH_SERVICE_ENDPOINT using api verion $SEARCH_SERVICE_APIVERSION..."

# Json string with header
$headers = @{
    "Content-Type"  = "application/json"
    "api-key"       = $adminKey
    "cache-control" = "no-cache"
}

try {
    Invoke-RestMethod -Method Put `
        -Uri "$($env:SEARCH_SERVICE_ENDPOINT)/indexes/$($env:INDEX_NAME)?api-version=$SEARCH_SERVICE_APIVERSION" `
        -Headers $headers `
        -Body $updatedIndex | Out-Null
    Write-Host "Done."
}
catch {
    Write-Host "Failed to create index $env:INDEX_NAME in $env:SEARCH_SERVICE_ENDPOINT."
    Write-Host $_.Exception.Message
    Write-Host $_.Exception.InnerException.Message
    throw    
}