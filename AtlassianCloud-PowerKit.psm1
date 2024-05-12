<#
.SYNOPSIS
    Atlassian Cloud PowerKit module for interacting with Atlassian Cloud REST API.
.DESCRIPTION
    Atlassian Cloud PowerKit module for interacting with Atlassian Cloud REST API.
    - Dependencies: AtlassianCloud-PowerKit-Shared
    - Functions:
      - Use-AtlassianCloud-PowerKit: Interactive function to run any function in the module.
    - Debug output is enabled by default. To disable, set $DisableDebug = $true before running functions.
.EXAMPLE
    Use-AtlassianCloudPowerKit
    This example lists all functions in the AtlassianCloud-PowerKit module.
.EXAMPLE
    Use-AtlassianCloudPowerKit
    Simply run the function to see a list of all functions in the module and nested modules.
.EXAMPLE
    Get-DefinedPowerKitVariables
    This example lists all variables defined in the AtlassianCloud-PowerKit module.
.LINK
    GitHub:

#>
$ErrorActionPreference = 'Stop'; $DebugPreference = 'Continue'
$script:AtlassianCloudProfiles = @()
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
function Show-AtlassionCloudPowerKitFunctions {
    # List nested modules and their exported functions to the console in a readable format, grouped by module
    $colors = @('Green', 'Cyan', 'Red', 'Magenta', 'Yellow')
    $nestedModules = Get-Module -Name AtlassianCloud-PowerKit | Select-Object -ExpandProperty NestedModules

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
            $letterReference = [char](65 + $colorIndex)
            $functionReferences[$letterReference] = $_

            Write-Host ' ' -NoNewline -BackgroundColor "Dark$color"
            Write-Host '   ' -NoNewline -BackgroundColor Black
            Write-Host "$letterReference -> " -NoNewline -BackgroundColor Black
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
    $selectedFunction = $selectedFunction.Trim().ToUpper()
    # Attempt to convert the input string to a char
    try {
        $selectedFunction = [char]$selectedFunction
    }
    catch {
        Write-Host 'Invalid selection. Please try again.'
        return
    }
    $selectedFunction = [char]$selectedFunction
    Write-Host "`n"
    Write-Host "You selected: $selectedFunction"
    if ([string]::IsNullOrEmpty($selectedFunction)) {
        return
    }
    elseif ($functionReferences.ContainsKey($selectedFunction)) {
        # Run the selected function timing the execution
        try {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            Invoke-Expression $functionReferences[$selectedFunction]
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
            # Write success separator
            Write-Host "`n" -BackgroundColor Black
            Write-Host '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++' -BackgroundColor Black -ForegroundColor DarkGreen
            Write-Host "`n"
            $message = "Success! --> **$($functionReferences[$selectedFunction])** completed at $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) taking $($stopwatch.Elapsed.TotalSeconds) seconds."
            Write-Host ($message | ConvertFrom-Markdown -AsVT100EncodedString).VT100EncodedString -BackgroundColor Black -ForegroundColor DarkGreen
            Write-Host '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++' -BackgroundColor Black -ForegroundColor DarkGre
            $runAnother = Read-Host 'Run another function? (Y/N)'
            if ($runAnother -eq 'Y') {
                Use-AtlassianCloudPowerKit
            }
        }

    }
    else {
        Write-Host 'Invalid selection. Please try again.'
    }
}
# Function to list availble profiles with number references for interactive selection or 'N' to create a new profile
function Show-AtlassianCloudPowerKitProfileList {
    $profileIndex = 0
    $script:AtlassianCloudProfiles | ForEach-Object {
        Write-Host "[$profileIndex] $_"
        $profileIndex++
    }
    # Read the user input
    if ($script:AtlassianCloudProfiles.Count -eq 0) {
        Write-Host 'No profiles found. Please create a new profile.'
    }
    Write-Host '[N] Create a new profile'
    $selectedProfile = Read-Host 'Select a profile to use or create a new profile:'
    # Load the selected profile or create a new profile
    if ($selectedProfile -eq 'N') {
        Write-Debug 'Calling function to create a new profile.'
        # Ask user to enter the profile name
        $PROF_INPUT_NAME = Read-Host 'Enter a profile name:'
        $PROF_INPUT_NAME = [string]$PROF_INPUT_NAME.Trim().ToLower()
        Write-Debug "Profile name entered: $PROF_INPUT_NAME"
        if (!$PROF_INPUT_NAME -or $PROF_INPUT_NAME -eq '' -or $script:AtlassianCloudProfiles.Contains($PROF_INPUT_NAME) -or $PROF_INPUT_NAME.Length -gt 100) {
            Write-Error 'Profile name cannot be empty, taken or mor than 100 characters, Please try again.'
        }
        else {
            if (Register-AtlassianCloudPowerKitProfile -ProfileName $PROF_INPUT_NAME) {
                $script:AtlassianCloudProfiles = Get-AtlassianCloudPowerKitProfileList
                Write-Host 'Profile created successfully... loading'
                Set-AtlassianCloudPowerKitProfile -ProfileName $PROF_INPUT_NAME
            }
            else {
                Write-Error 'Profile creation failed. Please try again.'
            }
        }
    }
    elseif ($selectedProfile -ge 0 -and $selectedProfile -lt $script:AtlassianCloudProfiles.Count) {
        Set-AtlassianCloudPowerKitProfile -ProfileName $script:AtlassianCloudProfiles[$selectedProfile]
    }
    else {
        Write-Error 'Invalid selection. Please try again.'
    }
}

function Use-AtlassianCloudPowerKit {
    param (
        [Parameter(Mandatory = $false)]
        [string] $ProfileName
    )
    Get-RequisitePowerKitModules
    $script:AtlassianCloudProfiles = Get-AtlassianCloudPowerKitProfileList
    if (!$ProfileName) {
        Write-Host 'No profile name provided. Check the profiles available.'
        Show-AtlassianCloudPowerKitProfileList
    }
    else {
        $ProfileName = $ProfileName.Trim().ToLower()
        if ($script:AtlassianCloudProfiles -contains $ProfileName) {
            Set-AtlassianCloudPowerKitProfile -ProfileName $ProfileName
        }
        else {
            Write-Host 'Profile not found. Check the profiles available.'
            Show-AtlassianCloudPowerKitProfileList
        }
        Set-AtlassianCloudPowerKitProfile -ProfileName $ProfileName
    }
    $LOADED_PROFILE = Get-AtlassianCloudSelectedProfile
    Write-Host "Profile loaded: $($LOADED_PROFILE.PROFILE_NAME)"
    Show-AtlassionCloudPowerKitFunctions
}