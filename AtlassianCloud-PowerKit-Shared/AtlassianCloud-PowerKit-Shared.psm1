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
$script:vaultKeyPath = 'vault_key.xml'
$script:vaultRegistered = $false
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
    Write-Debug "Set-AtlassianCloudPowerKitProfile - with: $ProfileName ..."
    # Load all profiles from the secret vault
    if (!$script:vaultRegistered) {
        Register-AtlassianCloudPowerKitVault
    }
    # Check if the profile exists
    Get-AtlassianCloudPowerKitProfileList
    if (!$script:AtlassianCloudProfiles.Contains($ProfileName)) {
        Write-Debug "Profile $ProfileName does not exists in the vault - we have: $script:AtlassianCloudProfiles"
        return $false
    }
    else {
        Write-Debug "Profile $ProfileName exists in the vault, loading..."
        try {
            Unlock-Vault
            $script:AtlassianCloudSelectedProfile = (Get-Secret -Name $ProfileName -Vault $script:AtlassianCloudPowerKitVaultName -AsPlainText)
        } 
        catch {
            Write-Debug "Failed to load profile $ProfileName. Please check the vault key file."
            throw "Failed to load profile $ProfileName. Please check the vault key file."
        }
        Set-AtlassianCloudAPIHeaders -ProfileName $ProfileName
        Write-Debug "Profile $ProfileName loaded successfully."
        Write-Debug "Profile Data: $($script:AtlassianCloudSelectedProfile | Format-List * | Out-String)"
    }
    return $true
}

function Unlock-Vault {
    Write-Debug "Checking if vault $script:AtlassianCloudPowerKitVaultName is the default vault..."
    if ((Get-SecretVault | Where-Object IsDefault).Name -ne $script:AtlassianCloudPowerKitVaultName) {
        Write-Debug "$script:AtlassianCloudPowerKitVaultName is not the default vault. Setting as default..."
        Set-SecretVault -Name $script:AtlassianCloudPowerKitVaultName -DefaultVault
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
    if (-not (Test-Path $script:vaultKeyPath)) {
        Write-Debug 'No vault key file found. Creating...'
        $vaultKey = ConvertTo-SecureString -String $(New-StrongPassword 24 12) -AsPlainText -Force
        $vaultKey | Export-Clixml -Path $script:vaultKeyPath
        Write-Debug 'Vault key file created successfully.'
    }
    Write-Debug "Importing vault key from $script:vaultKeyPath..."
    $vaultKey = Import-CliXml -Path $script:vaultKeyPath
    Write-Debug 'Vault key imported successfully.'
    if (Get-SecretVault -Name $script:AtlassianCloudPowerKitVaultName -ErrorAction SilentlyContinue) {
        Write-Debug "Vault $script:AtlassianCloudPowerKitVaultName already exists."
    }
    else {
        Write-Debug "Registering vault $script:AtlassianCloudPowerKitVaultName..."
        Register-SecretVault -Name $script:AtlassianCloudPowerKitVaultName -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault -AllowClobber
        Write-Debug "Vault $script:AtlassianCloudPowerKitVaultName registered successfully."
        Write-Debug "Checking if vault $script:AtlassianCloudPowerKitVaultName is the default vault..."
        if ((Get-SecretVault | Where-Object IsDefault).Name -ne $script:AtlassianCloudPowerKitVaultName) {
            Write-Debug "$script:AtlassianCloudPowerKitVaultName is not the default vault. Setting as default..."
            Set-SecretVault -Name $script:AtlassianCloudPowerKitVaultName -DefaultVault
        }
        Set-SecretStorePassword -NewPassword $vaultKey
        else {
            Write-Debug "$script:AtlassianCloudPowerKitVaultName is the default vault."
        }
        Write-Debug "Configuring vault $script:AtlassianCloudPowerKitVaultName..."
        # Check for vault password file $script:vaultKeyPath
        $storeConfiguration = @{
            Authentication  = 'Password'
            Password        = $vaultKey
            PasswordTimeout = 3600
            Interaction     = 'None'
            Confirm         = $false
        }
        Set-SecretStoreConfiguration @storeConfiguration
        Write-Debug "Vault $script:AtlassianCloudPowerKitVaultName configured successfully."
        # if the vault is not the default vault, set it as default
    }
    Write-Debug "Unlocking vault $script:AtlassianCloudPowerKitVaultName..."
    try {
        Unlock-SecretStore -Password $vaultKey
    }
    catch {
        Write-Debug "Failed to unlock vault $script:AtlassianCloudPowerKitVaultName. Please check the vault key file."
        Write-Debug "De-registering vault $script:AtlassianCloudPowerKitVaultName... and resetting vault key file."
        Unregister-SecretVault -Name $script:AtlassianCloudPowerKitVaultName
        Remove-Item -Path $script:vaultKeyPath -Force
        Write-Debug "Vault $script:AtlassianCloudPowerKitVaultName de-registered and vault key file removed, starting from scratch..."
        Register-AtlassianCloudPowerKitVault
    }
    Write-Debug "Vault $script:AtlassianCloudPowerKitVaultName unlocked successfully."
    Write-Debug "Loading profiles from vault $script:AtlassianCloudPowerKitVaultName..."
    $script:vaultRegistered = $true
    [array]$script:AtlassianCloudProfiles = (Get-SecretInfo -Vault $script:AtlassianCloudPowerKitVaultName -Name '*').Name
    Write-Debug "Found profiles: $script:AtlassianCloudProfiles"
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
    if (!$script:vaultRegistered) {
        Register-AtlassianCloudPowerKitVault
    }
    # Check if the profile already exists in the secret vault
    if ($null -ne $script:AtlassianCloudProfiles -and $script:AtlassianCloudProfiles.Count -gt 0 -and $script:AtlassianCloudProfiles.Contains($ProfileName)) {
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
            
        }
        if ($UseOpsgenieAPI) {
            $OpsgenieAPICredential = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($OpsgenieAPICredential.GetNetworkCredential().password))
            $ProfileData.Add('OpsgenieAPIEndpoint', $OpsgenieAPIEndpoint)
            $ProfileData.Add('OpsgenieAPIAuthString', $OpsgenieAPICredential)
            $ProfileData.Add('UseOpsgenieAPI', $UseOpsgenieAPI)
        }
        Write-Debug "Creating profile $ProfileName in $script:AtlassianCloudPowerKitVaultName..."
        Write-Debug "Priflie Data: $($ProfileData | Format-List * | Out-String)"
        Set-Secret -Name $ProfileName -Secret $ProfileData -Vault $script:AtlassianCloudPowerKitVaultName
    }
    Write-Debug "Profile $ProfileName created successfully in $script:AtlassianCloudPowerKitVaultName."
    Write-Debug 'Clearing existing profiles selection...'
    Reset-AtlassianCloudPowerKitProfile
    Set-AtlassianCloudPowerKitProfile -ProfileName $ProfileName
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
    return $script:AtlassianCloudSelectedProfile
}

function Get-AtlassianCloudAPIHeaders {
    if ($script:AtlassianCloudAPIHeaders.Count -eq 0) {
        Write-Debug 'No API headers set. Please load a profile first.'
        return $false
    }
    return $script:AtlassianCloudAPIHeaders
}
function Get-OpsgenieAPIHeaders {
    if ($script:OpsgenieAPIHeaders.Count -eq 0) {
        Write-Debug 'No Opsgenie API headers set.'
        return $false
    }
    return $script:OpsgenieAPIHeaders
}

function Get-AtlassianCloudPowerKitProfileList {
    if (!$script:vaultRegistered) {
        Register-AtlassianCloudPowerKitVault
    }
    else {
        [array]$script:AtlassianCloudProfiles = (Get-SecretInfo -Vault $script:AtlassianCloudPowerKitVaultName -Name '*').Name
    }
    return [array]$script:AtlassianCloudProfiles
}