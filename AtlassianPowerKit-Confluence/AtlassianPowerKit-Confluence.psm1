$ErrorActionPreference = 'Stop'; $DebugPreference = 'Continue'
<#
.SYNOPSIS
    Atlassian Cloud PowerShell Module for handy functions to interact with Attlassian Cloud APIs.

.LINK
GitHub: https://github.com/markz0r/AtlassianPowerKit

#>
# Function to export Confluence page to a file Word document, with templating
function Export-ConfluencePageWord {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_SPACE_KEY,
        [Parameter(Mandatory = $true)]
        [int64]$CONFLUENCE_PAGE_ID,
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_PAGE_TITLE,
        [Parameter(Mandatory = $false)]
        [string]$TEMPLATE_FILEPATH = ".\$($env:AtlassianPowerKit_PROFILE_NAME)\$($env:AtlassianPowerKit_PROFILE_NAME)_Document_Template.dotx"
    )
    $CONFLUENCE_PAGE_TITLE = $CONFLUENCE_PAGE_TITLE -replace ' ', ''
    $CONFLUENCE_PAGE_TITLE = $CONFLUENCE_PAGE_TITLE -replace '[\\\/\:\*\?\"\<\>\|]', ''
    $CONFLUENCE_PAGE_ENDPOINT = "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/wiki/exportword?pageId=$($CONFLUENCE_PAGE_ID)"
    $directoryString = ".\$($env:AtlassianPowerKit_PROFILE_NAME)\$CONFLUENCE_SPACE_KEY\CONFLUENCE_WORD_EXPORTS"
    if (-not (Test-Path $directoryString)) {
        New-Item -ItemType Directory -Path $directoryString -Force
    }
    $directoryPath = Get-Item -Path $directoryString
    if (-not (Test-Path $TEMPLATE_FILEPATH)) {
        Write-Error "Template file does not exist: $TEMPLATE_FILEPATH"
    }
    $TEMPLATE_FILE_NAME = $(Get-Item -Path $TEMPLATE_FILEPATH).FullName
    $FILE_NAME = "$($directoryPath.FullName)\$CONFLUENCE_PAGE_TITLE.doc"    
    try {
        $response = Invoke-WebRequest -Uri $CONFLUENCE_PAGE_ENDPOINT -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get
        # Save the content directly to the file
        [System.IO.File]::WriteAllBytes($FILE_NAME, $response.Content)
    }
    catch {
        Write-Error "Exception.Message: $($_.Exception.Message)"
    }
    $FILE_STRING = "$($directoryPath.FullName)\$CONFLUENCE_PAGE_TITLE.doc"
    $FILE_NAME = $(get-item -Path $FILE_STRING).FullName
    Write-Debug "Confluence page exported to: $FILE_NAME"
    Write-Debug "Applying template: $TEMPLATE_FILE to $FILE_NAME..."
    try {
        $wordApp = New-Object -ComObject Word.Application
        #$wordApp.Visible = $false
        $wordApp2 = New-Object -ComObject word.application
        #$wordApp2.visible = $false
        Write-Debug '   - Converting to docx...'
        $doc = $wordApp.Documents.Open($FILE_NAME)
        # Save as docx
        $newDoc = $doc.Convert()
        $newDoc.SaveAs2("$($FILE_NAME)x", 16)
        $doc.Close()
        $newDoc.Close()
        Write-Debug '   - Prepping template...'
        # Add-Type -AssemblyName office
        # [ref]$SaveFormat = 'microsoft.office.interop.word.WdSaveFormat' -as [type]
        $sourceDoc = $wordApp.Documents.Open("$($FILE_NAME)x")
        # Check if the template file exists
        ################# Clean up and get Copy of the source document
        # Select from the beginning of the document to the end the second heading level 1
        $what = 11 # wdGoToHeading https://learn.microsoft.com/en-us/office/vba/api/word.wdgotoitem
        $which = 1 # wdGoToAbsolute https://learn.microsoft.com/en-us/office/vba/api/word.wdgotoitem
        $count = 2
        #$wordApp.Activate()
        $rangeEnd = $sourceDoc.GoTo($what, $which, $count)
        $selection = $wordApp.Selection
        $selection.SetRange(0, $rangeEnd.Start)
        $selection.Delete()
        # Select remaining text and copy it
        $range = $sourceDoc.Range()
        $range.Copy()
        #################
        ################# Paste the copied text into the new document based on the template
        $templateDoc = $wordApp2.Documents.Add($TEMPLATE_FILE_NAME)
        #$wordApp2.Activate()
        $what = 1 # wdGoToPage https://learn.microsoft.com/en-us/office/vba/api/word.wdgotoitem
        $which = 1 # wdGoToAbsolute https://learn.microsoft.com/en-us/office/vba/api/word.wdgotoitem
        $count = 4
        $selection = $templateDoc.GoTo($what, $which, $count)
        # Paste the copied text from range.Copy() into the template
        $selection.Paste()
        #################
        ################# Clean up the templated document
        $STRINGS_TO_REMOVE = @('﻿﻿')
        $STRINGS_TO_REMOVE | ForEach-Object {
            $templateDoc.Content.Find.Execute($_, $false, $false, $false, $false, $false, $true, 1, $true, '', 2)
        }  
        
        #################
        ################# Save the new document
        $templateDoc.SaveAs("$directoryPath\$CONFLUENCE_PAGE_TITLE-Templated.docx")
        # Also print as PDF
        $templateDoc.SaveAs("$directoryPath\$CONFLUENCE_PAGE_TITLE-Templated.pdf", 17)
        $sourceDoc.Close()
        $templateDoc.Close()
    }
    catch {
        Write-Debug 'AtlassianPowerKit-Confluence.psm1:Export-ConfluencePageWord - Errored!'
        Write-Error "Exception.Message: $($_.Exception.Message)"
    }
    finally {
        $wordApp.Quit()
        $wordApp2.Quit()
    }
}

# Function to export Confluence Child Pages to word documents
function Export-ConfluencePageWordForChildren {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_SPACE_KEY,
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_PARENT_PAGE_TITLE
    )
    $PARENT_PAGE = Get-ConfluencePageByTitle -CONFLUENCE_SPACE_KEY $CONFLUENCE_SPACE_KEY -CONFLUENCE_PAGE_TITLE $CONFLUENCE_PARENT_PAGE_TITLE
    if (!$PARENT_PAGE) {
        throw "Parent page does not exist: $CONFLUENCE_PARENT_PAGE_TITLE"
    }
    $PARENT_PAGE_ID = $PARENT_PAGE.results[0].id
    Write-Debug "Parent Page ID: $PARENT_PAGE_ID, Title: $CONFLUENCE_PARENT_PAGE_TITLE - getting child pages..."
    $CHILD_PAGES = $(Get-ConfluenceChildPages -CONFLUENCE_SPACE_KEY $CONFLUENCE_SPACE_KEY -PARENT_ID $PARENT_PAGE_ID)
    Write-Debug "Found $($CHILD_PAGES.results.count) child pages..."
    $CHILD_PAGES.results | ForEach-Object {
        $CONFLUENCE_PAGE_ID = $_.id
        Export-ConfluencePageStorageFormat -CONFLUENCE_SPACE_KEY $CONFLUENCE_SPACE_KEY -CONFLUENCE_PAGE_ID $CONFLUENCE_PAGE_ID
    }
}

# Function to get a Confluence page's storage format export by the page ID, writing to a file in ./PROFILE_NAME/spacekey/pageid_<YYYMMDD-HHMMSS>.xml
function Export-ConfluencePageStorageFormat {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_SPACE_KEY,
        [Parameter(Mandatory = $true)]
        [int64]$CONFLUENCE_PAGE_ID
    )
    $CONFLUENCE_PAGE_ENDPOINT = "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/wiki/api/v2/pages/$($CONFLUENCE_PAGE_ID)?body-format=storage"
    Write-Debug "Exporting page storage format for page ID: $CONFLUENCE_PAGE_ID ... URL: $CONFLUENCE_PAGE_ENDPOINT ..."
    try {
        Write-Debug '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'
        Write-Debug "Confluence Page exporting: $CONFLUENCE_PAGE_ENDPOINT"
        $REST_RESULTS = Invoke-RestMethod -Uri $CONFLUENCE_PAGE_ENDPOINT -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get
        Write-Debug $REST_RESULTS.getType()
        Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
        Write-Debug '++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'
    } 
    catch {
        Write-Debug ($_ | Select-Object -Property * -ExcludeProperty psobject | Out-String)
        Write-Error "Error updating field: $($_.Exception.Message)"
    }
    
    $CONFLUENCE_PAGE_STORAGE = $REST_RESULTS.body.storage.value
    $CONFLUENCE_PAGE_TITLE = $REST_RESULTS.title
    $CONFLUENCE_PAGE_TITLE_ENCODED = [System.Web.HttpUtility]::UrlEncode($CONFLUENCE_PAGE_TITLE)
    $CURRENT_DATE_TIME = Get-Date -Format 'yyyyMMdd-HHmmss'
    $FILE_NAME = ".\$($env:AtlassianPowerKit_PROFILE_NAME)\$CONFLUENCE_SPACE_KEY\$CONFLUENCE_PAGE_TITLE_ENCODED\$($CONFLUENCE_PAGE_TITLE_ENCODED)_$CURRENT_DATE_TIME.xml"
    if (-not (Test-Path ".\$($env:AtlassianPowerKit_PROFILE_NAME)\$CONFLUENCE_SPACE_KEY\$CONFLUENCE_PAGE_TITLE_ENCODED")) {
        New-Item -ItemType Directory -Path ".\$($env:AtlassianPowerKit_PROFILE_NAME)\$CONFLUENCE_SPACE_KEY\$CONFLUENCE_PAGE_TITLE_ENCODED"
    }
    # | Out-File -FilePath $FILE_NAME
    $CONFLUENCE_PAGE_STORAGE | Set-Content -Path $FILE_NAME -Encoding UTF8 -Force
    Write-Debug "Page storage format exported to: $FILE_NAME"
    return $FILE_NAME
}

# Function to export Confluence page storage format to a file for all child pages of a parent page
function Export-ConfluencePageStorageFormatForChildren {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_SPACE_KEY,
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_PARENT_PAGE_TITLE,
        [Parameter(Mandatory = $false)]
        [int]$DepthLimit = 0,
        [Parameter(Mandatory = $false)]
        [int]$DepthCount = 0
    )
    $PARENT_PAGE = Get-ConfluencePageByTitle -CONFLUENCE_SPACE_KEY $CONFLUENCE_SPACE_KEY -CONFLUENCE_PAGE_TITLE $CONFLUENCE_PARENT_PAGE_TITLE
    if (!$PARENT_PAGE) {
        throw "Parent page does not exist: $CONFLUENCE_PARENT_PAGE_TITLE"
    }
    $PARENT_PAGE_ID = $PARENT_PAGE.results[0].id
    Write-Debug "Parent Page ID: $PARENT_PAGE_ID, Title: $CONFLUENCE_PARENT_PAGE_TITLE, DepthCount: $DepthCount, DepthLimit: $DepthLimit - getting child pages..."
    $CHILD_PAGES = $(Get-ConfluenceChildPages -CONFLUENCE_SPACE_KEY $CONFLUENCE_SPACE_KEY -PARENT_ID $PARENT_PAGE_ID)
    Write-Debug "Found $($CHILD_PAGES.results.count) child pages..."
    $CHILD_PAGES.results | ForEach-Object {
        Write-Debug "Exporting page storage format for page ID: $($_.id)..."
        Export-ConfluencePageStorageFormat -CONFLUENCE_SPACE_KEY $CONFLUENCE_SPACE_KEY -CONFLUENCE_PAGE_ID $($_.id)
        if (($DepthLimit -eq 0) -or ($DepthCount -lt $DepthLimit)) {
            $DepthCount++
            Export-ConfluencePageStorageFormatForChildren -CONFLUENCE_SPACE_KEY $CONFLUENCE_SPACE_KEY -CONFLUENCE_PARENT_PAGE_TITLE $($_.title) -DepthLimit $DepthLimit -DepthCount $DepthCount
        }
    }
}

# FUNCTION to get Confluence page by ID
function Get-ConfluencePageByID {
    param (
        [Parameter(Mandatory = $true)]
        [int64]$CONFLUENCE_PAGE_ID
    )
    if (-not $CONFLUENCE_PAGE_ID -or $CONFLUENCE_PAGE_ID -eq 0) {
        $CONFLUENCE_PAGE_ID = read-host 'Enter Confluence Page ID'
    }
    $CONFLUENCE_PAGE_ENDPOINT = "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/wiki/api/v2/pages/$CONFLUENCE_PAGE_ID?body-format=storage"
    Write-Debug "Confluence Page ID: $CONFLUENCE_PAGE_ID"
    Write-Debug "Confluence Page Endpoint: $CONFLUENCE_PAGE_ENDPOINT"
    try {
        $REST_RESULTS = Invoke-RestMethod -Uri $CONFLUENCE_PAGE_ENDPOINT -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get
    }
    catch {
        Write-Debug ($_ | Select-Object -Property * -ExcludeProperty psobject | Out-String)
        Write-Error "Error updating field: $($_.Exception.Message)"
    }
    $REST_RESULTS | ConvertTo-Json -Depth 20
}

# Function get page by title
function Get-ConfluencePageByTitle {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_SPACE_KEY,
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_PAGE_TITLE
    )
    $CONFLUENCE_PAGE_TITLE_ENCODED = [System.Web.HttpUtility]::UrlEncode($CONFLUENCE_PAGE_TITLE)
    Write-Debug "Confluence Space Key: $CONFLUENCE_SPACE_KEY"
    Write-Debug "Confluence Page Title: $CONFLUENCE_PAGE_TITLE"
    Write-Debug "Confluence Page Title Encoded: $CONFLUENCE_PAGE_TITLE_ENCODED"
    $CONFLUENCE_PAGE_ENDPOINT = "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/wiki/api/v2/pages?spaceKey=$CONFLUENCE_SPACE_KEY&title=$CONFLUENCE_PAGE_TITLE_ENCODED&body-format=storage&expand=body.view,version"
    write-debug "Confluence Page Endpoint: $CONFLUENCE_PAGE_ENDPOINT"
    try {
        $REST_RESULTS = Invoke-RestMethod -Uri $CONFLUENCE_PAGE_ENDPOINT -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get
        #Write-Debug $REST_RESULTS.getType()
        Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
    }
    catch {
        Write-Debug ($_ | Select-Object -Property * -ExcludeProperty psobject | Out-String)
        Write-Error "Error updating field: $($_.Exception.Message)"
    }
    Write-Debug "Found $($REST_RESULTS.results.count) pages..."
    $REST_RESULTS
}

# Function to create a mapping of Confluence spaces and their IDs, that is accessible to all functions
function Get-ConfluenceSpaceList {
    $CONFLUENCE_SPACES_ENDPOINT = "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/wiki/api/v2/spaces"
    try {
        $REST_RESULTS = Invoke-RestMethod -Uri $CONFLUENCE_SPACES_ENDPOINT -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get -ContentType 'application/json'
    }
    catch {
        Write-Debug 'StatusCode:' $_.Exception.Response.StatusCode.value__
        Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
    }
    $REST_RESULTS | ConvertTo-Json -Depth 10
}

# function to get Confluence space properties by space ID, printing as json
function Get-ConfluenceSpacePropertiesBySpaceID {
    param (
        [Parameter(Mandatory = $false)]
        [string]$CONFLUENCE_SPACE_ID
    )
    if (-not $CONFLUENCE_SPACE_ID) {
        $CONFLUENCE_SPACE_ID = read-host 'Enter Confluence Space ID'
    }
    $CONFLUENCE_SPACE_ENDPOINT = "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/wiki/api/v2/spaces/$CONFLUENCE_SPACE_ID"
    try {
        $REST_RESULTS = Invoke-RestMethod -Uri $CONFLUENCE_SPACE_ENDPOINT -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get -ContentType 'application/json'
        Write-Debug $REST_RESULTS.getType()
        Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
    }
    catch {
        Write-Debug 'StatusCode:' $_.Exception.Response.StatusCode.value__
        Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
    }
    $REST_RESULTS
}

# Function to return child pages of a parent page
function Get-ConfluenceChildPages {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_SPACE_KEY,
        [Parameter(Mandatory = $true)]
        [int64]$PARENT_ID
    )
    $GET_CHILD_PAGE_ENDPOINT = "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/wiki/api/v2/pages/$PARENT_ID/children?limit=250"
    try {
        $REST_RESULTS = Invoke-RestMethod -Uri $GET_CHILD_PAGE_ENDPOINT -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get
        Write-Debug $REST_RESULTS.getType()
        Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
    }
    catch {
        Write-Debug 'StatusCode:' $_.Exception.Response.StatusCode.value__
        Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
    }
    $REST_RESULTS
}

# Function to remove all attachments from a Confluence page given the page ID and optionally and exclude list of attachment names
function Remove-AttachmentsFromConfPage {
    param (
        [Parameter(Mandatory = $true)]
        [int64]$CONFLUENCE_PAGE_ID,
        [Parameter(Mandatory = $false)]
        [array]$EXCLUDE_ATTACHMENT_NAMES
    )
    $CONFLUENCE_PAGE_ATTACHMENTS_ENDPOINT = "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/wiki/api/v2/pages/$CONFLUENCE_PAGE_ID/attachments"
    try {
        $REST_RESULTS = Invoke-RestMethod -Uri $CONFLUENCE_PAGE_ATTACHMENTS_ENDPOINT -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get
        Write-Debug $REST_RESULTS.getType()
        Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
    }
    catch {
        Write-Debug 'StatusCode:' $_.Exception.Response.StatusCode.value__
        Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
    }
    $REST_RESULTS.results | ForEach-Object {
        if ($EXCLUDE_ATTACHMENT_NAMES -contains $_.title) {
            Write-Debug "Excluding attachment: $($_.title)"
        }
        else {
            $CONFLUENCE_PAGE_ATTACHMENT_DELETE_ENDPOINT = "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/wiki/api/v2/attachments/$($_.id)"
            try {
                Write-Debug "Deleting attachment: $($_.title)"
                Invoke-RestMethod -Uri $CONFLUENCE_PAGE_ATTACHMENT_DELETE_ENDPOINT -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Delete
                Write-Debug $REST_RESULTS.getType()
                Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
            }
            catch {
                Write-Debug 'StatusCode:' $_.Exception.Response.StatusCode.value__
                Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
            }
        }
    }
}

# Function to set confluence space properties by space ID
function Set-ConfluenceSpacePropertyByID {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_SPACE_ID,
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_SPACE_PROPERTY_ID,
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_SPACE_PROPERTY_VALUE
    )
    $CONFLUENCE_SPACE_ENDPOINT = "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/wiki/api/v2/spaces/$CONFLUENCE_SPACE_ID"
    $CONFLUENCE_SPACE_PROPERTIES = @{
        key   = $CONFLUENCE_SPACE_PROPERTY_ID
        value = $CONFLUENCE_SPACE_PROPERTY_VALUE
    }
    try {
        $REST_RESULTS = Invoke-RestMethod -Uri $CONFLUENCE_SPACE_ENDPOINT -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Put -ContentType 'application/json' -Body $CONFLUENCE_SPACE_PROPERTIES
        Write-Debug $REST_RESULTS.getType()
        Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
    }
    catch {
        Write-Debug 'StatusCode:' $_.Exception.Response.StatusCode.value__
        Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
    }
    $REST_RESULTS
}

## INPROGRESS
# Function set Confluence page content using a storage format file and page ID
function Set-ConfluencePageContent {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_SPACE_KEY,
        [Parameter(Mandatory = $true)]
        [int64]$CONFLUENCE_PAGE_ID,
        [Parameter(Mandatory = $false)]
        [string]$CONFLUENCE_PAGE_STORAGE_FILE,
        [Parameter(Mandatory = $false)]
        [string]$CONFLUENCE_PAGE_STORAGE_FILE_CONTENT 
    )
    $VERSION_MESSAGE = "Updated via AtlassianPowerKit $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Get-ChildItem -Path . -Recurse -Filter 'Naive-ConflunceStorageValidator.psd1' | Import-Module
    $CONFLUENCE_PAGE_ENDPOINT = "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/wiki/api/v2/page/$($CONFLUENCE_PAGE_ID)"
    if ($CONFLUENCE_PAGE_STORAGE_FILE) {
        Write-Debug "Using file: $CONFLUENCE_PAGE_STORAGE_FILE to update page ID: $CONFLUENCE_PAGE_ID...ignoring -CONFLUENCE_PAGE_STORAGE_FILE_CONTENT if it was provided..."
        $CONFLUENCE_PAGE_STORAGE = Get-Content -Path $CONFLUENCE_PAGE_STORAGE_FILE -Raw
    }
    elseif ($CONFLUENCE_PAGE_STORAGE_FILE_CONTENT) {
        Write-Debug "Using content: $CONFLUENCE_PAGE_STORAGE_FILE_CONTENT to update page ID: $CONFLUENCE_PAGE_ID..."
        $CONFLUENCE_PAGE_STORAGE = $CONFLUENCE_PAGE_STORAGE_FILE_CONTENT
    }
    else {
        Write-Error 'You must provide either a file path to a storage format file or the content of the storage format file to update the page with parameter -CONFLUENCE_PAGE_STORAGE_FILE or -CONFLUENCE_PAGE_STORAGE_FILE_CONTENT'
    }
    Write-Debug 'Getting existing page title and version number...'
    $REST_RESULTS = Invoke-RestMethod -Uri $CONFLUENCE_PAGE_ENDPOINT -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get

    $CONFLUENCE_PAGE_TITLE = $REST_RESULTS.title
    $CURRENT_VERSION = $REST_RESULTS.version.number
    Write-Debug "Current Page Title: $CONFLUENCE_PAGE_TITLE, Current Version Info: "
    Write-Debug (ConvertTo-Json $REST_RESULTS.version -Depth 10)
    
    Test-ConfluenceStorageFormat -FilePath $CONFLUENCE_PAGE_STORAGE_FILE
    Write-Debug "Making backup of current page ID: $CONFLUENCE_PAGE_ID..."
    # Remove pretty formatting, whitepassed, and newlines
    $CONFLUENCE_PAGE_STORAGE = $CONFLUENCE_PAGE_STORAGE -replace '\s+', ' '
    $PAGE_PAYLOAD = @{
        id      = $CONFLUENCE_PAGE_ID
        version = @{
            number  = $CURRENT_VERSION + 1
            message = $VERSION_MESSAGE
        }
        status  = 'current'
        title   = "$CONFLUENCE_PAGE_TITLE"
        type    = 'page'
        body    = @{
            representation = 'storage'
            value          = $CONFLUENCE_PAGE_STORAGE
        }
    }
    $PAGE_PAYLOAD = $PAGE_PAYLOAD | ConvertTo-Json -Depth 20
    Write-Debug "Page Payload: $PAGE_PAYLOAD"
    try {
        #Invoke-RestMethod -Uri $CONFLUENCE_PAGE_ENDPOINT -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get
        Invoke-RestMethod -Uri $CONFLUENCE_PAGE_ENDPOINT  -Method Put -ContentType 'application/json' -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Body $PAGE_PAYLOAD
    }
    catch {
        Write-Debug 'StatusCode:' $_.ToString()
        Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
    }
}
# Function to take a CONFLUENCE_PAGE_ID, validate it is in 'YYYY (.*)' format, get a list of Child Pages, and if it doesn't already exist, create a new child page with the title 'YYYY[1-12] (.*)', move any existing child pages that title match 'YYYYMM.*' to the new child page, and then move the new child page to the top of the list
function Set-ConfluenceYearMonthStructure {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_SPACE_KEY,
        [Parameter(Mandatory = $true)]
        [int64]$CONFLUENCE_PAGE_ID
    )
    # If the page title does not match 'YYYY (.*)', throw an error and advise the user of this functions purpose
    $TEMP_FILE = New-TemporaryFile

    $CONFLUENCE_PAGE = Get-ConfluencePageByTitle -CONFLUENCE_SPACE_KEY $CONFLUENCE_SPACE_KEY -CONFLUENCE_PAGE_ID $CONFLUENCE_PAGE_ID
    if (!$CONFLUENCE_PAGE) {
        throw "Page does not exist: $CONFLUENCE_PAGE_ID"
    }
    $CONFLUENCE_PAGE_TITLE = $CONFLUENCE_PAGE.title
    if ($CONFLUENCE_PAGE_TITLE -notmatch '^\d{4} (.*)') {
        throw "Confluence page title does not match 'YYYY (.*)' format. This function is intended to be used on pages with titles in the format 'YYYY (.*)'"
    }
    $MATCH = $CONFLUENCE_PAGE_TITLE -match '(\d{4}) - (.*)'
    $CONFLUENCE_PAGE_YEAR = $MATCH[1]
    $CONFLUENCE_STRUCTURE_NAME = $MATCH[2].Trim()

    $PARENT_STORAGE_CONTENT = $CONFLUENCE_PAGE.body.storage.value
    $PARENT_STORAGE_CONTENT | Set-Content -Path $TEMP_FILE.FullName -Encoding UTF8 -Force
    # For MM in 01-12, create a new child page with the title 'YYYY[1-12] (.*)' - copy the content of the page to the new page
    
    1..12 | ForEach-Object {
        $CONFLUENCE_PAGE_MONTH = $_.ToString('00')
        $CONFLUENCE_PAGE_MONTH_TITLE = "$CONFLUENCE_PAGE_YEAR$CONFLUENCE_PAGE_MONTH - $CONFLUENCE_STRUCTURE_NAME"
        Write-Debug "Confluence Page Month Title: $CONFLUENCE_PAGE_MONTH_TITLE"
        $CONFLUENCE_PAGE_MONTH_PAGE = Get-ConfluencePageByTitle -CONFLUENCE_SPACE_KEY $CONFLUENCE_SPACE_KEY -CONFLUENCE_PAGE_TITLE $CONFLUENCE_PAGE_MONTH_TITLE
        if (!$CONFLUENCE_PAGE_MONTH_PAGE) {
            Write-Debug "Creating new page: $CONFLUENCE_PAGE_MONTH_TITLE"
            # Create new page
            $CONFLUENCE_PAGE_MONTH_PAGE = New-ConfluencePage -CONFLUENCE_SPACE_KEY $CONFLUENCE_SPACE_KEY -CONFLUENCE_PAGE_TITLE $CONFLUENCE_PAGE_MONTH_TITLE
            # Copy content from parent page
            Set-ConfluencePageContent -CONFLUENCE_SPACE_KEY $CONFLUENCE_SPACE_KEY -CONFLUENCE_PAGE_ID $CONFLUENCE_PAGE_MONTH_PAGE.id -CONFLUENCE_PAGE_STORAGE_FILE $TEMP_FILE.FullName
        }
        else {
            Write-Debug "Page already exists: $CONFLUENCE_PAGE_MONTH_TITLE"
        }
    } finally {
        Remove-Item -Path $TEMP_FILE.FullName -Force
    }
    # Get child pages of parent page
    $CHILD_PAGES = Get-ConfluenceChildPages -CONFLUENCE_SPACE_KEY $CONFLUENCE_SPACE_KEY -PARENT_ID $CONFLUENCE_PAGE_ID
    $CHILD_PAGES.results | ForEach-Object {
        $CHILD_PAGE_TITLE = $_.title
        $CHILD_PAGE_TITLE_MATCH = $CHILD_PAGE_TITLE -match '(\d{4})(\d{2})(\d+.*)'
        if ($CHILD_PAGE_TITLE_MATCH) {
            $CHILD_PAGE_YEAR = $Matches[1]
            $CHILD_PAGE_MONTH = $Matches[2]
            # Don't change the CHILD_PAGE_TITLE, we are just moving the page
            #$CHILD_PAGE_TITLE = $Matches[3]
            Write-Debug "Child Page Year: $CHILD_PAGE_YEAR, Month: $CHILD_PAGE_MONTH, Title: $CHILD_PAGE_TITLE"
            if ($CHILD_PAGE_YEAR -eq $CONFLUENCE_PAGE_YEAR) {
                Write-Debug "Child Page Year matches: $CHILD_PAGE_YEAR"
                if ($CHILD_PAGE_MONTH -eq $CONFLUENCE_PAGE_MONTH) {
                    Write-Debug

     
                    Write-Debug "Confluence Page Title: $CONFLUENCE_PAGE_TITLE , ID: $CONFLUENCE_PAGE_ID - Year: $CONFLUENCE_PAGE_YEAR - getting child pages..."
                    $CHILD_PAGES = Get-ConfluenceChildPages -CONFLUENCE_SPACE_KEY $CONFLUENCE_SPACE_KEY -PARENT_ID $CONFLUENCE_PAGE_ID
                    $CHILD_PAGES.results | ForEach-Object {
                        $CHILD_PAGE_TITLE = $_.title
                        $CHILD_PAGE_TITLE_MATCH = $CHILD_PAGE_TITLE -match '(\d{4})(\d{2})(\d+.*)'
                        if ($CHILD_PAGE_TITLE_MATCH) {
                            $CHILD_PAGE_YEAR = $Matches[1]
                            $CHILD_PAGE_MONTH = $Matches[2]
                            # Don't change the CHILD_PAGE_TITLE, we are just moving the page
                            #$CHILD_PAGE_TITLE = $Matches[3]
                            Write-Debug "Child Page Year: $CHILD_PAGE_YEAR, Month: $CHILD_PAGE_MONTH, Title: $CHILD_PAGE_TITLE"
                            if ($CHILD_PAGE_YEAR -eq $CONFLUENCE_PAGE_YEAR) {
                                Write-Debug "Child Page Year matches: $CHILD_PAGE_YEAR"
                                if ($CHILD_PAGE_MONTH -eq $CONFLUENCE_PAGE_MONTH) {
                                    Write-Debug "Child Page Month matches: $CHILD_PAGE_MONTH"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}