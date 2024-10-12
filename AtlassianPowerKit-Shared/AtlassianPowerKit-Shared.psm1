<#
.SYNOPSIS
    Atlassian Cloud PowerShell Module - Shared - for shared functions to interact with Attlassian Cloud APIs.

.DESCRIPTION
    Atlassian Cloud PowerShell Module - Shared
    - Dependencies: None
    - Shared Module Functions
        - Get-AtlassianAPIEndpoint
        - Get-OpsgenieAPIEndpoint
        - Clear-AtlassianPowerKitGlobalVariables
    - To list all functions in this module, run: Get-Command -Module AtlassianPowerKit-Shared
    - Debug output is enabled by default. To disable, set $DisableDebug = $true before running functions.

.EXAMPLE
    Get-AtlassianAPIEndpoint

    This example checks if the Jira Cloud API endpoint, username, and authentication token are defined, printing the values if they are, else advise to run New-AtlassianAPIEndpoint.

.EXAMPLE
    Get-OpsgenieAPIEndpoint

    This example checks if the Opsgenie API endpoint and authentication token are defined, printing the values if they are, else advise to run New-OpsgenieAPIEndpoint.

.EXAMPLE
    Clear-AtlassianPowerKitGlobalVariables

    This example clears all global variables where names start with 'PK_'.

.LINK
GitHub: https://github.com/markz0r/AtlassianPowerKit

#>

# Vault path: $env:LOCALAPPDATA\Microsoft\PowerShell\secretmanagement\localstore\
$ErrorActionPreference = 'Stop'; $DebugPreference = 'Continue'
$script:VAULT_NAME = 'AtlassianPowerKitProfileVault'
$VAULT_KEY_PATH = 'vault_key.xml'

function Get-VaultKey {
    if (-not (Test-Path $VAULT_KEY_PATH)) {
        Write-Debug 'No vault key file found. Please register a vault first.'
        return $false
    }
    $VAULT_KEY = Import-CliXml -Path $VAULT_KEY_PATH
    return $VAULT_KEY
}

function Unlock-Vault {
    param (
        [Parameter(Mandatory = $true)]
        [string]$VaultName
    )
    try {
        if ((Get-SecretVault | Where-Object IsDefault).Name -ne $script:VAULT_NAME) {
            Write-Debug "$script:VAULT_NAME is not the default vault. Setting as default..."
            Set-SecretVaultDefault -Name $script:VAULT_NAME
        }
        # Attempt to get a non-existent secret. If the vault is locked, this will throw an error.
        $VAULT_KEY = Get-VaultKey
        Unlock-SecretStore -Password $VAULT_KEY
    }
    catch {
        # If an error is thrown, the vault is locked.
        write-debug "Unlock-Vault failed: $_ ..."
        throw 'Unlock-Vault failed Exiting'
    }
    # If no error is thrown, the vault is unlocked.
    Write-Debug 'Vault is unlocked.'
}

# Function to test if AtlassianPowerKit profile authenticates successfully
function Test-AtlassianPowerKitProfile {
    Write-Debug 'Testing Atlassian Cloud PowerKit Profile...'
    #Write-Debug "API Headers: $($script:AtlassianAPIHeaders | Format-List * | Out-String)"
    Write-Debug "API Endpoint: $($env:AtlassianPowerKit_AtlassianAPIEndpoint) ..."
    Write-Debug "API Headers: $($env:AtlassianPowerKit_AtlassianAPIHeaders) ..."
    $HEADERS = ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders
    $TEST_ENDPOINT = 'https://' + $env:AtlassianPowerKit_AtlassianAPIEndpoint + '/rest/api/2/myself'
    try {
        Write-Debug "Running: Invoke-RestMethod -Uri https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/2/myself -Headers $($env:AtlassianPowerKit_AtlassianAPIHeaders | ConvertFrom-Json -AsHashtable) -Method Get"
        Invoke-RestMethod -Method Get -Uri $TEST_ENDPOINT -Headers $HEADERS | Write-Debug
        #Write-Debug "Results: $($REST_RESULTS | ConvertTo-Json -Depth 10) ..."
        Write-Debug 'Donennnne'
    }
    catch {
        Write-Debug "Error: $_ ..."
        throw 'Atlassian Cloud API Auth test failed.'
    }
    Write-Debug "Atlassian Cloud Auth test returned: $($REST_RESULTS.displayName) --- OK!"

    # Test Opsgenie API if profile uses Opsgenie API
    if ($env:AtlassianPowerKit_UseOpsgenieAPI) {
        try {
            Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_OpsgenieAPIEndpoint)/v1/services?limit=1" -Headers $($env:AtlassianPowerKit_OpsgenieAPIHeaders | ConvertFrom-Json -AsHashtable) -Method Get
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
    if (!$env:AtlassianPowerKit_PROFILE_NAME) {
        Write-Debug 'No profile loaded. Please load a profile first.'
        return $false
    }
    elseif (-not $env:AtlassianPowerKit_UseOpsgenieAPI) {
        Write-Debug 'Profile does not use Opsgenie API, setting defaults'
        $HEADERS = @{
            Authorization = "Basic $($env:AtlassianPowerKit_AtlassianAPIAuthString)"
            Accept        = 'application/json'
        }
    }
    else {
        $HEADERS = @{
            Authorization = "Basic $($env:AtlassianPowerKit_OpsgenieAPIAuthString)"
            Accept        = 'application/json'
        }
    }
    $env:AtlassianPowerKit_OpsgenieAPIHeaders = $HEADERS | ConvertTo-Json
    Write-Debug "Opsgenie headers set for $($env:AtlassianPowerKit_PROFILE_NAME)."
    Write-Debug "Headers are: $($env:AtlassianPowerKit_OpsgenieAPIHeaders)"
    Write-Debug "Opsgenie Profile Loaded for: $($env:AtlassianPowerKit_PROFILE_NAME)"
}

# Function to set the Atlassian Cloud API headers
function Set-AtlassianAPIHeaders {
    # check if there is a profile loaded
    if (!$env:AtlassianPowerKit_PROFILE_NAME) {
        Write-Debug 'No profile loaded. Please load a profile first.'
        return $false
    }
    else {
        Write-Debug "Profile $ProfileName loaded. Setting API headers and AtlassianAPIEndpoint..."
        $HEADERS = @{
            Authorization = "Basic $($env:AtlassianPowerKit_AtlassianAPIAuthString)"
            Accept        = 'application/json'
        }
        # Add atlassian headers to the profile data
        $env:AtlassianPowerKit_AtlassianAPIHeaders = $HEADERS | ConvertTo-Json
        Write-Debug "Atlassian headers set for $($env:AtlassianPowerKit_PROFILE_NAME)."
        Write-Debug "Headers are: $($env:AtlassianPowerKit_AtlassianAPIHeaders)"
        Test-AtlassianPowerKitProfile
        Write-Debug "Atlassian headers set and tested successfully for $($env:AtlassianPowerKit_PROFILE_NAME)."
    }
}

# Function to update the vault with the new profile data
function Update-AtlassianPowerKitVault {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ProfileName,
        [Parameter(Mandatory = $true)]
        [hashtable]$ProfileData
    )
    Write-Debug "Writing profile data to vault for $ProfileName..."
    Unlock-Vault -VaultName $script:VAULT_NAME
    try {
        Set-Secret -Name $ProfileName -Secret $ProfileData -Vault $script:VAULT_NAME
    } 
    catch {
        Write-Debug "Update of vault failed for $ProfileName."
        throw "Update of vault failed for $ProfileName."
    }
    Write-Debug "Vault entruy for $ProfileName updated successfully."
}

function Set-AtlassianPowerKitProfile {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SelectedProfileName
    )
    Write-Debug "Set-AtlassianPowerKitProfile - with: $SelectedProfileName ..."
    # Load all profiles from the secret vault
    if (!$(Get-SecretVault -Name $script:VAULT_NAME -ErrorAction SilentlyContinue)) {
        Register-AtlassianPowerKitVault
    }
    # Check if the profile exists
    $PROFILE_LIST = Get-AtlassianPowerKitProfileList
    if (!$PROFILE_LIST.Contains($SelectedProfileName)) {
        Write-Debug "Profile $SelectedProfileName does not exists in the vault - we have: $PROFILE_LIST"
        return $false
    }
    else {
        Write-Debug "Profile $SelectedProfileName exists in the vault, loading..."
        try {
            # if vault is locked, unlock it
            Unlock-Vault -VaultName $script:VAULT_NAME
            $PROFILE_DATA = (Get-Secret -Name $SelectedProfileName -Vault $script:VAULT_NAME -AsPlainText)
            #Create environment variables for each item in the profile data
            $PROFILE_DATA.GetEnumerator() | ForEach-Object {
                Write-Debug "Setting environment variable: $($_.Key) = $($_.Value)"
                # Create environment variable concatenated with AtlassianPowerKit_ prefix
                $SetEnvar = '$env:AtlassianPowerKit_' + $_.Key + " = `"$($_.Value)`""
                Invoke-Expression -Command $SetEnvar
                Write-Debug "Environment variable set: $SetEnvar"
            }
        } 
        catch {
            Write-Debug "Failed to load profile $SelectedProfileName. Please check the vault key file."
            throw "Failed to load profile $SelectedProfileName. Please check the vault key file."
        }
        Set-AtlassianAPIHeaders
        #Set-OpsgenieAPIHeaders
        $env:AtlassianPowerKit_CloudID = $(Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/_edge/tenant_info").cloudId
        Write-Debug "Profile $SelectedProfileName loaded successfully."
    }
    return $SelectedProfileName
}

function Register-AtlassianPowerKitVault {
    # Register the secret vault
    # Cheking if the vault is already registered
    while (-not (Test-Path $VAULT_KEY_PATH)) {
        Write-Debug 'No vault key file found. Removing any existing vaults and re-creating...'
        Unregister-SecretVault -Name $script:VAULT_NAME -ErrorAction SilentlyContinue
        # Create a random secure key to use as the vault key as protected data
        $VAULT_KEY = $null
        while (-not $VAULT_KEY -or $VAULT_KEY.Length -lt 16) {
            $VAULT_KEY = Read-Host -Prompt 'Enter a at least 16 random characters to use as the vault key' -AsSecureString
            $VAULT_KEY | Export-Clixml -Path $VAULT_KEY_PATH
        }
        # Write the vault key to a temporary file
        Write-Debug 'Vault key file created successfully.'
    }
    if (Get-SecretVault -Name $script:VAULT_NAME -ErrorAction SilentlyContinue) {
        Write-Debug "Vault $script:VAULT_NAME already exists."
    }
    else {
        Write-Debug "Registering vault $script:VAULT_NAME..."
        $VAULT_KEY = Get-VaultKey
        $storeConfiguration = @{
            Authentication  = 'Password'
            Password        = $VAULT_KEY
            PasswordTimeout = 3600
            Interaction     = 'None'
        }
        Set-SecretVaultDefault -ClearDefault
        Reset-SecretStore @storeConfiguration -Force
        Register-SecretVault -Name $script:VAULT_NAME -ModuleName Microsoft.PowerShell.SecretStore -VaultParameters $storeConfiguration -DefaultVault -AllowClobber
        Write-Debug "Vault $script:VAULT_NAME registered successfully."
        Write-Debug "Checking if vault $script:VAULT_NAME is the default vault..."
        if ((Get-SecretVault | Where-Object IsDefault).Name -ne $script:VAULT_NAME) {
            Write-Debug "$script:VAULT_NAME is not the default vault. Setting as default..."
            Set-SecretVaultDefault -Name $script:VAULT_NAME
        }
        #Set-SecretStoreConfiguration @storeConfiguration
        #try {
        #    Set-SecretStorePassword -NewPassword $VAULT_KEY
        #} 
        # catch {
        #     Write-Debug "Failed to set SecretStorePassword for $script:VAULT_NAME. Please check the vault key file."
        #     throw "ERROR: Failed to set SecretStorePassword for $script:VAULT_NAME. Please run again, if error continues please raise an issue ..."
        # }
        Write-Debug "Vault $script:VAULT_NAME configured successfully."
    }
    # Unlock the vault if it is locked
    try {
        $VAULT_KEY = Get-VaultKey
        Unlock-Vault -VaultName $script:VAULT_NAME
    }
    catch {
        Write-Debug "Failed to unlock vault $script:VAULT_NAME. Please check the vault key file."
        Write-Debug "De-registering vault $script:VAULT_NAME... and resetting vault key file."
        Unregister-SecretVault -Name $script:VAULT_NAME
        Remove-Item -Path $VAULT_KEY_PATH -Force
        Write-Debug "Vault $script:VAULT_NAME de-registered and vault key file removed, starting from scratch..."
        throw "ERROR: Failed to unlock vault $script:VAULT_NAME. Please run again, if error continues please raise an issue ..."
    }
} 

function Register-AtlassianPowerKitProfile {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ProfileName,
        [Parameter(Mandatory = $true)]
        [string] $AtlassianAPIEndpoint,
        [Parameter(Mandatory = $true)]
        [PSCredential] $AtlassianAPICredential,
        [Parameter(Mandatory = $false)]
        [string] $OpsgenieAPIEndpoint = 'api.opsgenie.com',
        [Parameter(Mandatory = $false)]
        [switch] $UseOpsgenieAPI = $false,
        [Parameter(Mandatory = $false)]
        [PSCredential] $OpsgenieAPICredential
    )
    if (!$script:REGISTER_VAULT) {
        Register-AtlassianPowerKitVault
    }
    # Function to write profile data to the vault
    function Set-AtlassianPowerKitProfileData {
        param (
            [Parameter(Mandatory = $true)]
            [string] $ProfileName,
            [Parameter(Mandatory = $true)]
            [hashtable] $ProfileData
        )
        Write-Debug "Writing profile data to vault for $ProfileName..."
        Unlock-Vault -VaultName $script:VAULT_NAME
        try {
            Set-Secret -Name $ProfileName -Secret $ProfileData -Vault $script:VAULT_NAME
        } 
        catch {
            Write-Debug "Update of vault failed for $ProfileName."
            throw "Update of vault failed for $ProfileName."
        }
        Write-Debug "Vault entruy for $ProfileName updated successfully."
    }
    # Check if the profile already exists in the secret vault
    if ($null -ne $env:AtlassianPowerKit_PROFILE_LIST_STRING -and $env:AtlassianPowerKit_PROFILE_LIST_STRING.Count -gt 0 -and $env:AtlassianPowerKit_PROFILE_LIST_STRING.Contains($ProfileName)) {
        Write-Debug "Profile $ProfileName already exists."
        # Ask user if they want to overwrite the profile
        $overwrite = Read-Host -Prompt "Profile $ProfileName already exists. Do you want to overwrite it? (Y/N)"
        if ($overwrite -eq 'Y') {
            Write-Debug "Overwriting profile $ProfileName..."
        }
        else {
            Write-Debug "Profile $ProfileName already exists."
            return $false
        }
    }
    #Write-Debug "Profile $ProfileName does not exist. Creating..."
    Write-Debug "Preparing profile data for $ProfileName..."
    $CredPair = "$($AtlassianAPICredential.UserName):$($AtlassianAPICredential.GetNetworkCredential().password)"
    Write-Debug "CredPair: $CredPair"
    $AtlassianAPIAuthToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($CredPair))
    $ProfileData = @{
        'PROFILE_NAME'           = $ProfileName
        'AtlassianAPIEndpoint'   = $AtlassianAPIEndpoint
        'AtlassianAPIUserName'   = $AtlassianAPICredential.UserName
        'AtlassianAPIAuthString' = $AtlassianAPIAuthToken
    }
    Write-Debug "Creating profile $ProfileName in $script:VAULT_NAME..."
    Set-Secret -Name $ProfileName -Secret $ProfileData -Vault $script:VAULT_NAME
    Write-Debug "Profile $ProfileName created successfully in $script:VAULT_NAME."
    Write-Debug 'Clearing existing profiles selection...'
    Clear-AtlassianPowerKitProfile
    $LOADED_PROFILE = Set-AtlassianPowerKitProfile -SelectedProfileName $ProfileName
    return $LOADED_PROFILE
}

function Clear-AtlassianPowerKitProfile {
    # Clear all environment variables starting with AtlassianPowerKit_
    Get-ChildItem env:AtlassianPowerKit_* | ForEach-Object {
        Write-Debug "Removing environment variable: $_"
        Remove-Item "env:$($_.Name)" -ErrorAction Continue
    }
}

# Function to iterate through profile directories and clear contents by 
function Clear-AtlassianPowerKitProfileDirs {
    $PROFILE_DIRS = Get-AtlassianPowerKitProfileList | Get-Item
    $EXCLUDED_BACKUP_PATTERNS = @('*.zip')
    $EXCLUDED_DELETE_PATTERNS = @('*.zip', '*.md', '*.dotx', '*pdf', '*.doc', '*.docx', '*templates', '*ARCHIVE')
    # Get all subdirectories in the AtlassianPowerKit profile directory that dont match $EXCLUDED_FILENAME_PATTERNS
    foreach ($dir in $PROFILE_DIRS) {
        $ARCHIVE_NAME = "$($dir.BaseName)_ARCHIVE_$(Get-Date -Format 'yyyyMMdd').zip"
        $ARCHIVE_PATH = Join-Path -Path $dir.FullName -ChildPath $ARCHIVE_NAME

        # Collecting items excluding the patterns
        $itemsToArchive = Get-ChildItem -Path $dir.FullName -Recurse -File -Exclude $EXCLUDED_BACKUP_PATTERNS
        Write-Debug "Items to archive: $($itemsToArchive.FullName) ..."

        if ($itemsToArchive.Count -eq 0) {
            Write-Debug "Profile directory $dir. FullName has nothing to archive. Skipping..."
        }
        else {
            # Archiving items
            Compress-Archive -Path $itemsToArchive.FullName -DestinationPath $ARCHIVE_PATH -Force
            Write-Debug "Archiving $($dir.BaseName) to $ARCHIVE_NAME in $($dir.FullName)...."
            # Delete any directories with no files or subdirectories
            Get-ChildItem -Path $dir.FullName -Recurse -Directory | Where-Object { $_.GetFileSystemInfos().Count -eq 0 } | Remove-Item -Force
            # Write-Debug "Profile directory $dir.FullName cleared and archived to $ARCHIVE_NAME."
        }
        Get-ChildItem -Path $dir.FullName -Recurse -File -Exclude $EXCLUDED_DELETE_PATTERNS | Remove-Item -Force
        Get-ChildItem -Path $dir.FullName -Recurse -Directory -Exclude $EXCLUDED_DELETE_PATTERNS | Remove-Item -Force
    }
    # Optionally, clear the directory after archiving
    Write-Debug 'Profile directories cleared.'
}

function Clear-AtlassianPowerKitVault {
    Unregister-SecretVault -Name $script:VAULT_NAME
    Write-Debug "Vault $script:VAULT_NAME cleared."
    $VAULT_KEY = Get-VaultKey
    $storeConfiguration = @{
        Authentication  = 'Password'
        Password        = $VAULT_KEY
        PasswordTimeout = 3600
        Interaction     = 'None'
    }
    Reset-SecretStore @storeConfiguration -Force
    Clear-AtlassianPowerKitProfile
}

# Function to check if a profile is already loaded
function Get-CurrentAtlassianPowerKitProfile {
    if ($env:AtlassianPowerKit_PROFILE_NAME -and $env:AtlassianPowerKit_CloudID) {
        Write-Debug "Profile $($env:AtlassianPowerKit_PROFILE_NAME) appears loaded..."
        #Write-Debug "Profile $($env:AtlassianPowerKit_PROFILE_NAME) is loaded."
        return $env:AtlassianPowerKit_PROFILE_NAME
    }
    else {
        Write-Debug 'No profile loaded.'
        return $false
    }
}

function Get-AtlassianPowerKitProfileList {
    Write-Debug 'Getting AtlassianPowerKit Profile List...'
    if (!$(Get-SecretVault -Name $script:VAULT_NAME -ErrorAction SilentlyContinue)) {
        Register-AtlassianPowerKitVault
    }
    else {
        Write-Debug 'Vault already registered, getting profiles...'
        unlock-vault -VaultName $script:VAULT_NAME
        $PROFILE_LIST = (Get-SecretInfo -Vault $script:VAULT_NAME -Name '*').Name
        if ($PROFILE_LIST.Count -eq 0) {
            Write-Debug 'No profiles found. Please create a new profile.'
            return $false
        }
    }
    $env:AtlassianPowerKit_PROFILE_LIST_STRING = $PROFILE_LIST
    Write-Debug "Profiles found: $($env:AtlassianPowerKit_PROFILE_LIST_STRING)"
    return $PROFILE_LIST
}