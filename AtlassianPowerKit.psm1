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
Push-Location $PSScriptRoot
$script:AtlassianPowerKitRequiredModules = @('PowerShellGet', 'Microsoft.PowerShell.SecretManagement', 'Microsoft.PowerShell.SecretStore')
$script:LOCAL_MODULES = $(Get-ChildItem -Path . -Recurse -Depth 1 -Include *.psd1 -Exclude 'AtlassianPowerKit.psd1', 'AtlassianPowerKit-Shared.psd1', 'Naive-ConflunceStorageValidator.psd1')

# function to create a zip archives of the profile directories
function Clear-AtlassianPowerKitProfileDirs {
    $profileNames = Get-AtlassianPowerKitProfileList
    Write-Debug "Assuming profile dirs is as per the profile list: $profileNames"
    $profileNames | ForEach-Object {
        $profileDir = (Get-Item -Path $_).FullName
        Write-Debug "Profile directory: $profileDir"
        $zipFile = "$profileDir-$(Get-Date -Format 'yyyyMMdd-HHmmss').zip"
        Compress-Archive -Path $profileDir -DestinationPath $zipFile -Exclude '*.zip' 
        Write-Debug "Profile directory $profileDir archived to $zipFile"
        # Remove the profile directory
        Remove-Item -Path "$profileDir\*.*" -Exclude '*.zip' -Force 
    }
}

function Invoke-AtlassianPowerKitFunction {
    param (
        [Parameter(Mandatory = $true)]
        [string] $FunctionName,
        [Parameter(Mandatory = $false)]
        [string] $ProvidedProfileName,
        [Parameter(Mandatory = $false)]
        [hashtable] $FunctionParameters
    )
    Import-NestedModules
    if ($ProvidedProfileName) {
        $LOADED_PROFILE = Set-AtlassianPowerKitProfile -SelectedProfileName $ProvidedProfileName
    } 
    else {
        $LOADED_PROFILE = Get-CurrentAtlassianPowerKitProfile
        # Test if a profile is loaded, if not, ask the user to select a profile
    }
    if (!$LOADED_PROFILE) {
        Write-Host 'No profile loaded. Please select a profile.'
        $LOADED_PROFILE = Show-AtlassianPowerKitProfileList
    }
    Write-Debug "Invoking function: $FunctionName with profile: $LOADED_PROFILE"
    
    # Splattting the parameters to the function
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    Invoke-Expression "$FunctionName @FunctionParameters"
    $stopwatch.Stop()
    Write-Output "Function $FunctionName completed - execution time: $($stopwatch.Elapsed.TotalSeconds) seconds"
}

function Import-NestedModules {
    # Get directory of this module
    $pwd
    # Find list of module in subdirectories and import them
    Import-Module .\AtlassianPowerKit-Shared\AtlassianPowerKit-Shared.psd1 -Force
    #Get-Module -Name AtlassianPowerKit*
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
        Import-NestedModules
    }

}
# Function display console interface to run any function in the module
function Show-AtlassianPowerKitFunctions {
    $selectedFunction = $null
    # List nested modules and their exported functions to the console in a readable format, grouped by module
    $colors = @('Green', 'Cyan', 'Red', 'Magenta', 'Yellow')
    $localModules = $script:LOCAL_MODULES | ForEach-Object {
        Write-Debug "Local module: $($_.Name -replace '.psd1', '')"
        Get-Module -Name $($_.Name -replace '.psd1', '')
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
    $selectedFunction = Read-Host -Prompt "`nSelect a function by number or name to run (or hit enter to exit)"
    if ($selectedFunction -match '^\d+$') {
        $SelectedFunctionName = ($functionReferences[[int]$selectedFunction])
    }
    elseif ($selectedFunction -match '^\w+$') {
        try {
            # Test if the function exists
            $SelectedFunctionName = ($functionReferences | Where-Object { $_ -eq $selectedFunction })
        }
        catch {
            Write-Error "Function $selectedFunction not found"
        }
    }
    # if selected function is Return, exit the function
    if (!$SelectedFunctionName -or ($SelectedFunctionName -eq 0)) {
        return $false
    } 
    # Run the selected function timing the execution
    Write-Host "`n"
    Write-Host "Invoking AtlassingPowerKit Function:  $SelectedFunctionName" -ForegroundColor Green
    Invoke-AtlassianPowerKitFunction -FunctionName $SelectedFunctionName
    # Ask the user if they want to run another function
    Write-Host "`n"
    $runAnother = Read-Host 'Run another function? (Y / Return to exit)'
    if (($runAnother) -and ($runAnother -eq 'Y')) {
        Show-AtlassianPowerKitFunctions
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
    #Get-AtlassianPowerKitProfileList
    $PROFILE_LIST = Get-AtlassianPowerKitProfileList
    $profileIndex = 0
    if (!$PROFILE_LIST) {
        Write-Host 'Please create a new profile.'
        New-AtlassianPowerKitProfile
        #Write-Debug "Profile List: $(Get-AtlassianPowerKitProfileList)"
        #Show-AtlassianPowerKitProfileList
    } 
    else {
        #Write-Debug "Profile list: $env:AtlassianPowerKit_PROFILE_LIST_STRING"
        Write-Debug "Profile list string $PROFILE_LIST"
        $PROFILE_LIST.split() | ForEach-Object {
            Write-Host "[$profileIndex] $_"
            $profileIndex++
        }
    }   
    Write-Host '[N] Create a new profile'
    Write-Host '[C] Clear profile directories - Archives to zip then clears all files in profile directories'
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
    elseif ($selectedProfile -eq 'C') {
        Clear-AtlassianPowerKitProfileDirs
    }
    elseif ($selectedProfile -eq 'R') {
        Clear-AtlassianPowerKitVault
    }
    else {
        $selectedProfile = [int]$selectedProfile
        Write-Debug "Selected profile index: $selectedProfile"
        Write-Debug "Selected profile name: $($PROFILE_LIST[$selectedProfile])"
        $LOADED_PROFILENAME = Set-AtlassianPowerKitProfile -SelectedProfileName $($PROFILE_LIST[$selectedProfile])
        return $LOADED_PROFILENAME
    }
}

function AtlassianPowerKit {
    param (
        [Parameter(Mandatory = $false)]
        [string] $InputProfileName,
        [Parameter(Mandatory = $false)]
        [switch] $ArchiveProfileDirs,
        [Parameter(Mandatory = $false)]
        [switch] $ResetVault,
        [Parameter(Mandatory = $false)]
        [string] $FunctionName,
        [Parameter(Mandatory = $false)]
        [hashtable] $FunctionParameterHashTable
    )
    try {
        Get-RequisitePowerKitModules
        if ($ResetVault) {
            Clear-AtlassianPowerKitVault
            return $null
        }
        if ($ArchiveProfileDirs) {
            Clear-AtlassianPowerKitProfileDirs
            return $null
        }
        if (!$InputProfileName) {
            if (!$FunctionName) {
                Write-Host 'No profile name provided. Check the profiles available.'
                try {
                    $InputProfileName = Show-AtlassianPowerKitProfileList
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
        $InputProfileName = $InputProfileName.Trim().ToLower()
        $LOADED_PROFILE = Set-AtlassianPowerKitProfile -SelectedProfileName $InputProfileName
        #Write-Debug "Setting provided profile: $ProfileName"
        #Set-AtlassianPowerKitProfile $ProfileName
        if ($LOADED_PROFILE -ne $InputProfileName) {
            Write-Error 'Profile not loaded! Exiting...'
            return $false
        }
        if (!$FunctionName) {
            Show-AtlassianPowerKitFunctions
        }
        else {
            # If function parameters are provided, splat them to the function
            Write-Debug "Running function: $FunctionName, with profile: $InputProfileName and parameters:"
            if ($FunctionParameterHashTable) {
                # Iterate through the hashtable and display the key value pairs as "-key value"
                $FunctionParameterHashTable.GetEnumerator() | ForEach-Object {
                    Write-Debug "-$($_.Key) $_.Value"
                }
                Invoke-AtlassianPowerKitFunction -FunctionName $FunctionName -SelectedProfileName $InputProfileName -FunctionParameters $FunctionParameterHashTable
            }
            else {
                Write-Debug 'No parameters provided to the function, attempting to run the function without parameters.'
                Invoke-AtlassianPowerKitFunction -FunctionName $FunctionName -SelectedProfileName $InputProfileName
            }

        }
    }
    catch {
        Write-Debug "Exiting - with error: $($_.Exception.Message)"
    }
    finally {
        Clear-AtlassianPowerKitProfile
        #Pop-Location
        Write-Debug 'Gracefully exited AtlassianPowerKit'
    }
}