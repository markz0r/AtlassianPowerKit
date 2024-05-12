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

    This example checks if the Jira Cloud API endpoint, username, and authentication token are defined, printing the values if they are, else advise to run New-AtlassianCloudAPIEndpoint.

.EXAMPLE
    Get-OpsgenieAPIEndpoint

    This example checks if the Opsgenie API endpoint and authentication token are defined, printing the values if they are, else advise to run New-OpsgenieAPIEndpoint.

.EXAMPLE
    Clear-AtlassianCloudPowerKitGlobalVariables

    This example clears all global variables where names start with 'PK_'.

.LINK
GitHub: https://github.com/markz0r/AtlassianCloud-PowerKit

#>
$ErrorActionPreference = 'Stop'; $DebugPreference = 'Continue'
$script:AtlassianCloudPowerKitVaultName = 'AtlassianCloudPowerKitProfileVault'
$script:AtlassianCloudProfiles = @()
$script:AtlassianCloudSelectedProfile = @{}
$script:AtlassianCloudAPIHeaders = @{}
$script:AtlassianCloudAPIEndpoint = ''
$script:OpsgenieAPIEndpoint = ''
$script:OpsgenieAPIHeaders = @{}

# Function to test if AtlassianCloudPowerKit profile authenticates successfully
function Test-AtlassianCloudPowerKitProfile {
    Write-Debug 'Testing Atlassian Cloud PowerKit Profile...'
    Write-Debug "Profile Data: $($script:AtlassianCloudSelectedProfile | Format-List * | Out-String)"
    Write-Debug "API Headers: $($script:AtlassianCloudAPIHeaders | Format-List * | Out-String)"
    Write-Debug "API Endpoint: $script:AtlassianCloudAPIEndpoint"
    try {
        $REST_RESULTS = Invoke-RestMethod -Uri "$script:AtlassianCloudAPIEndpoint/rest/api/2/myself" -Headers $script:AtlassianCloudAPIHeaders -Method Get
        #Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
    }
    catch {
        Write-Debug 'StatusCode:' $_.Exception.Response.StatusCode.value__
        Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
        throw 'Atlassian Cloud API Auth test failed.'
    }
    Write-Debug "Atlassian Cloud Auth test returned: $REST_RESULTS.displayName --- OK!"

    # Test Opsgenie API if profile uses Opsgenie API
    if ($script:AtlassianCloudSelectedProfile.UseOpsgenieAPI) {
        Write-Debug "Opsgenie API Headers: $($script:OpsgenieAPIHeaders | Format-List * | Out-String)"
        Write-Debug "Opsgenie API Endpoint: $script:OpsgenieAPIEndpoint"
        try {
            Invoke-RestMethod -Uri "$script:OpsgenieAPIEndpoint/v1/services?limit=1" -Headers $script:OpsgenieAPIHeaders -Method Get
            #Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
        }
        catch {
            Write-Debug 'StatusCode:' $_.Exception.Response.StatusCode.value__
            Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
            throw 'Opsgenie API Auth test failed.'
        }
        Write-Debug 'Opsgenie Auth test --- OK!'
    }
}

# Funtion to set the Opsgenie API endpoint and headers
function Set-OpsgenieAPIHeaders {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ProfileName
    )
    # check if there is a profile loaded
    if (!$script:AtlassianCloudSelectedProfile -or $script:AtlassianCloudSelectedProfile.Count -eq 0) {
        Write-Debug 'No profile loaded. Please load a profile first.'
        return $false
    }
    elseif (-not $script:AtlassianCloudSelectedProfile.UseOpsgenieAPI) {
        Write-Debug 'Profile does not use Opsgenie API. Please load a profile that uses Opsgenie API.'
        return $false
    }
    else {
        Write-Debug "Profile $ProfileName loaded. Setting Opsgenie API headers and OpsgenieAPIEndpoint..."
        $script:OpsgenieAPIHeaders = @{
            Authorization = "Basic $($script:AtlassianCloudSelectedProfile.OpsgenieAPIAuthString)"
            Accept        = 'application/json'
        }
        $script:OpsgenieAPIEndpoint = "https://$($script:AtlassianCloudSelectedProfile.OpsgenieAPIEndpoint)"

        Write-Debug "Opsgenie API Headers set: $($script:OpsgenieAPIHeaders | Format-List * | Out-String)"
        Write-Debug "Opsgenie API Endpoint set: $script:OpsgenieAPIEndpoint"
        Write-Debug "Profile $ProfileName loaded, testing."
        Test-AtlassianCloudPowerKitProfile
        Write-Debug "Profile $ProfileName loaded and tested successfully."
    }
}

# Function to set the Atlassian Cloud API headers
function Set-AtlassianCloudAPIHeaders {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ProfileName
    )
    # check if there is a profile loaded
    if (!$script:AtlassianCloudSelectedProfile -or $script:AtlassianCloudSelectedProfile.Count -eq 0) {
        Write-Debug 'No profile loaded. Please load a profile first.'
        return $false
    }
    else {
        Write-Debug "Profile $ProfileName loaded. Setting API headers and AtlassianCloudAPIEndpoint..."
        $script:AtlassianCloudAPIHeaders = @{
            Authorization = "Basic $($script:AtlassianCloudSelectedProfile.AtlassianCloudAPIAuthString)"
            Accept        = 'application/json'
        }
        $script:AtlassianCloudAPIEndpoint = "https://$($script:AtlassianCloudSelectedProfile.AtlassianCloudAPIEndpoint)"
        Write-Debug "API Headers set: $($script:AtlassianCloudAPIHeaders | Format-List * | Out-String)"
        Write-Debug "Atlassian Cloud API Endpoint set: $script:AtlassianCloudAPIEndpoint"
        Write-Debug "Profile $ProfileName loaded, testing."
        Test-AtlassianCloudPowerKitProfile
        Write-Debug "Profile $ProfileName loaded and tested successfully."
    }
}

function Set-AtlassianCloudPowerKitProfile {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ProfileName
    )
    # Load all profiles from the secret vault
    Get-AtlassianCloudPowerKitVault
    # Check if the profile exists
    if (!$script:AtlassianCloudProfiles.ContainsKey($ProfileName)) {
        Write-Debug "Profile $ProfileName does not exists in the vault - we have: $($script:AtlassianCloudProfiles.Keys)"
        return $false
    }
    else {
        Write-Debug "Profile $ProfileName exists in the vault, loading..."
        $script:AtlassianCloudSelectedProfile = Get-Secret -Name $ProfileName -Vault $script:AtlassianCloudPowerKitVaultName
        Set-AtlassianCloudAPIHeaders -ProfileName $ProfileName
        Write-Debug "Profile $ProfileName loaded successfully."
        Write-Debug "Profile Data: $($script:AtlassianCloudSelectedProfile | Format-List * | Out-String)"
    }
    return $true
}

# Function to load all AtlassianCloudPowerKit profiles from the secret vault
function Get-AtlassianCloudPowerKitProfileList {
    # Register the secret vault
    # Cheking if the vault is already registered
    if (-not (Get-SecretVault -Name $script:AtlassianCloudPowerKitVaultName -ErrorAction SilentlyContinue)) {
        Write-Debug "No vault found called $script:AtlassianCloudPowerKitVaultName... Registering..."
        Register-SecretVault -Name $script:AtlassianCloudPowerKitVaultName -ModuleName '.\AtlassianCloud-PowerKit-Shared\AtlassianCloud-PowerKit-Shared.psm1'
        Write-Debug "Registered vault $script:AtlassianCloudPowerKitVaultName successfully."
    }
    else {
        # If the vault is already registered, check if the vault is unlocked
        if (-not (Get-SecretVault -Name $script:AtlassianCloudPowerKitVaultName).IsUnlocked) {
            # If the vault is locked, unlock it
            Unlock-SecretVault -Name $script:AtlassianCloudPowerKitVaultName
        }
    }
    # for all profiles in the vault, load them into the AtlassianCloudProfiles variable
    $script:AtlassianCloudProfiles = $(Get-SecretInfo -Vault $script:AtlassianCloudPowerKitVaultName).Name
    return $script:AtlassianCloudProfiles
}

function Register-AtlassianCloudPowerKitProfile {
    param(
        [Parameter(Mandatory)]
        [string] $ProfileName,
        [Parameter(Mandatory)]
        [string] $AtlassianCloudAPIEndpoint,
        [Parameter(Mandatory)]
        [PSCredential] $AtlassianCloudAPICredential,
        [Parameter(Mandatory = $false)]
        [string] $OpsgenieAPIEndpoint = 'api.opsgenie.com',
        [Parameter(Mandatory = $false)]
        [switch] $UseOpsgenieAPI = $false,
        [Parameter(Mandatory = $false)]
        [PSCredential] $OpsgenieAPICredential
    )
    # Register the secret vault
    # Cheking if the vault is already registered
    $ProfileName = $ProfileName.Trim().ToLower()
    if (-not (Get-SecretVault -Name $script:AtlassianCloudPowerKitVaultName -ErrorAction SilentlyContinue)) {
        Write-Debug "No vault found called $script:AtlassianCloudPowerKitVaultName. Registering..."
        Register-SecretVault -Name $script:AtlassianCloudPowerKitVaultName -ModuleName 'AtlassianCloud-PowerKit-Shared' -VaultParameters @{}
        Write-Debug "Registered vault $script:AtlassianCloudPowerKitVaultName successfully."
    }
    Get-AtlassianCloudPowerKitVault # ensure vault unlocked and profile list loaded
    # Check if the profile already exists in the secret vault
    if ($script:AtlassianCloudProfiles.ContainsKey($ProfileName)) {
        Write-Debug "Profile $ProfileName already exists."
        # Create a hashtable of the profile data to store in the secret vault
        return $false
    }
    else {
        #Write-Debug "Profile $ProfileName does not exist. Creating..."
        $CredPair = "$($AtlassianCloudAPICredential.UserName):$($AtlassianCloudAPICredential.GetNetworkCredential().password)"
        $AtlassianCloudAPICredential = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($CredPair))
        $ProfileData = @{
            'PROFILE_NAME'                = $ProfileName
            'AtlassianCloudAPIEndpoint'   = $AtlassianCloudAPIEndpoint
            'AtlassianCloudAPIUserName'   = $AtlassianCloudAPICredential.UserName
            'AtlassianCloudAPIAuthString' = $AtlassianCloudAPICredential
        }
        if ($UseOpsgenieAPI) {
            $OpsgenieAPICredential = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($OpsgenieAPICredential.GetNetworkCredential().password))
            $ProfileData.Add('OpsgenieAPIEndpoint', $OpsgenieAPIEndpoint)
            $ProfileData.Add('OpsgenieAPIAuthString', $OpsgenieAPICredential)
            $ProfileData.Add('UseOpsgenieAPI', $UseOpsgenieAPI)
        }
        Set-Secret -Name $ProfileName -Secret $ProfileData -Vault $script:AtlassianCloudPowerKitVaultName
    }
    Write-Debug "Profile $ProfileName created successfully in $script:AtlassianCloudPowerKitVaultName."
}

function Reset-AtlassianCloudPowerKitProfile {
    $script:AtlassianCloudSelectedProfile = @{}
    $script:AtlassianCloudAPIHeaders = @{}
    $script:AtlassianCloudAPIEndpoint = ''
    $script:OpsgenieAPIEndpoint = ''
    Write-Debug 'Atlassian Cloud PowerKit profile unregistered.'
}

function Clear-AtlassianCloudPowerKitVault {
    Reset-SecretStore -Name $script:AtlassianCloudPowerKitVaultName
    Write-Debug "Vault $script:AtlassianCloudPowerKitVaultName cleared."
    Reset-AtlassianCloudPowerKitProfile
}

function Get-AtlassianCloudSelectedProfile {
    if ($script:AtlassianCloudSelectedProfile.Count -eq 0) {
        Write-Debug 'No profile loaded. Please load a profile first.'
        return $false
    }
    $LOADED_SCRIPT_VARS = $script:AtlassianCloudSelectedProfile
    if ($script:AtlassianCloudAPIEndpoint -and $script:AtlassianCloudAPIHeaders) {
        $LOADED_SCRIPT_VARS.Add('AtlassianCloudAPIEndpoint', $script:AtlassianCloudAPIEndpoint)
        $LOADED_SCRIPT_VARS.Add('AtlassianCloudAPIHeaders', $script:AtlassianCloudAPIHeaders)
    }
    if ($script:OpsgenieAPIEndpoint -and $script:OpsgenieAPIHeaders) {
        $LOADED_SCRIPT_VARS.Add('OpsgenieAPIEndpoint', $script:OpsgenieAPIEndpoint)
        $LOADED_SCRIPT_VARS.Add('OpsgenieAPIHeaders', $script:OpsgenieAPIHeaders)

    }
    return $LOADED_SCRIPT_VARS
}