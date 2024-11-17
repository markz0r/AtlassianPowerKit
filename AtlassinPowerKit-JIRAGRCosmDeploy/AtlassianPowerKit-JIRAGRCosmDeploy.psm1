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
