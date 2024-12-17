[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[^/]+/.*$', ErrorMessage = "Repository must be in the format 'owner/repo'")]
    [string]
    $Repository,
    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Environment,
    [Parameter(Mandatory = $true, Position = 2)]
    [ValidateNotNullOrEmpty()]
    [string]
    $VariablesJson,
    [Parameter(Mandatory = $true, Position = 3)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Token
)

$ErrorActionPreference = 'Stop'

function createOrUpdateEnvironmentVariable($repo, $environment, $variable, $token) {
    $headers = @{
        Accept                 = "application/vnd.github+json"
        Authorization          = "Bearer $token"
        "Content-Type"         = "application/json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }

    $variablesApi = "https://api.github.com/repos/$repo/environments/$environment/variables"

    try {
        Write-Host "Creating variable '$($variable.name)' in environment '$environment'..."

        Invoke-RestMethod -Method Post -Uri $variablesApi -Headers $headers -Body $(ConvertTo-Json $variable) | Out-Null
        
        Write-Host "Variable $($variable.name) created"
    }
    catch [Microsoft.PowerShell.Commands.HttpResponseException] {
        if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::Conflict -or $_.ErrorDetails.Message -notlike "*variable already exists*") {
            throw
        }
        
        Invoke-RestMethod -Method Patch -Uri "$variablesApi/$($variable.name)" -Headers $headers -Body $(ConvertTo-Json $variable) | Out-Null
        Write-Host "Variable $($variable.name) updated"
    }
}

$variables = ConvertFrom-Json $VariablesJson -Depth 10 -NoEnumerate -AsHashtable

$variables | ForEach-Object {
    $variable = [hashtable]$_

    if ($variable.ContainsKey("name") -eq $false -or $variable["name"] -eq $null) {
        throw "Variable name is required."
    }

    $newVariable = @{
        name  = $variable.name
        value = $variable.value ?? ""
    }

    try {
        createOrUpdateEnvironmentVariable -repo $Repository -environment $Environment -variable $newVariable -token $Token
    }
    catch {
        Write-Host "Failed to create or update variable $($variable.name). Reason: $($_.Exception.Message)"
    }
}

Write-Host "Done."