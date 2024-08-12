<#

.LINK
GitHub: https://github.com/markz0r/AtlassianPowerKit

#>
$ErrorActionPreference = 'Stop'; $DebugPreference = 'Continue'

# Function to get list of Orgs from Jira Cloud
function Get-AtlassianOrgs {
    $ORG_LIST = Invoke-RestMethod -Uri 'https://api.atlassian.com/admin/v1/orgs' -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get -ContentType 'application/json'
    $ORG_LIST | ConvertTo-Json -Depth 10
}

# Function to get Org history from Jira Cloud
function Export-OrgHistory {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ORG_ID
    )
    $ORG_HISTORY = Invoke-RestMethod -Uri "https://api.atlassian.com/admin/v1/orgs/$ORG_ID/events" -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get -ContentType 'application/json'
    $ORG_HISTORY | ConvertTo-Json -Depth 10
}
