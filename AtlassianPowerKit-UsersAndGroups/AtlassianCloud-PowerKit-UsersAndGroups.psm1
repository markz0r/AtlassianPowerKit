<#
.SYNOPSIS
    Atlassian Cloud PowerShell Module - Users and Groups - for handy functions to interact with Attlassian Cloud APIs.

.DESCRIPTION
    Atlassian Cloud PowerShell Module - Users and Groups
    - Dependencies: AtlassianPowerKit-Shared
        - New-AtlassianCloudAPIEndpoint
    - Users and Groups Module Functions
        - Get-AtlassianGroupMembers
        - Get-AtlassianCloudUser
        - Show-JiraCloudJSMProjectRole
    - To list all functions in this module, run: Get-Command -Module AtlassianPowerKit-UsersAndGroups
    - Debug output is enabled by default. To disable, set $DisableDebug = $true before running functions.

.EXAMPLE
    Get-AtlassianGroupMembers -GROUP_NAME 'jira-administrators'

    This example gets all members of the 'jira-administrators' group.

.EXAMPLE
    Get-AtlassianCloudUser -ACCOUNT_ID '5f7b7f7d7f7f7f7f7f7f7f7f7'

    This example gets the user details for the account ID '5f7b7f7d7f7f7f7f7f7f7f7f7'.

.EXAMPLE
    Show-JiraCloudJSMProjectRole -JiraCloudJSMProjectKey 'OSM'

    This example gets all roles for the Jira Service Management (JSM) project with the key 'OSM'.


.LINK
GitHub: https://github.com/markz0r/AtlassianPowerKit

#>
$ErrorActionPreference = 'Stop'; $DebugPreference = 'Continue'
$script:LOADED_PROFILE = @{}

# Function to list all Atlassian Groups and their members
function Get-AtlassianGroups {
    $script:LOADED_PROFILE = Get-LoadedProfile
    $GROUPS_ENDPOINT = "https://$($script:LOADED_PROFILE.AtlassianCloudAPIEndpoint)/rest/api/2/groups/picker"
    $GROUP_ENDPOINT_HEADERS = $script:AtlassianCloudAPIHeaders.'maxResults' = 100
    Write-Debug "Groups Endpoint: $GROUPS_ENDPOINT"
    Write-Debug "Headers: $GROUP_ENDPOINT_HEADERS"
    try {
        $REST_RESULTS = Invoke-RestMethod -Uri $GROUPS_ENDPOINT -Headers $GROUP_ENDPOINT_HEADERS -Method Get -ContentType 'application/json'
        #Write-Debug $REST_RESULTS.getType()
        Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
    }
    catch {
        Write-Debug 'StatusCode:' $_.Exception.Response.StatusCode.value__
        Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
    }
    return $REST_RESULTS
}

# Get all users in a Group
function Get-AtlassianGroupMembers {
    param (
        [Parameter(Mandatory = $true)]
        [string]$GROUP_NAME
    )
    $GROUP_NAME_ENCODED = [System.Web.HttpUtility]::UrlEncode($GROUP_NAME)
    Write-Debug "Group Name: $GROUP_NAME"
    Write-Debug "Group Name Encoded: $GROUP_NAME_ENCODED"
    $GROUP_MEMBERS_ENDPOINT = "https://$script:ATLASSIAN_CLOUD_API_ENDPOINT/rest/api/3/group/member?groupname=$GROUP_NAME_ENCODED"
    try {
        $REST_RESULTS = Invoke-RestMethod -Uri $GROUP_MEMBERS_ENDPOINT -Headers $script:AtlassianCloudAPIHeaders -Method Get -ContentType 'application/json'
        #Write-Debug $REST_RESULTS.getType()
        Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
    }
    catch {
        Write-Debug 'StatusCode:' $_.Exception.Response.StatusCode.value__
        Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
    }
}

# Function get user details and create json object for that user in the Jira Cloud API using the accountID
function Get-AtlassianCloudUser {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ACCOUNT_ID
    )
    $ACCOUNT_ID_ENCODED = [System.Web.HttpUtility]::UrlEncode($ACCOUNT_ID)
    Write-Debug "Account ID: $ACCOUNT_ID"
    Write-Debug "Account ID Encoded: $ACCOUNT_ID_ENCODED"
    $USER_ENDPOINT = "https://$script:ATLASSIAN_CLOUD_API_ENDPOINT/rest/api/3/user?accountId=$ACCOUNT_ID_ENCODED"
    try {
        $REST_RESULTS = Invoke-RestMethod -Uri $USER_ENDPOINT -Headers $script:AtlassianCloudAPIHeaders -Method Get -ContentType 'application/json'
        Write-Debug $REST_RESULTS.getType()
        Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
    }
    catch {
        Write-Debug 'StatusCode:' $_.Exception.Response.StatusCode.value__
        Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
    }
}

# Function to list all roles for a JSM cloud project
function Show-JiraCloudJSMProjectRole {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JiraCloudJSMProjectKey
    )
    $JiraProjectRoles = Invoke-RestMethod -Uri "https://$script:ATLASSIAN_CLOUD_API_ENDPOINT/rest/api/3/project/$JiraCloudJSMProjectKey/role" -Headers $script:AtlassianCloudAPIHeaders -Method Get
    Write-Debug $JiraProjectRoles.getType()
    $JiraProjectRoles | Get-Member -MemberType Properties | ForEach-Object {
        Write-Debug "$($_.Name) - $($_.Definition) - ID: $($_.Definition.split('/')[-1])"
    }
}