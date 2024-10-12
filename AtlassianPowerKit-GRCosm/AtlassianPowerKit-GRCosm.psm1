$ErrorActionPreference = 'Stop'; $DebugPreference = 'Continue'
<#
.SYNOPSIS
    Atlassian Cloud PowerShell Module for handy functions to interact with Attlassian Cloud APIs.

.LINK
GitHub: https://github.com/markz0r/AtlassianPowerKit

#>


# Create class for FILE_INFO_ARRAY
class ConfluenceMetadataObject {
    [string] $FILE_NAME
    [string] $VIEW_URL
    [string] $DOWNLOAD_URL
    [string] $UNIQUE_ID
    [string] $EMBED_URL
    [string] $LOCAL_ID
    [string] $MACRO_ID
    [string] $CONFLUENCE_PARENT
    [string[]] $LABELS
    
    # Shared initializer method
    [void] Init([hashtable]$Properties) {
        foreach ($Property in $Properties.Keys) {
            $this.$Property = $Properties.$Property
        }
    }
    # Constructors
    ConfluenceMetadataObject() { $this.Init(@{}) }
    ConfluenceMetadataObject([hashtable]$Properties) {
        $this.Init($Properties)
    }
    # Contructor with named parameters
    ConfluenceMetadataObject([string]$FILE_NAME, [string]$VIEW_URL, [string]$DOWNLOAD_URL, [string]$UNIQUE_ID, [string]$EMBED_URL, [string]$LOCAL_ID, [string]$MACRO_ID, [string]$CONFLUENCE_PARENT, [string[]]$LABELS) {
        $this.Init(@{
                FILE_NAME         = $FILE_NAME
                VIEW_URL          = $VIEW_URL
                DOWNLOAD_URL      = $DOWNLOAD_URL
                UNIQUE_ID         = $UNIQUE_ID
                EMBED_URL         = $EMBED_URL
                LOCAL_ID          = $LOCAL_ID
                MACRO_ID          = $MACRO_ID
                CONFLUENCE_PARENT = $CONFLUENCE_PARENT
                LABELS            = $LABELS
            })
    }
}

#  funciton to install, update, and import POWERSHELL_MODULE_DEPS
function Install-AtlassianPowerKitGRCosmDependencies {
    param (
        [Parameter(Mandatory = $false)]
        [switch] $InstallDependencies = $false
    )
    if ($InstallDependencies) {
        Write-Debug "Installing dependencies: $POWERSHELL_MODULE_DEPS"
        $POWERSHELL_MODULE_DEPS | ForEach-Object {
            if (-not (Get-Module -ListAvailable -Name $_)) {
                Install-Module -Name $_ -Force -Scope CurrentUser -AllowClobber
            }
            else {
                Write-Debug "Module $_ already installed"
            }
            # Provide warning message to user if module has update available
            $module = Get-Module -ListAvailable -Name $_ | Sort-Object Version -Descending
            $latest_version = Find-Module -Name $_ | Select-Object -ExpandProperty Version
            $module | ForEach-Object { 
                if ($_.Version -lt $latest_version) {
                    Write-Warning "Module $_ has an update available. Run 'Update-Module -Name $_' to update."
                    Write-Debug "Module $_ version: $($_.Version), available version: $latest_version"
                }
            }
            # If there area multiple versions of the module installed, advise user how to uninstall only the older version/s
            # Get the latest installed version of the module
            $OLDER_VERSIONS = Get-Module -ListAvailable -Name $_ | Sort-Object Version -Descending | Select-Object -Skip 1
            if ($OLDER_VERSIONS) {
                #Write-Warning "Multiple versions of module $_ are installed. Run 'Uninstall-Module -Name $_ -RequiredVersion ' to uninstall the older version/s."
                $OLDER_VERSIONS | ForEach-Object { 
                    #Write-Debug "Older version: $($_.Version)" 
                    Write-Debug "MULTIPLE VERSIONS of $($_.Name), [$OLDER_VERSIONS]"
                    Write-Debug "Uninstall-Module -Name $($_.Name) -RequiredVersion $($_.Version) -Force"
                }
            }
            # Import the latest available version of the module into the current session
            Import-Module -Name $_
            Write-Debug "...  $_ imported successfully"
        }
    }
    else {
        try {
            $POWERSHELL_MODULE_DEPS | ForEach-Object {
                Import-Module -Name $_
                Write-Debug "...  $_ imported successfully"
            }
        }
        catch {
            Write-Error "Error importing module $_ - Run 'Install-AtlassianPowerKitGRCosmDependencies -InstallDependencies' to install dependencies"
        }
    }

}

function Create-ConfluencePageStructure {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_SPACE_KEY,
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_PARENT_PAGE_ID,
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_PAGE_STRUCTURE_JSON,
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_PAGE_TEMPLATE_PATH
    )
    # Ensure the AtlasianPowerKit-GRCosm dependencies are installed
    Install-AtlassianPowerKitGRCosmDependencies -InstallDependencies
    # Check template file exists
    if (-not (Test-Path $CONFLUENCE_PAGE_TEMPLATE_PATH)) {
        Write-Error "Create-ConfluencePageStructure: Template file not found: $CONFLUENCE_PAGE_TEMPLATE_PATH"
    }

}

function Update-GRCosmConfRegister {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_SPACE_KEY,
        [Parameter(Mandatory = $true)]
        [string]$CONF_PAGE_ID,
        [Parameter(Mandatory = $true)]
        [string]$FILTER_ID,
        [Parameter(Mandatory = $true)]
        [string]$REGISTER_STORAGE_TEMPLATE_PATH
    )
    # Ensure the AtlasianPowerKit-GRCosm dependencies are installed
    

    # Check template file exists
    if (-not (Test-Path $REGISTER_STORAGE_TEMPLATE_PATH)) {
        Write-Error "Update-GRCosmConfRegister: Template file not found: $REGISTER_STORAGE_TEMPLATE_PATH"
    }
    # Backup the Confluence page storage format
    $BACKUP_FILE = Export-ConfluencePageStorageFormat -CONFLUENCE_SPACE_KEY $CONFLUENCE_SPACE_KEY -CONFLUENCE_PAGE_ID $CONF_PAGE_ID
    Write-Debug "Backup file: $BACKUP_FILE"

    # Get JIRA filter data - Fields are determined by the JIRA filter
    $CONF_REGISTER_TABLE_DATA = Get-JiraFilterResultsAsConfluenceTable -FILTER_ID $FILTER_ID
    $UPDATED_PAGE_STORAGE_DATA = Get-Content $REGISTER_STORAGE_TEMPLATE_PATH
    # Replate 'GRCOSM_REGISTER_TABLE_DATA' with $CONF_REGISTER_TABLE_DATA
    $UPDATED_PAGE_STORAGE_DATA = $UPDATED_PAGE_STORAGE_DATA -replace 'GRCOSM_REGISTER_TABLE_DATA', $CONF_REGISTER_TABLE_DATA

}

# Authenticate to MS Graph using interactive login, scope is for listing SharePoint documents and retrieving the unique identifier
function Connect-MgGraphScoped {
    param(
        [Parameter(Mandatory = $true)]
        [string[]] $RequiredScopes,
        [Parameter(Mandatory = $true)]
        [string] $TenantName,
        [Parameter(Mandatory = $false)]
        [switch] $ReAuth = $false
    )

    # Get the current context
    $context = Get-MgContext

    # Check if the context and its scopes are not null
    if (($null -ne $context) -and ($null -ne $context.Scopes) -and (-not $ReAuth)) {
        # Check if the context's scopes include all the required scopes
        $hasRequiredScopes = ($RequiredScopes | ForEach-Object { $context.Scopes -contains $_ } | Where-Object { $_ -eq $false } | Measure-Object | Select-Object -ExpandProperty Count) -eq 0

        if (-not $hasRequiredScopes) {
            # If the context doesn't have all the required scopes, authenticate again
            Disconnect-MgGraph -ErrorAction SilentlyContinue
            Connect-MgGraph -Scopes $RequiredScopes -TenantId $TenantName -NoWelcome
        }
    }
    else {
        # If there's no context or its scopes are null, authenticate

        Connect-MgGraph -Scopes $RequiredScopes -TenantId $TenantName
    }
    Get-MgContext
}

function Get-SharePointFileMetadata {
    param (
        [Parameter(Mandatory = $true)]
        [string]$TenantName,
        [Parameter(Mandatory = $true)]
        [string]$SiteName,
        [Parameter(Mandatory = $true)]
        [string]$FOLDER_PATH_OR_NAME,
        [Parameter(Mandatory = $false)]
        [string]$SOURCE_FILENAME,
        [Parameter(Mandatory = $false)]
        [string]$REGEX_MULTI_SEARCH = $false
    )
    [ConfluenceMetadataObject[]] $CONFLUENCE_METADATA_OBJECTS = @()
    # Declare FILE_ITEMS as an array of objects
    [object[]] $FILE_ITEMS = @()
    
    $SiteWebUrl = "https://$TenantName.sharepoint.com/sites/$SiteName"
    Connect-MgGraphScoped -RequiredScopes $MS_GRAPH_SCOPES -TenantName $TenantName
    # Get the site ID by the site name
    $Site = Get-MgSite -Search "$SiteWebUrl"
    # Display all sites and their properties
    $SiteId = $Site.Id
    if (-not $SiteId) {
        Write-Error "Site not found: $SiteName"
    }
    else {
        Write-Debug "SiteId: $SiteId (SiteName: $SiteName)"
    }
    # Check if the site exists
    $Site = Get-MgSite -SiteId $SiteId
    # Ensure the necessary Microsoft Graph connection
    $Drive = Get-MgSiteDrive -SiteId $SiteId
    # Validate the $Drive.DriveType = 'documentLibrary'
    $DriveId = $Drive.Id
    if (-not $DriveId) {
        Write-Error "Drive not found: $DriveId"
    }
    else {
        Write-Debug "DriveId: $DriveId"
    }
    #Encode the folder name
    # Get the string after the last '/' in the folder path (if there are any '/'s)
    $FOLDER_NAME = $FOLDER_PATH_OR_NAME.Split('/')[-1]
    Write-Debug "Folder Name: $FOLDER_NAME"

    $folder = Search-MgDrive -DriveId $DriveId -Q $FOLDER_NAME | Where-Object { $_.Name -eq $FOLDER_NAME }
    Write-debug 'Folder found: '
    Write-Debug $folder.ToJson($null, 'IncludeAll')

    # If more than one folder is found, select the first one
    if ($folder.Count -gt 1) {
        Write-Debug 'Folders found: '
        $folder | ForEach-Object { Write-Debug "Folder: $($_.Name), ID: $($_.Id), WebUrl: $($_.WebUrl)" }
        Write-Warning 'More than one folder found. Selecting the first one.'
        $folder = $folder[0]
    }
    # Check if the folder exists
    if ($null -eq $folder) {
        Write-Error 'Folder not found.'
        return
    }
    else {
        Write-Debug "Folder: $($folder.Name), ID: $($folder.Id), WebUrl: $($folder.WebUrl)"
    }
    if ($REGEX_MULTI_SEARCH) {
        Write-Debug "Searching for files with search string: $SOURCE_FILENAME and regex: $REGEX_MULTI_SEARCH"
        $FILE_ITEMS = Search-MgDriveItem -DriveId $DriveId -DriveItemId $folder.Id -Q $SOURCE_FILENAME | Where-Object { $_.Name -match $REGEX_MULTI_SEARCH }
        Write-Debug "File Items: $($file_items.Count)"
        if ($($file_items.Count) -eq 0) {
            Write-Error "No files found: $SOURCE_FILENAME with regex: $REGEX_MULTI_SEARCH"
        }
    }
    else {
        $FILE_ITEMS = Search-MgDriveItem -DriveId $DriveId -DriveItemId $folder.Id -Q $SOURCE_FILENAME | Where-Object { $_.Name.EndsWith($SOURCE_FILENAME) }
        Write-Debug "File Items: $($file_items.Count)"
        if ($($file_items.Count) -eq 0) {
            Write-Debug 'Query: Search-MgDriveItem -DriveId $DriveId -DriveItemId $($folder.Id) -Q $SOURCE_FILENAME -Property name, Id, File.... | Where-Object { $_.Name -match $SOURCE_FILENAME }'
            Write-Error 'No files found: $SOURCE_FILENAME'
        }
        elseif ($($file_items.Count) -gt 1) {
            Write-Warning "More than one file found: $($file_items.Count)"
            Write-Debug 'Query: Search-MgDriveItem -DriveId $DriveId -DriveItemId $($folder.Id) -Q $SOURCE_FILENAME -Property name, Id, File, .... | Where-Object { $_.Name -match $SOURCE_FILENAME }'
            $file_items | ForEach-Object { Write-Debug '##############################################'; Write-Debug $($_.ToJSON($null, 'IncludeAll')); Write-Debug '##############################################' }
            Write-Debug 'Defaulting to the first file'
            $FILE_ITEM = $file_items[0]
        }
    }
    $FILE_ITEMS | ForEach-Object {
        $FILE_ITEM = Get-MgDriveItem -DriveId $DriveId -DriveItemId $($_.Id)
        $CONFLUENCE_METADATA_OBJECTS += [ConfluenceMetadataObject]::new(@{
                FILE_NAME    = $($FILE_ITEM.Name)
                VIEW_URL     = $($FILE_ITEM.WebUrl)
                DOWNLOAD_URL = $($($FILE_ITEM)['@microsoft.graph.downloadUrl'])
                UNIQUE_ID    = $DOWNLOAD_URL.Split('UniqueId=')[1].Split('&')[0]
                EMBED_URL    = "https://$TenantName.sharepoint.com/sites/$SiteName/_layouts/15/embed.aspx?UniqueId=$UNIQUE_ID"
                LOCAL_ID     = $AC_LOCAL_ID
                MACRO_ID     = $AC_MACRO_ID
            })
        # Write-Debug $CONFLUENCE_METADATA_OBJECT
        # $actualPath = $FILE_ITEM.ParentReference.Path -replace '^.*root:', ''
        # $fullPath = Join-Path -Path $actualPath -ChildPath $FILE_ITEM.Name
        # $FILE_ITEM_PATH = Join-Path -Path "sites/$SiteName/Shared Documents/" -ChildPath $fullPath
        # $FILE_ITEM_PATH.GetType()
        # Write-Debug $FILE_ITEM_PATH
    }
    return $CONFLUENCE_METADATA_OBJECTS
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

# Function to extract all of the UNIQUE Placeholders from a Confluence page storage format, the placeholders are in the format of &lt;&lt;Tsfdalsdkfj&gt;&gt; - read the confluence storage data from file and return an array of unique placeholders
function Get-OSMPlaceholdersConfluence {
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
    Write-Debug "Getting placeholders from files in: $($(Get-ChildItem -Recurse -Path $PATH_TO_STORAGE_EXPORTS -Filter *.xml ).FullName)"
    $PLACEHOLDERS = @()
    $CLEAN_FILES = @()
    Get-ChildItem -Path $PATH_TO_STORAGE_EXPORTS -Recurse -Filter *.xml | ForEach-Object {
        $FILE = $_
        $content = Get-Content $FILE.FullName
        $PATTERNS_TO_FIND | ForEach-Object {
            $placeholder = $content | Select-String -Pattern $_ -AllMatches | ForEach-Object { $_.Matches.Value } | Sort-Object -Unique
            if ($_ -eq '&lt;&lt;.*?&gt;&gt;') {
                if ($placeholder) {
                    $placeholder_ref = $placeholder | ForEach-Object { $_ -replace '&lt;&lt;', 'PLACEHOLDER_' -replace '&gt;&gt;', ' ' }
                    $placeholder = "$placeholder_ref ($placeholder)"
                }
            }
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

# Function to build a CSV file by 

# Function to create Confluence Page in Storage Format based on template, for viewing SharePoint Document (embedded in Confluence)
function New-ConfluencePolicyViewerSharePoint {
    param (
        [Parameter(Mandatory = $false)]
        [string]$PATH_TO_TEMPLATE = 'templates\confluence\GRCosm-SharePointViewer-Template.confluence',
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_PARENT,
        [Parameter(Mandatory = $true)]
        [ConfluenceMetadataObject]$CONFLUENCE_METADATA_OBJECT,
        [Parameter(Mandatory = $false)]
        [string]$PATH_TO_OUTPUT = "$env:AtlassianPowerKit_PROFILE_NAME\snapshots\confluence\latest\"
    )
    # Read the template
    try {
        $TEMPLATE = Get-Content $PATH_TO_TEMPLATE
    }
    catch {
        Write-Error "Error reading template: $PATH_TO_TEMPLATE"
    }
    # Add CONFULENCE_PARENT to ConfluenceMetadataObject
    $CONFLUENCE_METADATA_OBJECT.CONFLUENCE_PARENT = $CONFLUENCE_PARENT
    # Check for null values in ConfluenceMetadataObject Properties
    $CONFLUENCE_METADATA_OBJECT | Get-Member -MemberType Properties | ForEach-Object {
        $property = $_.Name
        $value = $CONFLUENCE_METADATA_OBJECT.$property
        if (-not $value) {
            Write-Error "Property $property is null"
        }
        Write-Debug "$property : $value"
    }
    # Create variable for the basename of the file from the ConfluenceMetadataObject.FILE_NAME, remove the file extension ensuring handling filename with multiple '.'s, throw error if number of characters removed is not 2-5 characters
    $BASENAME = $CONFLUENCE_METADATA_OBJECT.FILE_NAME -replace '\.[^.]*$', ''
    $CHARS_REMOVED = $CONFLUENCE_METADATA_OBJECT.FILE_NAME.Length - $BASENAME.Length
    if ($CHARS_REMOVED -lt 2 -or $CHARS_REMOVED -gt 5) {
        Write-Debug "BASENAME from FILE_NAME: $CONFLUENCE_METADATA_OBJECT.FILE_NAME"
        Write-Warning "Extension removed was abnormal, check FILE_NAME: $CONFLUENCE_METADATA_OBJECT.FILE_NAME"
    }
    # Create array of placeholders in the template which can be identified by pattern: '{{ .*? }}'
    $PLACEHOLDERS = $TEMPLATE | Select-String -Pattern '{{ .*? }}' -AllMatches | ForEach-Object { $_.Matches.Value } | Sort-Object -Unique
    Write-Debug "PLACEHOLDERS: $($PLACEHOLDERS)"
    # If there are PLACEHOLDERS that are not defined in the ConfluenceMetadataObject, throw an error
    $PLACEHOLDERS | ForEach-Object {
        $placeholder = $_
        $value = $CONFLUENCE_METADATA_OBJECT.$($_ -replace '{{ ', '' -replace ' }}', '')
        if (-not $value) {
            Write-Error "Placeholder $placeholder is not defined in ConfluenceMetadataObject"
        }
    }
    # Replace the placeholders in the template with the values from the ConfluenceMetadataObject
    $TEMPLATE_INPUT_ARRAY = $TEMPLATE | ForEach-Object {
        $line = $_
        $PLACEHOLDERS | ForEach-Object {
            $placeholder = $_
            $value = $CONFLUENCE_METADATA_OBJECT.$($_ -replace '{{ ', '' -replace ' }}', '')
            $line = $line -replace $placeholder, $value
        }
        $line
    }
    # Write the output to a file and console as debug and advise user of the file location
    $OUTPUT_FILE = "$PATH_TO_OUTPUT\$($CONFLUENCE_METADATA_OBJECT.FILE_NAME).confluence"
    # Write the TEMPLATE_INPUT_ARRAY to the OUTPUT_FILE, create the directory if it does not exist and overwrite the file if it does
    $TEMPLATE_INPUT_ARRAY | Set-Content -Path $OUTPUT_FILE -Force
}


# Function to generate SharePoint - Confluence object mapping
function New-SharePointConfluenceObjectMapping {
    param (
        [Parameter(Mandatory = $false)]
        [string]$PATH_TO_OUTPUT = "$env:AtlassianPowerKit_PROFILE_NAME\AtlasianPowerKit-GRCosm\$env:AtlassianPowerKit_PROFILE_NAME-config.json",
        [Parameter(Mandatory = $true)]
        [string]$TenantName,
        [Parameter(Mandatory = $true)]
        [string]$SiteName,
        [Parameter(Mandatory = $true)]
        [string]$FOLDER_NAME,
        [Parameter(Mandatory = $true)]
        [string]$CANDIDATE_FILE_PATTERN
    )
    # Find all files in the SharePoint folder that match the CANDIDATE_FILE_PATTERN, then call Get-SharePointFileMetadata to get the metadata for each file
    $SHAREPOINT_FILES = Get-SharePointFileMetadata -TenantName $TenantName -SiteName $SiteName -FOLDER_PATH_OR_NAME $FOLDER_NAME -SOURCE_FILENAME $CANDIDATE_FILE_PATTERN
}

#Install-AtlassianPowerKitGRCosmDependencies
if ($ReAuth) {
    if (!$TenantName) {
        $TenantName = Read-Host -Prompt 'Enter the Tenant Name'
    }
    Connect-MgGraphScoped -RequiredScopes $MS_GRAPH_SCOPES -TenantName $TenantName
}

# Funtion to 