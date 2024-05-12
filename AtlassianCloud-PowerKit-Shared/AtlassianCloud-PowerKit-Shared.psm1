<#
.SYNOPSIS
    Atlassian Cloud PowerShell Module - Shared - for shared functions to interact with Attlassian Cloud APIs.

.DESCRIPTION
    Atlassian Cloud PowerShell Module - Shared
    - Dependencies: None
    - Shared Module Functions
        - Get-AtlassianCloudAPIEndpoint
        - Get-OpsgenieAPIEndpoint
        - Clear-AtlassianCloudPowerKitGlobalVariables
    - To list all functions in this module, run: Get-Command -Module AtlassianCloud-PowerKit-Shared
    - Debug output is enabled by default. To disable, set $DisableDebug = $true before running functions.

.EXAMPLE
    Get-AtlassianCloudAPIEndpoint

    This example checks if the Jira Cloud API endpoint, username, and authentication token are defined, printing the values if they are, else advise to run Set-AtlassianCloudAPIEndpoint.

.EXAMPLE
    Get-OpsgenieAPIEndpoint

    This example checks if the Opsgenie API endpoint and authentication token are defined, printing the values if they are, else advise to run Set-OpsgenieAPIEndpoint.

.EXAMPLE
    Clear-AtlassianCloudPowerKitGlobalVariables

    This example clears all global variables where names start with 'PK_'.
    
.LINK
GitHub: https://github.com/markz0r/AtlassianCloud-PowerKit

#>
$ErrorActionPreference = 'Stop'; $DebugPreference = 'Continue'


# Function to check if the Jira Cloud API endpoint, username, and authentication token are defined, printing the values if they are, else advise to run Set-AtlassianCloudAPIEndpoint
function Get-AtlassianCloudAPIEndpoint {
    # Function to define the Jira Cloud API endpoint, username, and authentication token
    function Set-AtlassianCloudAPIEndpoint {
        param (
            [Parameter(Mandatory = $true)]
            [string]$AtlassianCloudAPIEndpoint
        )
        $global:PK_AtlassianCloudAPIEndpoint = $AtlassianCloudAPIEndpoint
        $AtlassianCloudAPICredential = Get-Credential

        $pair = "$($AtlassianCloudAPICredential.UserName):$($AtlassianCloudAPICredential.GetNetworkCredential().password)"
        $global:PK_AtlassianEncodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
        $global:PK_AtlassianDefaultAPIHeaders = @{
            Authorization = "Basic $global:PK_AtlassianEncodedCreds"
            Accept        = 'application/json'
        }
    }
    if ($global:PK_AtlassianCloudAPIEndpoint -and $global:PK_AtlassianEncodedCreds -and $global:PK_AtlassianDefaultAPIHeaders) {
        # Write-Debug '###############################################'
        # Write-Debug 'Endpoint already configured...'
        # Write-Debug "Jira Cloud API Endpoint: $global:PK_AtlassianCloudAPIEndpoint"
        # Write-Debug "Jira Cloud API Encoded Creds: $global:PK_AtlassianEncodedCreds"
        # Write-Debug '###############################################'
    }
    else {
        Write-Debug 'Jira Cloud API Endpoint and Credential not defined. Requesting...'
        Set-AtlassianCloudAPIEndpoint
    }
}

# Function to get Opsgenie endpoint
function Get-OpsgenieAPIEndpoint {
    function Set-OpsgenieAPIEndpoint {
        param (
            [Parameter(Mandatory = $false)]
            [string]$OpsgenieAPIEndpoint = 'api.opsgenie.com'
        )
        $global:PK_OpsgenieAPIEndpoint = $OpsgenieAPIEndpoint
        $OpsgenieAPICredential = Get-Credential

        $pair = "$($OpsgenieAPICredential.GetNetworkCredential().password)"
        $global:PK_OpsgenieEncodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
        $global:PK_OpsgenieDefaultAPIHeaders = @{
            Authorization = "Basic $global:OpsgenieEncodedCreds"
            Accept        = 'application/json'
        }
    }
    if ($global:PK_OpsgenieAPIEndpoint -and $global:OpsgenieEncodedCreds -and $global:OpsgenieDefaultAPIHeaders) {
        # Write-Debug '###############################################'
        # Write-Debug 'Endpoint already configured...'
        # Write-Debug "Jira Cloud API Endpoint: $global:PK_AtlassianCloudAPIEndpoint"
        # Write-Debug "Jira Cloud API Encoded Creds: $global:PK_AtlassianEncodedCreds"
        # Write-Debug '###############################################'
    }
    else {
        Write-Debug 'OpsGenie Cloud API Endpoint and Credential not defined. Requesting...'
        Set-OpsgenieAPIEndpoint
    }
}
# Function to list all global variables and values where names start with PK_
function Get-PowerKitVariables {
    Get-Variable -Name 'PK_*' | ForEach-Object {
        Write-Debug "$($_.Name): $($_.Value)"
    }
}

# Function to clear all global variables where names start with PK_
function Clear-PowerKitVariables {
    Get-PowerKitVariables
    # Ask for confirmation before clearing all global variables
    $ClearVariables = Read-Host 'Clear all global variables where names start with PK_? (Y/N)'
    if ($ClearVariables -eq 'Y') {
        Get-Variable -Name 'PK_*' | ForEach-Object {
            Remove-Variable -Name $_.Name -Scope Global
        }
    }
}
