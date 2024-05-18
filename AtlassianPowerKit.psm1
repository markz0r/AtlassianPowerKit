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
    Use-AtlassianCloudPowerKit
    This example lists all functions in the AtlassianPowerKit module.
.EXAMPLE
    Use-AtlassianCloudPowerKit
    Simply run the function to see a list of all functions in the module and nested modules.
.EXAMPLE
    Get-DefinedPowerKitVariables
    This example lists all variables defined in the AtlassianPowerKit module.
.LINK
    GitHub:

#>
$ErrorActionPreference = 'Stop'; $DebugPreference = 'Continue'
$script:PROFILE_LIST = @()
$script:LOADED_PROFILE = @{}

$script:AtlassianPowerKitRequiredModules = @('Microsoft.PowerShell.SecretManagement', 'Microsoft.PowerShell.SecretStore')

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
}
# Function display console interface to run any function in the module
function Show-AtlassianCloudPowerKitFunctions {
    # List nested modules and their exported functions to the console in a readable format, grouped by module
    $colors = @('Green', 'Cyan', 'Red', 'Magenta', 'Yellow')
    $nestedModules = Get-Module -Name AtlassianPowerKit | Select-Object -ExpandProperty NestedModules | Where-Object Name -Match 'AtlassianPowerKit-.*'

    $colorIndex = 0
    $functionReferences = @{}
    $nestedModules | ForEach-Object {
        # Select a color from the list
        $color = $colors[$colorIndex % $colors.Count]
        $spaces = ' ' * (52 - $_.Name.Length)
        Write-Host '' -BackgroundColor Black
        Write-Host "Module: $($_.Name)" -BackgroundColor $color -ForegroundColor White -NoNewline
        Write-Host $spaces  -BackgroundColor $color -NoNewline
        Write-Host ' ' -BackgroundColor Black
        $spaces = ' ' * 41
        Write-Host " Exported Commands:$spaces" -BackgroundColor "Dark$color" -ForegroundColor White -NoNewline
        Write-Host ' ' -BackgroundColor Black
        $_.ExportedCommands.Keys | ForEach-Object {
            # Assign a letter reference to the function
            $functRefNum = $colorIndex
            $functionReferences[$functRefNum] = $_

            Write-Host ' ' -NoNewline -BackgroundColor "Dark$color"
            Write-Host '   ' -NoNewline -BackgroundColor Black
            Write-Host "$functRefNum -> " -NoNewline -BackgroundColor Black
            Write-Host "$_" -NoNewline -BackgroundColor Black -ForegroundColor $color
            # Calculate the number of spaces needed to fill the rest of the line
            $spaces = ' ' * (50 - $_.Length)
            Write-Host $spaces -NoNewline -BackgroundColor Black
            Write-Host ' ' -NoNewline -BackgroundColor "Dark$color"
            Write-Host ' ' -BackgroundColor Black
            # Increment the color index for the next function
            $colorIndex++
        }
        $spaces = ' ' * 60
        Write-Host $spaces -BackgroundColor "Dark$color" -NoNewline
        Write-Host ' ' -BackgroundColor Black
    }

    # Write separator for readability
    Write-Host "`n" -BackgroundColor Black
    Write-Host '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++' -BackgroundColor Black -ForegroundColor DarkGray
    # Ask the user which function they want to run
    $selectedFunction = Read-Host -Prompt "`nSelect a function to run (or hit enter to exit):"
    # Attempt to convert the input string to a char
    try {
        $selectedFunction = [int]$selectedFunction
    }
    catch {
        if (!$selectedFunction) {
            return $true
        }
        Write-Host 'Invalid selection. Please try again.'
        Show-AtlassianCloudPowerKitFunctions
    }
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
        # Exit with an error code
        exit 1
    }
    finally {
        # Ask the user if they want to run another function
    }   if ($runAnother -eq 'Y') {
        Get-PowerKitFunctions
    }
    else {
        Write-Host 'Have a great day!'
        return $true
    }
}

# Function to create a new profile
function New-AtlassianCloudPowerKitProfile {
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
            Register-AtlassianCloudPowerKitProfile($ProfileName)       
        }
        catch {
            Write-Debug "Error: $($_.Exception.Message)'
            throw 'Register-AtlassianCloudPowerKitProfile $ProfileName failed. Exiting."
        }
    }
}

# Function to list availble profiles with number references for interactive selection or 'N' to create a new profile
function Show-AtlassianCloudPowerKitProfileList {
    $profileIndex = 0
    if ($script:PROFILE_LIST.Count -eq 0) {
        Write-Host 'No profiles found. Please create a new profile.'
        New-AtlassianCloudPowerKitProfile
    }
    else {
        # ensure $script:AtlassianCloudProfilesis an array
        if ($script:PROFILE_LIST -isnot [System.Array]) {
            $script:PROFILE_LIST = @($script:PROFILE_LIST)
        }
        $script:PROFILE_LIST | ForEach-Object {
            Write-Host "[$profileIndex] $_"
            $profileIndex++
        }
        Write-Host '[N] Create a new profile'
        Write-Host '[Q] Quit'
        Write-Host '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++' -ForegroundColor DarkGray
        $selectedProfile = Read-Host 'Select a profile to use or create a new profile'
        if ($selectedProfile -eq 'N') {
            New-AtlassianCloudPowerKitProfile
        } 
        elseif ($selectedProfile -eq 'Q') {
            Write-Host 'Exiting...'
            return $true
        }
        else {
            $selectedProfile = [int]$selectedProfile
            Write-Debug "Selected profile index: $selectedProfile"
            Write-Debug "Selected profile name: $($script:PROFILE_LIST[$selectedProfile])"
            return $script:PROFILE_LIST[$selectedProfile]
        }
    }
}

function Use-AtlassianCloudPowerKit {
    param (
        [Parameter(Mandatory = $false)]
        [string] $ProfileName
    )
    Get-RequisitePowerKitModules
    $script:PROFILE_LIST = Get-AtlassianCloudPowerKitProfileList
    if (!$ProfileName) {
        Write-Host 'No profile name provided. Check the profiles available.'
        $ProfileName = Show-AtlassianCloudPowerKitProfileList
    }
    else {
        $ProfileName = $ProfileName.Trim().ToLower()
        if (!($script:PROFILE_LIST -contains $ProfileName)) {
            Write-Host 'Profile not found. Check the profiles available.'
            Show-AtlassianCloudPowerKitProfileList
        }
    }
    Set-AtlassianCloudPowerKitProfile -ProfileName $ProfileName
    $script:LOADED_PROFILE = Get-LoadedProfile
    Write-Host "Profile loaded: $($script:LOADED_PROFILE)"
    Show-AtlassianCloudPowerKitFunctions
}