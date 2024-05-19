<#
.SYNOPSIS
    Atlassian Cloud PowerShell Module - Users and Groups - for handy functions to interact with Attlassian Cloud APIs.

.DESCRIPTION
    Atlassian Cloud PowerShell Module - Users and Groups
    - Dependencies: AtlassianPowerKit-Shared
        - New-AtlassianAPIEndpoint
    - Users and Groups Module Functions
        - Get-AtlassianGroupMembers
        - Get-AtlassianUser
        - Show-JiraCloudJSMProjectRole
    - To list all functions in this module, run: Get-Command -Module AtlassianPowerKit-UsersAndGroups
    - Debug output is enabled by default. To disable, set $DisableDebug = $true before running functions.

.EXAMPLE
    Get-AtlassianGroupMembers -GROUP_NAME 'jira-administrators'

    This example gets all members of the 'jira-administrators' group.

.EXAMPLE
    Get-AtlassianUser -ACCOUNT_ID '5f7b7f7d7f7f7f7f7f7f7f7f7'

    This example gets the user details for the account ID '5f7b7f7d7f7f7f7f7f7f7f7f7'.

.EXAMPLE
    Show-JiraCloudJSMProjectRole -JiraCloudJSMProjectKey 'OSM'

    This example gets all roles for the Jira Service Management (JSM) project with the key 'OSM'.


.LINK
GitHub: https://github.com/markz0r/AtlassianPowerKit

#>
$ErrorActionPreference = 'Stop'; $DebugPreference = 'Continue'
$script:LOADED_PROFILE = @{}

# Function that takes a hashtable of groupnames and groupids and prints all members of each group
function Get-AtlassianGroupMembersBulk {
    $MEMBERS_LIST = @{}
    $GROUPS = Get-AtlassianGroups
    $GROUPS.GetEnumerator() | ForEach-Object {
        # Check if the group has members
        $MEMBER_ENTRY_ARRAY = Get-AtlassianGroupMembers -GROUP_NAME $_.Key
        if ((!$MEMBER_ENTRY_ARRAY) -or $MEMBER_ENTRY_ARRAY.Count -eq 0) {
            Write-Host "No members found in group $($_.Key)"
        }
        else {
            Write-Debug "MEMBER_ENTRY_ARRAY TYPE = $($MEMBER_ENTRY_ARRAY.getType()), COUNT = $($MEMBER_ENTRY_ARRAY.Count)"
            $MEMBERS_LIST.add($_.Key, $MEMBER_ENTRY_ARRAY)
        }
    }
    # Write GROUP_ARRAY to in format that can be used in a report
    $MEMBERS_LIST | ForEach-Object {
        $_ | Format-Table -AutoSize
    }
    # Write $MEMBERS_LIST to a file as CSV with groupname as Row header and members below
    $EXPORT_DATE = Get-Date -Format 'yyyy-MM-dd-HHmmss'
    $EXPORT_FILE = "AtlassianGroupMembers-$($env:AtlassianPowerKit_PROFILE_NAME)-$EXPORT_DATE.csv"
    $MEMBERS_LIST.GetEnumerator() | ForEach-Object {
        $GROUP_NAME = $_.Key
        $GROUP_MEMBERS = $_.Value
        # Create a CSV file with the group name as the header and the members below, with each member on a new line
        $CSV_COLUMNS = 'Group Name', 'Member Name', 'Member Account ID', 'Member Email Address'
        $CSV_ARRAY = @()
        $GROUP_MEMBERS | ForEach-Object {
            $CSV_ARRAY += [PSCustomObject]@{
                'Group Name'           = $GROUP_NAME
                'Member Name'          = $_.displayName
                'Member Account ID'    = $_.accountId
                'Member Email Address' = $_.emailAddress
            }
        }
        $CSV_ARRAY | Export-Csv -Path $EXPORT_FILE -NoTypeInformation -Append
    }
}

# Function to list all Atlassian Groups and their members
function Get-AtlassianGroups {
    $GROUPS_ENDPOINT = "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/2/groups/picker?maxResults=100"
    $GROUP_ENDPOINT_HEADERS = ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders
    Write-Debug "Groups Endpoint: $GROUPS_ENDPOINT"
    Write-Debug "Headers: $GROUP_ENDPOINT_HEADERS"
    try {
        $REST_RESULTS = Invoke-RestMethod -Uri $GROUPS_ENDPOINT -Headers $GROUP_ENDPOINT_HEADERS -Method Get -ContentType 'application/json'
        #Write-Debug $REST_RESULTS.getType()
    }
    catch {
        Write-Debug 'StatusCode:' $_.Exception.Response.StatusCode.value__
        Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
    }
    # Create a Hashtable of groups.name and groups.groupdud
    $GROUPS = @{}
    $REST_RESULTS.groups | ForEach-Object {
        $GROUPS[$_.name] = $_.groupid
    }
    return $GROUPS
}

# Get all users in a Group
function Get-AtlassianGroupMembers {
    param (
        [Parameter(Mandatory = $true)]
        [string]$GROUP_NAME
    )
    $GROUP_NAME_ENCODED = [System.Web.HttpUtility]::UrlEncode($GROUP_NAME)
    $HEADERS = ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders
    Write-Debug "Group Name: $GROUP_NAME"
    Write-Debug "Group Name Encoded: $GROUP_NAME_ENCODED"
    $GROUP_MEMBERS_ENDPOINT = "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/3/group/member?groupname=$GROUP_NAME_ENCODED&includeInactiveUsers=false&maxResults=100"
    Write-Debug "Group Members Endpoint: $GROUP_MEMBERS_ENDPOINT"
    try {
        $REST_RESULTS = Invoke-RestMethod -Uri $GROUP_MEMBERS_ENDPOINT -Headers $HEADERS -Method Get -ContentType 'application/json'
    }
    catch {
        # If rate limiting,  sleep for 20 seconds then retry
        if ($_.Exception.Response.StatusCode.value__ -eq 429) {
            Write-Host 'Rate limited. Sleeping for 20 seconds then retrying.'
            Start-Sleep -Seconds 20
            $REST_RESULTS = Invoke-RestMethod -Uri $GROUP_MEMBERS_ENDPOINT -Headers $HEADERS -Method Get -ContentType 'application/json'
        }
        Write-Debug 'Invoke-RestMethod Errored'
        Throw $_
    }
    # Get values.displayName, values.accountId, values.emailAddress from REST_RESULTS
    # Build an array of hashtables with the values
    $MEMBERS_HASH = @()
    # Build an array of hashtables with the values, handle null values and no members
    if ($REST_RESULTS.total -eq 0) {
        Write-Host "No members found in group $GROUP_NAME"
    }
    else {
        # Build an array of hashtables with the values handle null values
        $REST_RESULTS.values | ForEach-Object {
            $MEMBER_HASH = @{
                'displayName'  = $_.displayName
                'accountId'    = $_.accountId
                'emailAddress' = $_.emailAddress
            }
            $MEMBERS_HASH += $MEMBER_HASH
        }
    }
    Write-Debug $MEMBERS_HASH.getType()
    Write-Debug (ConvertTo-Json $MEMBERS_HASH -Depth 10)
    return $MEMBERS_HASH
}

# Function get user details and create json object for that user in the Jira Cloud API using the accountID
function Get-AtlassianUser {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ACCOUNT_ID
    )
    $ACCOUNT_ID_ENCODED = [System.Web.HttpUtility]::UrlEncode($ACCOUNT_ID)
    Write-Debug "Account ID: $ACCOUNT_ID"
    Write-Debug "Account ID Encoded: $ACCOUNT_ID_ENCODED"
    $USER_ENDPOINT = "https://$script:ATLASSIAN_CLOUD_API_ENDPOINT/rest/api/3/user?accountId=$ACCOUNT_ID_ENCODED"
    try {
        $REST_RESULTS = Invoke-RestMethod -Uri $USER_ENDPOINT -Headers $script:AtlassianAPIHeaders -Method Get -ContentType 'application/json'
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
    $JiraProjectRoles = Invoke-RestMethod -Uri "https://$script:ATLASSIAN_CLOUD_API_ENDPOINT/rest/api/3/project/$JiraCloudJSMProjectKey/role" -Headers $script:AtlassianAPIHeaders -Method Get
    Write-Debug $JiraProjectRoles.getType()
    $JiraProjectRoles | Get-Member -MemberType Properties | ForEach-Object {
        Write-Debug "$($_.Name) - $($_.Definition) - ID: $($_.Definition.split('/')[-1])"
    }
}