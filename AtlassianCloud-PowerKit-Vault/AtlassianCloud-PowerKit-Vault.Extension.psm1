# AtlassianCloud-PowerKit-Shared.Extension.psm1
# Import the required module
Import-Module -Name Microsoft.PowerShell.SecretManagement
# function to register a secret vault

function Register-Vault {
    param(
        [Parameter(Mandatory)]
        [string] $VaultName
    )
    # Check if the vault is already registered
    if (-not (Get-SecretVault -Name $VaultName -ErrorAction SilentlyContinue)) {
        # Register the vault
        Register-SecretVault -Name $VaultName -ModuleName SecretManagement.LocalVault -DefaultVault
    }
}


function Test-SecretVault {
    param(
        [Parameter(Mandatory)]
        [string] $VaultName,

        [hashtable] $AdditionalParameters
    )

    # Use the Get-AtlassianCloudPowerKitProfile function to test the vault
    $result = Get-AtlassianCloudPowerKitProfile -ProfileName $VaultName

    # Return $true if the test is successful, $false otherwise
    return $null -ne $result
}

# Define a function to set a secret in a vault
function Set-Secret {
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [hashtable] $Secret,

        [Parameter(Mandatory)]
        [string] $VaultName
    )

    # Store the secret in the vault
    Microsoft.PowerShell.SecretManagement\Set-Secret -Name $Name -Secret $Secret -Vault $VaultName
}

function Get-Secret {
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $VaultName,

        [hashtable] $AdditionalParameters
    )

    # Use the Get-AtlassianCloudPowerKitProfile function to get a secret from the vault
    $result = Get-AtlassianCloudPowerKitProfile -ProfileName $Name

    # Return the secret as a PSCredential object
    return New-Object System.Management.Automation.PSCredential($result.Url, (ConvertTo-SecureString $result.Token -AsPlainText -Force))
}

function Remove-Secret {
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $VaultName,

        [hashtable] $AdditionalParameters
    )

    # Use the Remove-AtlassianCloudPowerKitProfile function to remove a secret from the vault
    Remove-AtlassianCloudPowerKitProfile -ProfileName $Name
}