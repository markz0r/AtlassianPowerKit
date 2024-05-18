@{
    ModuleVersion        = '1.0.0.0'
    RootModule           = 'Strong-PasswordGenerator.psm1'
    CompatiblePSEditions = @('Core')
    Author               = 'Mark Culhane'
    Description          = 'A PowerShell module for generating strong passwords - copied directly from https://github.com/FranciscoNabas'
    FunctionsToExport    = 'New-StrongPassword'
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags = @('Password', 'Generator')
        }
    }
    RequiredModules      = @()
    RequiredAssemblies   = @()
    ScriptsToProcess     = @()
    ModuleList           = @()
    FileList             = @()
}