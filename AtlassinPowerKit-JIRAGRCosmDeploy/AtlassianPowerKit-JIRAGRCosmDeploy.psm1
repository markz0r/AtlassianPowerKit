<#
.SYNOPSIS
    Atlassian Cloud PowerShell Module - AtlassianPowerKit-JIRAGRCosmDeploy - module for creating new issue types, workflows, fields, screens, screen schemes, issue type screen schemes, and issue type screen scheme associations using the Atlassian Jira Cloud REST API.See https://developer.atlassian.com/cloud/jira/platform/rest/v3/ for more information.

.DESCRIPTION
    Atlassian Cloud PowerShell Module - AtlassianPowerKit-JIRAGRCosmDeploy
    - Dependencies: AtlassianPowerKit-Shared
        - New-AtlassianAPIEndpoint
    For list of functions and cmdlets, run Get-Command -Module AtlassianPowerKit-JIRAGRCosmDeploy.psm1

.EXAMPLE
    New-JiraIssueType -JiraCloudProjectKey 'OSM' -JiraIssueTypeName 'Test Issue Type' -JiraIssueTypeDescription 'This is a test issue type.' -JiraIssueTypeAvatarId '10000'

.LINK
GitHub: https://github.com/OrganisationServiceManagement/AtlassianPowerKit.git

#>

$ErrorActionPreference = 'Stop'; $DebugPreference = 'Continue'

# Listing issue Types
function Get-MarkDownJIRAIssueTypes {
    param (
        [P ]
        [Parameter(Mandatory = $false)]
        [string]$OUTPUT_PATH = "$($env:OSM_HOME)\$($env:AtlassianPowerKit_PROFILE_NAME)\JIRA"
    )
}

Get-Content .\cpk-HROSM-IssueTypes-20241117-145239.json | ConvertFrom-Json -Depth 100 | ForEach-Object { Write-Host "- [$($_.Name)]($($_.self)) - [Show All Instances](https://cpksystems.atlassian.net/jira/servicedesk/projects/HROSM/issues/?jql=project%20%3D%20HROSM%20AND%20issuetype%20%3D%20%22$($_.name.replace(' ','%20'))%22)" 
