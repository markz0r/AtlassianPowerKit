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


function Test-OSMHomeDir {
    # If the OSM_HOME environment variable is not set, set it to the current directory.
    $new_home = $(Get-Item $pwd).FullName | Split-Path -Parent
    if (-not $env:OSM_HOME) {
        Write-Debug "Setting OSM_HOME to $new_home"
        $env:OSM_HOME = $new_home
    }
    # Check the OSM_HOME environment variable directory exists
    if (-not (Test-Path $env:OSM_HOME)) {
        Write-Warning "OSM_HOME directory not found: $env:OSM_HOME"
        Write-Warn "Changing OSM_HOME to $new_home"
        $env:OSM_HOME = $new_home
    }
    if ($env:OSM_HOME -ne $new_home) {
        Write-Warn "OSM_HOME is set to $env:OSM_HOME, but the script location indicates it should be $new_home. This may cause issues."
    }
    $ValidatedOSMHome = (Get-Item $env:OSM_HOME).FullName
    return $ValidatedOSMHome
}

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
        [hashtable] $FunctionParameters
    )
    $TEMP_DIR = "$env:OSM_HOME\$env:AtlassianPowerKit_PROFILE_NAME\.temp"
    if (-not (Test-Path $TEMP_DIR)) {
        New-Item -ItemType Directory -Path $TEMP_DIR -Force | Out-Null
    }
    $TIMESTAMP = Get-Date -Format 'yyyyMMdd-HHmmss'
    $LOG_FILE = "$TEMP_DIR\$FunctionName-$TIMESTAMP.log"
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $stopwatch.Start()
    if ($FunctionParameters) {
        Write-Debug "Running function: $FunctionName with parameters: $($FunctionParameters | Out-String)"
        & $FunctionName @FunctionParameters
    }
    else {
        Invoke-Expression "$FunctionName" 
    }
    $stopwatch.Stop()
    Write-Output "Function $FunctionName completed - execution time: $($stopwatch.Elapsed.TotalSeconds) seconds"
    Write-Output "Log file: $LOG_FILE"
}

function Import-NestedModules {
    # Get directory of this module
    $LOCAL_MODULES = $(Get-ChildItem -Path . -Recurse -Depth 1 -Include *.psd1 -Exclude 'AtlassianPowerKit.psd1', 'AtlassianPowerKit-Shared.psd1', 'Naive-ConflunceStorageValidator.psd1')
    # Find list of module in subdirectories and import them
    Import-Module .\AtlassianPowerKit-Shared\AtlassianPowerKit-Shared.psd1 -Force
    #Get-Module -Name AtlassianPowerKit*
    $LOCAL_MODULES | ForEach-Object {
        #Write-Debug "Importing nested module: .\$($_.BaseName)\$($_.Name)"
        Import-Module $_.FullName -Force
        # Validate the module is imported
        if (-not (Get-Module -Name $_.BaseName)) {
            Write-Error "Module $($_.BaseName) not found. Exiting."
            throw "Nested module $($_.BaseName) not found. Exiting."
        }
    }
}

function Get-RequisitePowerKitModules {
    $AtlassianPowerKitRequiredModules = @('PowerShellGet', 'Microsoft.PowerShell.SecretManagement', 'Microsoft.PowerShell.SecretStore')
    $AtlassianPowerKitRequiredModules | ForEach-Object {
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
}
# Function display console interface to run any function in the module
function Show-AtlassianPowerKitFunctions {
    $selectedFunction = $null
    # List nested modules and their exported functions to the console in a readable format, grouped by module
    $colors = @('Green', 'Cyan', 'Red', 'Magenta', 'Yellow')
    $LOCAL_MODULES = $(Get-ChildItem -Path . -Recurse -Depth 1 -Include *.psd1 -Exclude 'AtlassianPowerKit.psd1', 'AtlassianPowerKit-Shared.psd1', 'Naive-ConflunceStorageValidator.psd1')
    $localModules = $LOCAL_MODULES | ForEach-Object {
        Write-Debug "Local module: $($_.FullName -replace '.psd1', '')"
        Import-Module -Name $_.FullName -Force -ErrorAction Stop
        Get-Module -Name $($_.Name -replace '.psd1', '') -Verbose -ErrorAction Stop
    }
    Write-Debug "Nested modules: $localModules"

    $colorIndex = 0
    $functionReferences = @{}
    $functionReferences[0] = 'Return'
    $localModules | ForEach-Object {
        Write-Debug "DISPLAYING Module: $($_.Name)"
        # Select a color from the list
        $color = $colors[$colorIndex % $colors.Count]
        $spaces = ' ' * (51 - $_.Name.Length)
        Write-Host '' -BackgroundColor Black
        Write-Host "Module: $($_.Name)" -BackgroundColor $color -ForegroundColor White -NoNewline
        Write-Host $spaces -BackgroundColor $color -NoNewline
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
        Write-Debug "Selected function by num: $selectedFunction"
        $SelectedFunctionName = ($functionReferences[[int]$selectedFunction])
    }
    elseif ($selectedFunction -match '^(?i)[a-z]*-[a-z]*$') {
        # Test if the function exists
        $selectedFunction = $selectedFunction.Trim().ToLower()
        Write-Debug "Selected function by name: $selectedFunction"
        Write-Debug "Function references: $($functionReferences.GetType())"
        if ($functionReferences.Values -contains $selectedFunction) {
            $SelectedFunctionName = $selectedFunction
        }
        else {
            Write-Error "Function $SelectedFunctionName does not exist in the function references."
        }
    }
    # if selected function is Return, exit the function
    if (!$SelectedFunctionName -or ($SelectedFunctionName -eq 0)) {
        Write-Debug 'No function selected. Exiting'
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
        [string] $Profile,
        [Parameter(Mandatory = $false)]
        [switch] $ArchiveProfileDirs,
        [Parameter(Mandatory = $false)]
        [switch] $ResetVault,
        [Parameter(Mandatory = $false)]
        [string] $FunctionName,
        [Parameter(Mandatory = $false)]
        [hashtable] $FunctionParameterHashTable
    )
    Import-NestedModules
    try {
        #Push-Location -Path $PSScriptRoot -ErrorAction Continue
        Write-Debug "Starting AtlassianPowerKit, running from $((Get-Item -Path $PSScriptRoot).FullName)"
        Write-Debug "OSM_HOME: $(Test-OSMHomeDir)"
        # If current directory is not the script root, push the script root to the stack
        Get-RequisitePowerKitModules
        if ($ResetVault) {
            Clear-AtlassianPowerKitVault
            return $null
        }
        if ($ArchiveProfileDirs) {
            Clear-AtlassianPowerKitProfileDirs
            return $null
        }
    }
    catch {
        Write-Error 'AtlassianPowerKit Main: Error initializing AtlassianPowerKit. Exiting.'
        throw 'AtlassianPowerKit Main: Error initializing AtlassianPowerKit. Exiting.'
    }
    try {
        # If no profile name is provided, list the available profiles
        $ProfileName = $null
        if ($Profile) {
            $ProfileName = $Profile.Trim().ToLower()
        }
        else {
            $ProfileName = $(Get-CurrentAtlassianPowerKitProfile)
            Write-Debug "Profile already loaded: $ProfileName"
        }
        if (!$ProfileName) {
            if (!$FunctionName) {
                Write-Host 'No profile name provided or currently loaded... listing options.'
                try {
                    $ProfileName = $(Show-AtlassianPowerKitProfileList)
                }
                catch {
                    Write-Error 'AtlassianPowerKit Main: No profile selected. Exiting...'
                    throw 'AtlassianPowerKit Main: No profile selected. Exiting...' 
                }
            }
            else {
                Write-Debug "Example: AtlassianPowerKit -ProfileName 'profileName' -FunctionName 'functionName' -FunctionParameterHashTable @{parameter1='value1';parameter='value2'}"
                Write-Error 'AtlassianPowerKit Main: No -ProfileName provided with FunctionName, Exiting...'
            }
        } 
        $ProfileName = Set-AtlassianPowerKitProfile -SelectedProfileName $ProfileName
        if (!$FunctionName) {
            Show-AtlassianPowerKitFunctions
        }
        else {
            # If function parameters are provided, splat them to the function
            Write-Debug "AtlassianPowerKit Main - Running function: $FunctionName, with profile: $ProfileName and parameters:"
            if ($FunctionParameterHashTable) {
                # Iterate through the hashtable and display the key value pairs as "-key value"
                $FunctionParameterHashTable.GetEnumerator() | ForEach-Object {
                    Write-Debug "-$($_.Key) $_.Value"
                }
                Invoke-AtlassianPowerKitFunction -FunctionName $FunctionName -FunctionParameters $FunctionParameterHashTable
            }
            else {
                Write-Debug 'AtlassianPowerKit Main: No parameters provided to the function, attempting to run the function without parameters.'
                Invoke-AtlassianPowerKitFunction -FunctionName $FunctionName
            }

        }
    }
    catch {
        # Write call stack and sub-function error messages to the debug output
        Write-Debug '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ AtlassianPowerKit Main: '
        # Write full call stack to the debug output and error message to the console
        Get-PSCallStack
        Write-Debug '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ AtlassianPowerKit Main: '
        Write-Error $_.Exception.Message
    }
    finally {
        #Clear-AtlassianPowerKitProfile
        Pop-Location
        Write-Debug 'Gracefully exited AtlassianPowerKit'
    }
}