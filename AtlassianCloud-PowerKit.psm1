<# 
.SYNOPSIS
    Atlassian Cloud PowerKit module for interacting with Atlassian Cloud REST API.
.DESCRIPTION
    Atlassian Cloud PowerKit module for interacting with Atlassian Cloud REST API.
    - Dependencies: AtlassianCloud-PowerKit-Shared
    - Functions:
        - Get-PowerKitFunctions
        - Get-PowerKitModules
        - Get-DefinedPowerKitVariables
    - Debug output is enabled by default. To disable, set $DisableDebug = $true before running functions.
.EXAMPLE
    Get-PowerKitFunctions
    This example lists all functions in the AtlassianCloud-PowerKit module.
.EXAMPLE
    Get-PowerKitModules
    This example lists all modules in the AtlassianCloud-PowerKit module.
.EXAMPLE
    Get-DefinedPowerKitVariables
    This example lists all variables defined in the AtlassianCloud-PowerKit module.
.LINK
    GitHub: 

#>
$ErrorActionPreference = 'Stop'; $DebugPreference = 'Continue'

function Get-PowerKitFunctions {
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
    write-host "`n"
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
                Get-PowerKitFunctions
            }
        }
        
    }
    else {
        Write-Host 'Invalid selection. Please try again.'
    }
}

function Get-PowerKitModules {
    Get-Module -Name AtlassianCloud-PowerKit -ListAvailable
}