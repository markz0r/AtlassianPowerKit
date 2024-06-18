<#
.SYNOPSIS
    Atlassian Cloud PowerShell Module for handy functions to interact with Attlassian Cloud APIs.

.LINK
GitHub: https://github.com/markz0r/AtlassianPowerKit

#>
$ErrorActionPreference = 'Stop'; $DebugPreference = 'Continue'
$POWERSHELL_MODULE_DEPS = @('Microsoft.Graph')
$MS_GRAPH_SCOPES = @('Files.Read.All', 'Sites.Read.All') # Required scopes for listing SharePoint documents and retrieving the unique identifier

$requiredModules = @('AtlassianPowerKit-Shared', 'AtlassianPowerKit-Conflunce', 'AtlassianPowerKit-Jira')

#  funciton to install, update, and import POWERSHELL_MODULE_DEPS
function Install-AtlassianPowerKitGRCosmDependencies {
    $POWERSHELL_MODULE_DEPS | ForEach-Object {
        if (-not (Get-Module -ListAvailable -Name $_)) {
            Install-Module -Name $_ -Force -Scope CurrentUser -AllowClobber
        }
        else {
            Write-Debug "Module $_ already installed, checking for updates..."
        }
        # Update the module
        Update-Module -Name $_ -Force
        # Import the module
        Import-Module -Name $_ -Force
    }
}

# Authenticate to MS Graph using interactive login, scope is for listing SharePoint documents and retrieving the unique identifier
function Connect-MgGraphScoped {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]
        $RequiredScopes
    )

    # Get the current context
    $context = Get-MgContext

    # Check if the context and its scopes are not null
    if ($null -ne $context -and $null -ne $context.Scopes) {
        # Check if the context's scopes include all the required scopes
        $hasRequiredScopes = $RequiredScopes | ForEach-Object { $context.Scopes -contains $_ } | Where-Object { $_ -eq $false } | Measure-Object | Select-Object -ExpandProperty Count -eq 0

        if (-not $hasRequiredScopes) {
            # If the context doesn't have all the required scopes, authenticate again
            Connect-MgGraph -Scopes $RequiredScopes
        }
    }
    else {
        # If there's no context or its scopes are null, authenticate
        Connect-MgGraph -Scopes $RequiredScopes
    }
}

function Get-PdfFilesInSharePoint {
    param (
        [Parameter(Mandatory = $true)]
        [string]$TenantName,
        [Parameter(Mandatory = $true)]
        [string]$SiteName,
        [Parameter(Mandatory = $true)]
        [string]$FolderPath,
        [Parameter(Mandatory = $false)]
        [switch]$Recursive
    )
    $SiteURL = "https://$TenantName.sharepoint.com"
    $SiteId = "$SiteURL,/sites/$SiteName"
    Write-Debug "SiteId: $SiteId"
    # Check if the site exists
    $site = Get-MgSite -SiteId $SiteId
    
    # Ensure the necessary Microsoft Graph connection
    Connect-MgGraphScoped -RequiredScopes $MS_GRAPH_SCOPES
    

    $DriveId = 
    # Get the folder
    $folder = Get-MgDriveListItem -SiteId $SiteId -DriveId $DriveId -ItemId $FolderPath

    # Check if the folder exists
    if ($null -eq $folder) {
        Write-Error 'Folder not found.'
        return
    }

    # Get the items in the folder
    $items = Get-MgDriveListItem -SiteId $SiteId -DriveId $DriveId -ItemId $folder.Id

    # Filter the items to get only PDF files
    $pdfFiles = $items | Where-Object { $_.File -and $_.Name -like '*.pdf' }

    # Output the PDF files
    $pdfFiles | ForEach-Object { Write-Output "Name: $($_.Name), ID: $($_.Id)" }

    # If the Recursive switch is set, get the PDF files in the subfolders
    if ($Recursive) {
        $subfolders = $items | Where-Object { $_.Folder }

        $subfolders | ForEach-Object {
            Get-PdfFilesInSharePoint -SiteId $SiteId -DriveId $DriveId -FolderPath $_.Id -Recursive
        }
    }
}

# Function to extract all of the UNIQUE Placeholders from a Confluence page storage format, the placeholders are in the format of &lt;&lt;Tsfdalsdkfj&gt;&gt; - read the confluence storage data from file and return an array of unique placeholders
function Get-OSMPlaceholdersJira {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PATH_TO_STORAGE_EXPORTS,
        [Parameter(Mandatory = $false)]
        [array]$PATTERNS_TO_FIND
    )
    if (-not $PATTERNS_TO_FIND) {
        $PATTERNS_TO_FIND = @('&lt;&lt;.*?&gt;&gt;', 'zoak-osm.([^\s,]+)', '([^\s,]+)to(.*)be(.*)replaced([^\s,]+)')
        Write-Debug "No pattern provided, using default: $PATTERNS_TO_FIND"
    }
    Write-Debug "Checking path $PATH_TO_STORAGE_EXPORTS for files..."
    # Check if the directory exists and contains files
    if (-not (Test-Path $PATH_TO_STORAGE_EXPORTS)) {
        Write-Debug "Directory does not exist or is empty: $PATH_TO_STORAGE_EXPORTS"
        return
    }
    # For each file in the directory, get the content and extract the placeholders
    $PLACEHOLDERS = @()
    $CLEAN_FILES = @()
    Get-ChildItem -Path $PATH_TO_STORAGE_EXPORTS -Recurse -Filter *.json | ForEach-Object {
        $FILE = $_
        $content = Get-Content $FILE.FullName
        $PATTERNS_TO_FIND | ForEach-Object {
            $placeholder = $content | Select-String -Pattern $_ -AllMatches | ForEach-Object { $_.Matches.Value } | Sort-Object -Unique
            Write-Debug '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'
            if ($placeholder) {
                $placeholder | ForEach-Object { 
                    # Write output in red
                    Write-Host "#### PLACEHOLDER FOUND!!! See: $($FILE.FullName): $_" -ForegroundColor Red
                    $PLACEHOLDERS += , ($($FILE.NAME), $_) }
            }
            else {
                Write-Debug "No placeholders found in file: $($FILE.FullName)"
                $CLEAN_FILES += $FILE
            }
            Write-Debug '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'
        }
    }
    Write-Debug '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'
    Write-Debug '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'
    Write-Debug 'CLEAN FILES:'
    $CLEAN_FILES | ForEach-Object { Write-Debug $_.FullName }
    Write-Debug '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'
    Write-Debug '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'
    Write-Debug 'FULL LIST:'
    $PLACEHOLDERS | ForEach-Object { Write-Debug "$($_[0]): $($_[1])" }
    Write-Debug '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'
    Write-Debug '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'
}

# Function to create Confluence Page in Storage Format based on template, for viewing SharePoint Document (embedded in Confluence)
function New-ConfluencePolicyViewerSharePoint {
    param (
        [Parameter(Mandatory = $false)]
        [string]$PATH_TO_TEMPLATE = "$env:AtlassianPowerKit_PROFILE_NAME\templates\confluence\$env:AtlassianPowerKit_PROFILE_NAME-GRCosm-SharePointViewer-Template.confluence",
        [Parameter(Mandatory = $true)]
        [string]$PATH_TO_SHAREPOINT_DOCUMENT,
        [Parameter(Mandatory = $true)]
        [string]$PATH_TO_OUTPUT
    )
    Connect-MgGraphScoped -RequiredScopes $MS_GRAPH_SCOPES

    # Read the template
    $TEMPLATE = Get-Content $PATH_TO_TEMPLATE
    # Replace the placeholders
    $CONFLUENT_POLICY_VIEWER_PLACEHOLDER_MAP = @{
        'SHAREPOINT_EMBED_URL' = $SHAREPOINT_EMBED_URL
    }
    
    # Write the output
    $TEMPLATE | Set-Content $PATH_TO_OUTPUT
}


# Function to generate Statement of Applicability Confluence Pages
function Convert-JIRAFilterToConfluencePage {
    param (
        [Parameter(Mandatory = $false)]
        [string]$PATH_TO_BACKUP = "$env:AtlassianPowerKit_PROFILE_NAME\snapshots\confluence\SoA\",
        [Parameter(Mandatory = $false)]
        [string]$PATH_TO_TEMPLATE,
    
    )
}