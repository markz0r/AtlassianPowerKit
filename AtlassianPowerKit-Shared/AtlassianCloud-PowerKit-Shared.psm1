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
    - To list all functions in this module, run: Get-Command -Module AtlassianPowerKit-Shared
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
GitHub: https://github.com/markz0r/AtlassianPowerKit

#>
$ErrorActionPreference = 'Stop'; $DebugPreference = 'Continue'
$script:VAULT_NAME = 'AtlassianCloudPowerKitProfileVault'
$script:VAULT_KEY_PATH = 'vault_key.xml'
$script:REGISTER_VAULT = $false
$script:PROFILE_LIST = @()
$script:LOADED_PROFILE = @{}

function Is-VaultUnlocked {
    param (
        [Parameter(Mandatory = $true)]
        [string]$VaultName
    )

    try {
        # Attempt to get a non-existent secret. If the vault is locked, this will throw an error.
        Get-Secret -Name 'NonExistentSecret' -Vault $VaultName -ErrorAction Stop > $null
    }
    catch {
        # If an error is thrown, the vault is locked.
        return $false
    }

    # If no error is thrown, the vault is unlocked.
    return $true
}

# Function to test if AtlassianCloudPowerKit profile authenticates successfully
function Test-AtlassianCloudPowerKitProfile {
    Write-Debug 'Testing Atlassian Cloud PowerKit Profile...'
    #Write-Debug "Profile Data: $($script:LOADED_PROFILE | Format-List * | Out-String)"
    #Write-Debug "API Headers: $($script:AtlassianCloudAPIHeaders | Format-List * | Out-String)"
    Write-Debug "API Endpoint: $($script:LOADED_PROFILE.AtlassianCloudAPIEndpoint)"
    try {
        $REST_RESULTS = Invoke-RestMethod -Uri "$($script:LOADED_PROFILE.AtlassianCloudAPIEndpoint)/rest/api/2/myself" -Headers $($script:LOADED_PROFILE.AtlassianCloudAPIHeaders) -Method Get
        #Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
    }
    catch {
        Write-Debug 'StatusCode:' $_.Exception.Response.StatusCode.value__
        Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
        throw 'Atlassian Cloud API Auth test failed.'
    }
    Write-Debug "Atlassian Cloud Auth test returned: $REST_RESULTS.displayName --- OK!"

    # Test Opsgenie API if profile uses Opsgenie API
    if ($script:LOADED_PROFILE.UseOpsgenieAPI) {
        try {
            Invoke-RestMethod -Uri "$($script:LOADED_PROFILE.OpsgenieAPIEndpoint)/v1/services?limit=1" -Headers $($script:LOADED_PROFILE.OpsgenieAPIHeaders) -Method Get
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
    # check if there is a profile loaded
    if (!$script:LOADED_PROFILE -or ($($script:LOADED_PROFILE).Count -eq 0)) {
        Write-Debug 'No profile loaded. Please load a profile first.'
        return $false
    }
    elseif (-not $script:LOADED_PROFILE.UseOpsgenieAPI) {
        Write-Debug 'Profile does not use Opsgenie API, setting defaults'
        $script:LOADED_PROFILE.OpsgenieAPIHeaders = @{
            Authorization = "Basic $($script:LOADED_PROFILE.AtlassianCloudAPIAuthString)"
            Accept        = 'application/json'
        }
    }
    else {
        $script:LOADED_PROFILE.OpsgenieAPIHeaders = @{
            Authorization = "Basic $($script:LOADED_PROFILE.OpsgenieAPIAuthString)"
            Accept        = 'application/json'
        }
    }
    $script:LOADED_PROFILE.OpsgenieAPIHeaders = 'https://api.opsgenie.com'
    Write-Debug "Opsgenie Profile Loaded for: $($script:LOADED_PROFILE.PROFILE_NAME)"
}

# Function to set the Atlassian Cloud API headers
function Set-AtlassianCloudAPIHeaders {
    # check if there is a profile loaded
    if (!$script:LOADED_PROFILE -or $script:LOADED_PROFILE.Count -eq 0) {
        Write-Debug 'No profile loaded. Please load a profile first.'
        return $false
    }
    else {
        Write-Debug "Profile $ProfileName loaded. Setting API headers and AtlassianCloudAPIEndpoint..."
        $AtlassianCloudAPIHeaders = @{
            Authorization = "Basic $($script:LOADED_PROFILE.AtlassianCloudAPIAuthString)"
            Accept        = 'application/json'
        }
        $script:LOADED_PROFILE.AtlassianCloudAPIHeaders = $AtlassianCloudAPIHeaders
        #Write-Debug "API Headers set: $($script:AtlassianCloudAPIHeaders | Format-List * | Out-String)"
        Test-AtlassianCloudPowerKitProfile
        Write-Debug "Atlassian headers set and tested successfully for $($script:LOADED_PROFILE.PROFILE_NAME)."
    }
}

function Set-AtlassianCloudPowerKitProfile {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ProfileName
    )
    Write-Debug "Set-AtlassianCloudPowerKitProfile - with: $ProfileName ..."
    # Load all profiles from the secret vault
    if (!$script:REGISTER_VAULT) {
        Register-AtlassianCloudPowerKitVault
    }
    # Check if the profile exists
    Get-AtlassianCloudPowerKitProfileList
    if (!$script:PROFILE_LIST.Contains($ProfileName)) {
        Write-Debug "Profile $ProfileName does not exists in the vault - we have: $script:PROFILE_LIST"
        return $false
    }
    else {
        Write-Debug "Profile $ProfileName exists in the vault, loading..."
        try {
            # if vault is locked, unlock it
            if (!(Is-VaultUnlocked -VaultName $script:VAULT_NAME)) {
                Write-Debug 'Vault is locked. Unlocking...'
                Unlock-Vault
            }
            $script:LOADED_PROFILE = (Get-Secret -Name $ProfileName -Vault $script:VAULT_NAME -AsPlainText)
        } 
        catch {
            Write-Debug "Failed to load profile $ProfileName. Please check the vault key file."
            throw "Failed to load profile $ProfileName. Please check the vault key file."
        }
        Set-AtlassianCloudAPIHeaders
        Set-OpsgenieAPIHeaders
        Write-Debug "Profile $ProfileName loaded successfully."
        #Write-Debug "Profile Data: $($script:LOADED_PROFILE | Format-List * | Out-String)"
    }
    return $true
}

function Unlock-Vault {
    Write-Debug "Checking if vault $script:VAULT_NAME is the default vault..."
    if ((Get-SecretVault | Where-Object IsDefault).Name -ne $script:VAULT_NAME) {
        Write-Debug "$script:VAULT_NAME is not the default vault. Setting as default..."
        Set-SecretVault -Name $script:VAULT_NAME -DefaultVault
    }
    Write-Debug "Unlocking vault $VaultName..."
    try {
        $vaultKey = Import-CliXml -Path $VaultKeyPath
        Unlock-SecretStore -Password $vaultKey
    }
    catch {
        Write-Debug "Failed to unlock vault $VaultName. Please check the vault key file."
        throw "Failed to unlock vault $VaultName. Please check the vault key file."
    }
    Write-Debug "Vault $VaultName unlocked successfully."
}

function Register-AtlassianCloudPowerKitVault {
    # Register the secret vault
    # Cheking if the vault is already registered
    if (-not (Test-Path $script:VAULT_KEY_PATH)) {
        Write-Debug 'No vault key file found. Creating...'
        $vaultKey = ConvertTo-SecureString -String $(New-StrongPassword 24 12) -AsPlainText -Force
        $vaultKey | Export-Clixml -Path $script:VAULT_KEY_PATH
        Write-Debug 'Vault key file created successfully.'
    }
    Write-Debug "Importing vault key from $script:VAULT_KEY_PATH..."
    $vaultKey = Import-CliXml -Path $script:VAULT_KEY_PATH
    Write-Debug 'Vault key imported successfully.'
    if (Get-SecretVault -Name $script:VAULT_NAME -ErrorAction SilentlyContinue) {
        Write-Debug "Vault $script:VAULT_NAME already exists."
    }
    else {
        Write-Debug "Registering vault $script:VAULT_NAME..."
        Register-SecretVault -Name $script:VAULT_NAME -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault -AllowClobber
        Write-Debug "Vault $script:VAULT_NAME registered successfully."
        Write-Debug "Checking if vault $script:VAULT_NAME is the default vault..."
        if ((Get-SecretVault | Where-Object IsDefault).Name -ne $script:VAULT_NAME) {
            Write-Debug "$script:VAULT_NAME is not the default vault. Setting as default..."
            Set-SecretVault -Name $script:VAULT_NAME -DefaultVault
        }
        Set-SecretStorePassword -NewPassword $vaultKey
        else {
            Write-Debug "$script:VAULT_NAME is the default vault."
        }
        Write-Debug "Configuring vault $script:VAULT_NAME..."
        # Check for vault password file $script:VAULT_KEY_PATH
        $storeConfiguration = @{
            Authentication  = 'Password'
            Password        = $vaultKey
            PasswordTimeout = 3600
            Interaction     = 'None'
            Confirm         = $false
        }
        Set-SecretStoreConfiguration @storeConfiguration
        Write-Debug "Vault $script:VAULT_NAME configured successfully."
        # if the vault is not the default vault, set it as default
    }
    Write-Debug "Unlocking vault $script:VAULT_NAME..."
    try {
        Unlock-SecretStore -Password $vaultKey
    }
    catch {
        Write-Debug "Failed to unlock vault $script:VAULT_NAME. Please check the vault key file."
        Write-Debug "De-registering vault $script:VAULT_NAME... and resetting vault key file."
        Unregister-SecretVault -Name $script:VAULT_NAME
        Remove-Item -Path $script:VAULT_KEY_PATH -Force
        Write-Debug "Vault $script:VAULT_NAME de-registered and vault key file removed, starting from scratch..."
        Register-AtlassianCloudPowerKitVault
    }
    Write-Debug "Vault $script:VAULT_NAME unlocked successfully."
    Write-Debug "Loading profiles from vault $script:VAULT_NAME..."
    $script:REGISTER_VAULT = $true
    [array]$script:PROFILE_LIST = (Get-SecretInfo -Vault $script:VAULT_NAME -Name '*').Name
    Write-Debug "Found profiles: $script:PROFILE_LIST"
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
    if (!$script:REGISTER_VAULT) {
        Register-AtlassianCloudPowerKitVault
    }
    # Check if the profile already exists in the secret vault
    if ($null -ne $script:PROFILE_LIST -and $script:PROFILE_LIST.Count -gt 0 -and $script:PROFILE_LIST.Contains($ProfileName)) {
        Write-Debug "Profile $ProfileName already exists."
        # Create a hashtable of the profile data to store in the secret vault
        return $false
    }
    else {
        #Write-Debug "Profile $ProfileName does not exist. Creating..."
        Write-Debug "Preparing profile data for $ProfileName..."
        $CredPair = "$($AtlassianCloudAPICredential.UserName):$($AtlassianCloudAPICredential.GetNetworkCredential().password)"
        Write-Debug "CredPair: $CredPair"
        $AtlassianCloudAPIAuthToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($CredPair))
        $ProfileData = @{
            'PROFILE_NAME'                = $ProfileName
            'AtlassianCloudAPIEndpoint'   = $AtlassianCloudAPIEndpoint
            'AtlassianCloudAPIUserName'   = $AtlassianCloudAPICredential.UserName
            'AtlassianCloudAPIAuthString' = $AtlassianCloudAPIAuthToken
            'OpsgenieAPIEndpoint'         = $OpsgenieAPIEndpoint
        }
        if ($UseOpsgenieAPI) {
            $OpsgenieAPICredential = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($OpsgenieAPICredential.GetNetworkCredential().password))
            $ProfileData.Add('OpsgenieAPIAuthString', $OpsgenieAPICredential)
            $ProfileData.Add('UseOpsgenieAPI', $UseOpsgenieAPI)
        }
        Write-Debug "Creating profile $ProfileName in $script:VAULT_NAME..."
        Set-Secret -Name $ProfileName -Secret $ProfileData -Vault $script:VAULT_NAME
    }
    Write-Debug "Profile $ProfileName created successfully in $script:VAULT_NAME."
    Write-Debug 'Clearing existing profiles selection...'
    Reset-AtlassianCloudPowerKitProfile
    Set-AtlassianCloudPowerKitProfile -ProfileName $ProfileName
}

function Reset-AtlassianCloudPowerKitProfile {
    $script:LOADED_PROFILE = @{}
    Write-Debug 'Atlassian Cloud PowerKit profile unregistered.'
}

function Clear-AtlassianCloudPowerKitVault {
    Reset-SecretStore -Name $script:VAULT_NAME
    Write-Debug "Vault $script:VAULT_NAME cleared."
    Reset-AtlassianCloudPowerKitProfile
}

function Get-LoadedProfile {
    if (($script:LOADED_PROFILE).Count -eq 0) {
        Write-Debug 'No profile loaded. Please load a profile first.'
        return $false
    }
    return $script:LOADED_PROFILE
}

function Get-AtlassianCloudPowerKitProfileList {
    if (!$script:REGISTER_VAULT) {
        Register-AtlassianCloudPowerKitVault
    }
    else {
        [array]$script:PROFILE_LIST = (Get-SecretInfo -Vault $script:VAULT_NAME -Name '*').Name
    }
    return [array]$script:PROFILE_LIST
}