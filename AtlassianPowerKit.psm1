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

function Import-NestedModules {
    param (
        [Parameter(Mandatory = $true)]
        [string[]] $NESTED_MODULES
    )
    $NESTED_MODULES | ForEach-Object {
        $MODULE_NAME = $_
        Write-Debug "Importing nested module: $MODULE_NAME"
        #Find-Module psd1 file in the subdirectory and import it
        $PSD1_FILE = Get-ChildItem -Path ".\$MODULE_NAME" -Filter "$MODULE_NAME.psd1" -Recurse -ErrorAction SilentlyContinue
        if (-not $PSD1_FILE) {
            Write-Error "Module $MODULE_NAME not found. Exiting."
            throw "Nested module $MODULE_NAME not found. Exiting."
        }
        elseif ($PSD1_FILE.Count -gt 1) {
            Write-Error "Multiple module files found for $MODULE_NAME. Exiting."
            throw "Multiple module files found for $MODULE_NAME. Exiting."
        }
        Import-Module $PSD1_FILE.FullName -Force
        Write-Debug "Importing nested module: $PSD1_FILE,  -- $($PSD1_FILE.BaseName)"
        #Write-Debug "Importing nested module: .\$($_.BaseName)\$($_.Name)"
        # Validate the module is imported
        if (-not (Get-Module -Name $MODULE_NAME)) {
            Write-Error "Module $MODULE_NAME not found. Exiting."
            throw "Nested module $MODULE_NAME not found. Exiting."
        }
    }
    return $NESTED_MODULES
}

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
        Write-Warning "Changing OSM_HOME to $new_home"
        $env:OSM_HOME = $new_home
    }
    if ($env:OSM_HOME -ne $new_home) {
        Write-Warn "OSM_HOME is set to $env:OSM_HOME, but the script location indicates it should be $new_home. This may cause issues."
    }
    $ValidatedOSMHome = (Get-Item $env:OSM_HOME).FullName
    return $ValidatedOSMHome
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
        $singleLineDefinition = $FunctionParameters.GetEnumerator() | ForEach-Object { 
            "$($_.Key)=$($_.Value)" 
        } -join ', '
        Write-Debug "Running function: $FunctionName with parameters: $singleLineDefinition"
        & $FunctionName @FunctionParameters
    }
    else {
        Invoke-Expression "$FunctionName" 
    }
    $stopwatch.Stop()
    Write-Output "Function $FunctionName completed - execution time: $($stopwatch.Elapsed.TotalSeconds) seconds"
    Write-Output "Log file: $LOG_FILE"
    Write-Output 'To run again, use the command: '
    Write-Output "Invoke-AtlassianPowerKitFunction -FunctionName $FunctionName -FunctionParameters @{ $singleLineDefinition }"
}

function Show-AdminFunctions {
    param (
        [Parameter(Mandatory = $false)]
        [string[]] $AdminModules = @('AtlassianPowerKit-Shared', 'AtlassianPowerKit-UsersAndGroups')
    )
    # Clear current screen
    Clear-Host
    Show-AtlassianPowerKitFunctions -NESTED_MODULES $AdminModules
}

# Function display console interface to run any function in the module
function Show-AtlassianPowerKitFunctions {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$NESTED_MODULES
    )
    $selectedFunction = $null
    # Remove AtlassianPowerKit-Shard and AtlassianPowerKit-UsersAndGroups from the nested modules
    $NESTED_MODULES = $NESTED_MODULES | Where-Object { $_ -ne 'AtlassianPowerKit-Shared' -and $_ -ne 'AtlassianPowerKit-UsersAndGroups' }
    # List nested modules and their exported functions to the console in a readable format, grouped by module
    $colors = @('Green', 'Cyan', 'Red', 'Magenta', 'Yellow', 'Blue', 'Gray')
    $colorIndex = 0
    $functionReferences = @()
    $functionReferences += 'Return'
    $NESTED_MODULES | ForEach-Object {
        $MODULE_NAME = $_
        #Write-Debug "DISPLAYING Module: $_"
        # Select a color from the list
        $color = $colors[$colorIndex % $colors.Count]
        $spaces = ' ' * (51 - $_.Length)
        Write-Host '' -BackgroundColor Black
        Write-Host "Module: $($_)" -BackgroundColor $color -ForegroundColor White -NoNewline
        Write-Host $spaces -BackgroundColor $color -NoNewline
        Write-Host ' ' -BackgroundColor Black
        $spaces = ' ' * 40
        Write-Host " Exported Commands:$spaces" -BackgroundColor "Dark$color" -ForegroundColor White -NoNewline
        Write-Host ' ' -BackgroundColor Black
        $colorIndex++
        #Write-Debug $MODULE_NAME
        #Get-Module -Name $MODULE_NAME 
        $FunctionList = (Get-Module -Name $MODULE_NAME).ExportedFunctions.Keys
        $FunctionList | ForEach-Object {
            $functionReferences += $_
            Write-Host ' ' -NoNewline -BackgroundColor "Dark$color"
            Write-Host '   ' -NoNewline -BackgroundColor Black
            Write-Host "$($functionReferences.Length - 1) -> " -NoNewline -BackgroundColor Black
            Write-Host "$_" -NoNewline -BackgroundColor Black -ForegroundColor $color
            # Calculate the number of spaces needed to fill the rest of the line
            $spaces = ' ' * (50 - ($_.Length + (($functionReferences.Length - 1 ).ToString().Length)))
            Write-Host $spaces -NoNewline -BackgroundColor Black
            Write-Host ' ' -NoNewline -BackgroundColor "Dark$color"
            Write-Host ' ' -BackgroundColor Black
            # Increment the color index for the next function
        }
        $colorIndex++
        $spaces = ' ' * 59
        Write-Host $spaces -BackgroundColor "Dark$color" -NoNewline
        Write-Host ' ' -BackgroundColor Black
    }
    Write-Host '[A] Admin (danger) functions'
    Write-Host '[Q / Return] Quit'
    Write-Host '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++' -ForegroundColor DarkGray
    # Write separator for readability
    Write-Host "`n"
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
        $selectedFunction = $selectedFunction
        Write-Debug "Selected function by name: $selectedFunction"
        #Write-Debug "Function references: $($functionReferences.GetType())"
        if ($functionReferences.Contains($selectedFunction)) {
            $SelectedFunctionName = $selectedFunction
        }
        else {
            Write-Error "Function $selectedFunction does not exist in the function references."
        }
    }
    # if selected function is Return, exit the function
    if (!$SelectedFunctionName -or ($SelectedFunctionName -eq 0 -or $SelectedFunctionName -eq 'Return')) {
        Write-Debug 'No function selected. Exiting'
        return $null
    }
    if ($SelectedFunctionName -eq 'A') {
        Show-AdminFunctions
    }
    # Run the selected function timing the execution
    Write-Host "`n"
    Write-Host "Invoking AtlassingPowerKit Function:  $SelectedFunctionName" -ForegroundColor Green
    return $SelectedFunctionName
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
    Write-Host '[A] Admin (danger) functions'
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
    elseif ($selectedProfile -eq 'A') {
        Show-AdminFunctions
    }
    else {
        $selectedProfile = [int]$selectedProfile
        $SELECTED_PROFILE_NAME = $PROFILE_LIST[$selectedProfile]
        # Write-Debug "Selected profile index: $selectedProfile"
        # Write-Debug "Selected profile name: $($PROFILE_LIST[$selectedProfile])"
        #$LOADED_PROFILENAME = Set-AtlassianPowerKitProfile -SelectedProfileName $($PROFILE_LIST[$selectedProfile])
        return $SELECTED_PROFILE_NAME
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
        [hashtable] $FunctionParameterHashTable,
        [Parameter(Mandatory = $false)]
        [switch] $ClearProfile
    )
    $NESTED_MODULES = Import-NestedModules -NESTED_MODULES @('AtlassianPowerKit-Shared', 'AtlassianPowerKit-Jira', 'AtlassianPowerKit-Confluence', 'AtlassianPowerKit-GRCosm', 'AtlassianPowerKit-JSM', 'AtlassianPowerKit-UsersAndGroups')
    if (!$env:AtlassianPowerKit_RequisiteModules) {
        $env:AtlassianPowerKit_RequisiteModules = Get-RequisitePowerKitModules
        Write-Debug 'AtlassianPowerKit_RequisiteModules - Required modules imported'
    }
    try {
        #Push-Location -Path $PSScriptRoot -ErrorAction Continue
        Write-Debug "Starting AtlassianPowerKit, running from $((Get-Item -Path $PSScriptRoot).FullName)"
        Write-Debug "OSM_HOME: $(Test-OSMHomeDir)"
        # If current directory is not the script root, push the script root to the stack
        if ($ResetVault) {
            Clear-AtlassianPowerKitVault
            return $true
        }
        if ($ArchiveProfileDirs) {
            Clear-AtlassianPowerKitProfileDirs
            return $true
        }
        if ($ClearProfile) {
            Clear-AtlassianPowerKitProfile
            return $true
        }
        # If no profile name is provided, list the available profiles
        $ProfileName = $null
        if ($Profile) {
            $ProfileName = $Profile.Trim().ToLower()
        }
        if (!$ProfileName) {
            $ProfileName = $(Show-AtlassianPowerKitProfileList)
        }
        $CURRENT_PROFILE = Set-AtlassianPowerKitProfile -SelectedProfileName $ProfileName
        Write-Debug "Profile set to: $CURRENT_PROFILE"
        if (!$FunctionName) {
            $FunctionName = Show-AtlassianPowerKitFunctions -NESTED_MODULES $NESTED_MODULES
        }
        # If function parameters are provided, splat them to the function
        Write-Debug "AtlassianPowerKit Main - Running function: $FunctionName, with profile: $CURRENT_PROFILE"
        if ($FunctionParameterHashTable) {
            Write-Debug '   Parameters provided to the function via hashtable:'
            # Iterate through the hashtable and display the key value pairs as "-key value"
            $FunctionParameterHashTable.GetEnumerator() | ForEach-Object {
                Write-Debug "       -$($_.Key) $_.Value"
            }
            Invoke-AtlassianPowerKitFunction -FunctionName $FunctionName -FunctionParameters $FunctionParameterHashTable
        }
        elseif ($FunctionName) {
            Write-Debug "AtlassianPowerKit Main: No parameters provided to the function, attempting to run the function without parameters: $FunctionName"
            Invoke-AtlassianPowerKitFunction -FunctionName $FunctionName
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
        Remove-Item 'env:AtlassianPowerKit_*' -ErrorAction Continue
        Write-Debug 'Gracefully exited AtlassianPowerKit'
    }
}