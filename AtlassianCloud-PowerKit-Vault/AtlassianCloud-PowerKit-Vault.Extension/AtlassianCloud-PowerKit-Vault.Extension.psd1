@{
    ModuleVersion      = '1.0'
    RootModule         = '.\AtlassianCloud-PowerKit-Vault.Extension.psm1'
    RequiredAssemblies = '..\TestStoreImplementation.dll'
    FunctionsToExport  = @('Set-Secret', 'Get-Secret', 'Remove-Secret', 'Get-SecretInfo', 'Test-SecretVault')
}