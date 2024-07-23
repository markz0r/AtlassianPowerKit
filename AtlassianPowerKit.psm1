<#
.SYNOPSIS
    Atlassian Cloud PowerKit module for interacting with Atlassian Cloud REST API.
.DESCRIPTION
    Atlassian Cloud PowerKit module for interacting with Atlassian Cloud REST API.
    - Dependencies: AtlassianPowerKit-Shared
    - Functions:
      - Use-AtlassianPowerKit: Interactive function to run any function in the module.
    - Debug output is enabled by default. To disable, set $DisableDebug = $true before running functions.
.EXAMPLE
    Use-AtlassianPowerKit
    This example lists all functions in the AtlassianPowerKit module.
.EXAMPLE
    Use-AtlassianPowerKit
    Simply run the function to see a list of all functions in the module and nested modules.
.EXAMPLE
    Get-DefinedPowerKitVariables
    This example lists all variables defined in the AtlassianPowerKit module.
.LINK
    GitHub:

#>
$ErrorActionPreference = 'Stop'; $DebugPreference = 'Continue'
Set-Location $PSScriptRoot
$script:AtlassianPowerKitRequiredModules = @('PowerShellGet', 'Microsoft.PowerShell.SecretManagement', 'Microsoft.PowerShell.SecretStore')
$script:LOCAL_MODULES = $(Get-ChildItem -Path . -Recurse -Depth 1 -Include *.psd1 -Exclude 'AtlassianPowerKit.psd1', 'AtlassianPowerKit-Shared.psd1', 'Naive-ConflunceStorageValidator.psd1')

function Get-RequisitePowerKitModules {
    $script:AtlassianPowerKitRequiredModules | ForEach-Object {
        # Import or install the required module
        try {
            if (-not (Get-Module -Name $_ -ListAvailable)) {
                Write-Debug "Module $_ not found. Installing..."
                Install-Module -Name $_ -Force -Scope CurrentUser
            }            
        }
        catch {
            Write-Error "Module $_ not found and installation failed. Exiting."
            throw "Dependency module $_ unanable to install, try manual install, Exiting for now."
        }
        finally {
            Import-Module -Name $_ -Force
        }
    }
    # Find list of module in subdirectories and import them
    Import-Module .\AtlassianPowerKit-Shared\AtlassianPowerKit-Shared.psd1 -Force
    Get-Module -Name AtlassianPowerKit*
    $script:LOCAL_MODULES | ForEach-Object {
        Write-Debug "Importing nested module: .\$($_.BaseName)\$($_.Name)"
        Import-Module $_.FullName -Force
        # Validate the module is imported
        if (-not (Get-Module -Name $_.BaseName)) {
            Write-Error "Module $($_.BaseName) not found. Exiting."
            throw "Nested module $($_.BaseName) not found. Exiting."
        }
    }
}
# Function display console interface to run any function in the module
function Show-AtlassianPowerKitFunctions {
    # List nested modules and their exported functions to the console in a readable format, grouped by module
    $colors = @('Green', 'Cyan', 'Red', 'Magenta', 'Yellow')
    $localModules = $script:LOCAL_MODULES | ForEach-Object {
        Write-Debug "Local module: $($_.Name -replace '.psd1', '')"
        $module = Get-Module -Name $($_.Name -replace '.psd1', '')
        $module
    }
    Write-Debug "Nested modules: $localModules"

    $colorIndex = 0
    $functionReferences = @{}
    $functionReferences[0] = 'Return'
    $localModules | ForEach-Object {
        # Select a color from the list
        $color = $colors[$colorIndex % $colors.Count]
        $spaces = ' ' * (51 - $_.Name.Length)
        Write-Host '' -BackgroundColor Black
        Write-Host "Module: $($_.Name)" -BackgroundColor $color -ForegroundColor White -NoNewline
        Write-Host $spaces  -BackgroundColor $color -NoNewline
        Write-Host ' ' -BackgroundColor Black
        $spaces = ' ' * 40
        Write-Host " Exported Commands:$spaces" -BackgroundColor "Dark$color" -ForegroundColor White -NoNewline
        Write-Host ' ' -BackgroundColor Black
        $_.ExportedCommands.Keys | ForEach-Object {
            $colorIndex++
            # Assign a letter reference to the function
            # $functRefNum = $colorIndex + 1
            $functRefNum = $colorIndex
            $functionReferences[$functRefNum] = $_
            Write-Host ' ' -NoNewline -BackgroundColor "Dark$color"
            Write-Host '   ' -NoNewline -BackgroundColor Black
            Write-Host "$functRefNum -> " -NoNewline -BackgroundColor Black
            Write-Host "$_" -NoNewline -BackgroundColor Black -ForegroundColor $color
            # Calculate the number of spaces needed to fill the rest of the line
            $spaces = ' ' * (50 - ($_.Length + ($functRefNum.ToString().Length)))
            Write-Host $spaces -NoNewline -BackgroundColor Black
            Write-Host ' ' -NoNewline -BackgroundColor "Dark$color"
            Write-Host ' ' -BackgroundColor Black
            # Increment the color index for the next function
        }
        $spaces = ' ' * 59
        Write-Host $spaces -BackgroundColor "Dark$color" -NoNewline
        Write-Host ' ' -BackgroundColor Black
    }

    # Write separator for readability
    Write-Host "`n" -BackgroundColor Black
    Write-Host '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++' -BackgroundColor Black -ForegroundColor DarkGray
    # Ask the user which function they want to run
    # if the user hits enter, exit the function
    # Attempt to convert the input string to a char
    try {
        $selectedFunction = Read-Host -Prompt "`nSelect a function by number or name to run (or hit enter to exit)"
        if ($selectedFunction -match '^\d+$') {
            $selectedFunction = [int]$selectedFunction
        }
        else {
            $selectedFunction = $functionReferences.Keys | Where-Object { $functionReferences[$_] -eq $selectedFunction }
        }
    }
    catch {
        return $null
    }
    # if selected function is Return, exit the function
    if (!$selectedFunction -or ($selectedFunction -eq 0)) {
        return $null
    } 
    else {
        # Run the selected function timing the execution
        Write-Host "`n"
        Write-Host "You selected:  $($functionReferences.$selectedFunction)" -ForegroundColor Green
        try {     
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            Invoke-Expression ($functionReferences.$selectedFunction)
            $stopwatch.Stop()
        }
        catch {
            # Write all output including errors to the console from the selected function
            Write-Host $_.Exception.Message -ForegroundColor Red
            throw "Error running function: $functionReferences[$selectedFunction] failed. Exiting."
        }
        Write-Host "`nFunction $($functionReferences.$selectedFunction) completed - execution time: $($stopwatch.Elapsed.TotalSeconds) seconds" -ForegroundColor Green
        # Ask the user if they want to run another function
        Write-Host "`n"
        try {
            $runAnother = Read-Host 'Run another function? (Y / Return to exit)'
            if (($runAnother) -and ($runAnother -eq 'Y')) {
                Show-AtlassianPowerKitFunctions
            }
        }
        catch {
            return $null
        }
    }
}

# Function to create a new profile
function New-AtlassianPowerKitProfile {
    # Ask user to enter the profile name
    $ProfileName = Read-Host 'Enter a profile name:'
    $ProfileName = $ProfileName.ToLower().Trim()
    if (!$ProfileName -or $ProfileName -eq '' -or $ProfileName.Length -gt 100) {
        Write-Error 'Profile name cannot be empty, or more than 100 characters, Please try again.'
        # Load the selected profile or create a new profile
        Write-Debug "Profile name entered: $ProfileName"
        Throw 'Profile name cannot be empty, taken or mor than 100 characters, Please try again.'
    }
    else {
        try {
            Register-AtlassianPowerKitProfile($ProfileName)       
        }
        catch {
            Write-Debug "Error: $($_.Exception.Message)"
            throw "Register-AtlassianPowerKitProfile $ProfileName failed. Exiting."
        }
    }
}

# Function to list availble profiles with number references for interactive selection or 'N' to create a new profile
function Show-AtlassianPowerKitProfileList {
    $profileIndex = 0
    if (!$env:AtlassianPowerKit_PROFILE_LIST) {
        Write-Host 'No profiles found. Please create a new profile.'
        New-AtlassianPowerKitProfile
        Write-Debug "Profile List: $(Get-AtlassianPowerKitProfileList)"
        Show-AtlassianPowerKitProfileList
    } 
    else {
        Write-Debug "Profile list: $env:AtlassianPowerKit_PROFILE_LIST"
        $PROFILE_LIST = $env:AtlassianPowerKit_PROFILE_LIST.split()
        Write-Debug "Profile list array $PROFILE_LIST"
        $PROFILE_LIST | ForEach-Object {
            Write-Host "[$profileIndex] $_"
            $profileIndex++
        }
    }   
    Write-Host '[N] Create a new profile'
    Write-Host '[R] Reset vault and profiles - Deletes all profiles and vault data'
    Write-Host '[Q / Return] Quit'
    Write-Host '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++' -ForegroundColor DarkGray
    try {
        # read input from the user and just break with no error if the input is not a number, 'N', 'R' or 'Q'
        $selectedProfile = Read-Host 'Select a profile number or action'
    }
    catch {
        return $null
    }
    if ((!$selectedProfile) -or ($selectedProfile -eq 'Q')) {
        return $null
    }
    elseif ($selectedProfile -eq 'N') {
        New-AtlassianPowerKitProfile
    } 
    elseif ($selectedProfile -eq 'R') {
        Clear-AtlassianPowerKitVault
    }
    else {
        $selectedProfile = [int]$selectedProfile
        Write-Debug "Selected profile index: $selectedProfile"
        Write-Debug "Selected profile name: $($PROFILE_LIST[$selectedProfile])"
        return "$($PROFILE_LIST[$selectedProfile])"
    }
}

function Use-AtlassianPowerKit {
    param (
        [Parameter(Mandatory = $false)]
        [string] $ProfileName,
        [Parameter(Mandatory = $false)]
        [switch] $ArchiveProfileDirs,
        [Parameter(Mandatory = $false)]
        [switch] $ResetVault
    )
    Get-RequisitePowerKitModules
    if ($ResetVault) {
        Clear-AtlassianPowerKitVault
        return $null
    }
    if ($ArchiveProfileDirs) {
        Clear-AtlassianPowerKitProfileDirs
        return $null
    }
    $env:AtlassianPowerKit_PROFILE_NAME = $null
    #Write-Debug "Profile List: $(Get-AtlassianPowerKitProfileList)"
    if (!$ProfileName) {
        if (!$FunctionName) {
            Write-Host 'No profile name provided. Check the profiles available.'
            try {
                $ProfileName = Show-AtlassianPowerKitProfileList
                Set-AtlassianPowerKitProfile $ProfileName
            }
            catch {
                Write-Host 'No profile selected. Exiting...'
                return $null
            }
        }
        else {
            Write-Debug "Example: Use-AtlassianPowerKit -ProfileName 'profileName' -FunctionName 'functionName'"
            Write-Error 'No -ProfileName provided with FunctionName, Exiting...'
        }
    } 
    else {
        try {
            $ProfileName = $ProfileName.Trim().ToLower()
            Write-Debug "Setting provided profile: $ProfileName"
            Set-AtlassianPowerKitProfile $ProfileName
            if (!$env:AtlassianPowerKit_PROFILE_NAME -or ($env:AtlassianPowerKit_PROFILE_NAME -ne $ProfileName)) {
                Throw 'Profile not loaded! Exiting...'
            }
        }
        catch {
            Write-Error "Unable to set profile $ProfileName. Exiting..."
        }
    }
    if ($env:AtlassianPowerKit_PROFILE_NAME) {
        Write-Host "Profile loaded: $($env:AtlassianPowerKit_PROFILE_NAME)"
        if (!$FunctionName) {
            Show-AtlassianPowerKitFunctions
        }
        else {
            try {
                Write-Debug "Running function: $FunctionName"
                Invoke-Expression $FunctionName
            }
            catch {
                Write-Error "Function $FunctionName failed. Exiting..."
            }
        }
        Show-AtlassianPowerKitFunctions
    }
}