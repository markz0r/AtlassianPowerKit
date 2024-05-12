function Get-Secret {
    [CmdletBinding()]
    param (
        [string] $Name,
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    return [TestStore]::GetItem($Name, $AdditionalParameters)
}

function Get-SecretInfo {
    [CmdletBinding()]
    param (
        [string] $Filter,
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    return @(, [Microsoft.PowerShell.SecretManagement.SecretInformation]::new(
            'Name', # Name of secret
            'String', # Secret data type [Microsoft.PowerShell.SecretManagement.SecretType]
            $VaultName, # Name of vault
            $Metadata))    # Optional Metadata parameter
}

function Set-Secret {
    [CmdletBinding()]
    param (
        [string] $Name,
        [object] $Secret,
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    [TestStore]::SetItem($Name, $Secret)
}

# Optional function
function Set-SecretInfo {
    [CmdletBinding()]
    param (
        [string] $Name,
        [hashtable] $Metadata,
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    [TestStore]::SetItemMetadata($Name, $Metadata)
}

function Remove-Secret {
    [CmdletBinding()]
    param (
        [string] $Name,
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    [TestStore]::RemoveItem($Name)
}

function Test-SecretVault {
    [CmdletBinding()]
    param (
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    return [TestStore]::TestVault()
}

# Optional function
function Unregister-SecretVault {
    [CmdletBinding()]
    param (
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    [TestStore]::RunUnregisterCleanup()
}

# Optional function
function Unlock-SecretVault {
    [CmdletBinding()]
    param (
        [SecureString] $Password,
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    [TestStore]::UnlockVault($Password)
}