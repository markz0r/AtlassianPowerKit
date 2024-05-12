@{
    ModuleVersion   = '1.0'
    RootModule      = '.\AtlassianCloud-PowerKit-Vault-Store-Implementation.dll'
    NestedModules   = @('.\TestVault.Extension')
    CmdletsToExport = @('Set-TestStoreConfiguration', 'Get-TestStoreConfiguration')
    PrivateData     = @{
        PSData = @{
            Tags = @('SecretManagement')
        }
    }
}