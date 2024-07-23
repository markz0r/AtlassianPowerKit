$ErrorActionPreference = 'Stop'; $DebugPreference = 'Continue'
$script:CONFLUENCE_SPACE_MAP = @{}

# Function to create a mapping of Confluence spaces and their IDs, that is accessible to all functions
function Get-ConfluenceSpaces {
    $CONFLUENCE_SPACES_ENDPOINT = "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/wiki/api/v2/spaces"
    try {
        $REST_RESULTS = Invoke-RestMethod -Uri $CONFLUENCE_SPACES_ENDPOINT -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get -ContentType 'application/json'
        Write-Debug $REST_RESULTS.getType()
        Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
    }
    catch {
        Write-Debug 'StatusCode:' $_.Exception.Response.StatusCode.value__
        Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
    }
    $script:CONFLUENCE_SPACE_MAP = $REST_RESULTS.results | ForEach-Object {
        $script:CONFLUENCE_SPACE_MAP[$_.key] = [PSCustomObject]@{
            name   = $_.name
            id     = $_.id
            type   = $_.type
            status = $_.status
        }
    }
    Write-Debug "Confluence Space Maps set: $($script:CONFLUENCE_SPACE_MAP | Format-List * | Out-String)"
}

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
        $copy = $range.Copy()
        #################
        ################# Paste the copied text into the new document based on the template
        $templateDoc = $wordApp2.Documents.Add($TEMPLATE_FILE_NAME)
        #$wordApp2.Activate()
        $what = 1 # wdGoToPage https://learn.microsoft.com/en-us/office/vba/api/word.wdgotoitem
        $which = 1 # wdGoToAbsolute https://learn.microsoft.com/en-us/office/vba/api/word.wdgotoitem
        $count = 4
        $selection = $templateDoc.GoTo($what, $which, $count)
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
function Export-ConfluencePageChildrenWord {
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
        $CONFLUENCE_PAGE_TITLE = $_.title
        $CONFLUENCE_PAGE_ID = $_.id
        Export-ConfluencePageStorageFormat -CONFLUENCE_SPACE_KEY $CONFLUENCE_SPACE_KEY -CONFLUENCE_PAGE_ID $CONFLUENCE_PAGE_ID
    }
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

# Function to get a Confluence page's storage format export by the page ID, writing to a file in ./PROFILE_NAME/spacekey/pageid_<YYYMMDD-HHMMSS>.xml
function Export-ConfluencePageStorageFormat {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_SPACE_KEY,
        [Parameter(Mandatory = $true)]
        [int64]$CONFLUENCE_PAGE_ID
    )
    $CONFLUENCE_PAGE_ENDPOINT = "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/wiki/api/v2/pages/$($CONFLUENCE_PAGE_ID)?body-format=storage"
    Write-Debug "Exporting page storage format for page ID: $CONFLUENCE_PAGE_ID in space: $CONFLUENCE_SPACE_KEY... URL: $CONFLUENCE_PAGE_ENDPOINT ..."
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
    $REST_RESULTS.body.storage.value | Out-File -FilePath $FILE_NAME
    Write-Debug "Page storage format exported to: $FILE_NAME"
}

function Set-ConfluencePageContent {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_SPACE_KEY,
        [Parameter(Mandatory = $true)]
        [int64]$CONFLUENCE_PAGE_ID,
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_PAGE_STORAGE_FILE
    )
    Get-ChildItem -Path . -Recurse -Filter 'Naive-ConflunceStorageValidator.psd1' | Import-Module
    $CONFLUENCE_PAGE_STORAGE = $null
    $CONFLUENCE_PAGE_ENDPOINT = "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/wiki/api/v2/pages/$($CONFLUENCE_PAGE_ID)"
    Write-Debug "Exporting page storage format for page ID: $CONFLUENCE_PAGE_ID in space: $CONFLUENCE_SPACE_KEY... URL: $CONFLUENCE_PAGE_ENDPOINT ..."
    try {
        $REST_RESULTS = Invoke-RestMethod -Uri $CONFLUENCE_PAGE_ENDPOINT -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get
    } 
    catch {
        Write-Debug 'StatusCode:' $_.Exception.Response.StatusCode.value__
        Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
        Write-Error "Error getting page ID: $CONFLUENCE_PAGE_ID in space: $CONFLUENCE_SPACE_KEY"
    }
    if ($CONFLUENCE_PAGE_STORAGE_FILE) {
        Write-Debug "Using file: $CONFLUENCE_PAGE_STORAGE_FILE to update page ID: $CONFLUENCE_PAGE_ID in space: $CONFLUENCE_SPACE_KEY..."
        try {
            $CONFLUENCE_PAGE_STORAGE = Get-Content -Path $CONFLUENCE_PAGE_STORAGE_FILE -Raw
        }
        catch {
            Write-Error "Error reading file: $CONFLUENCE_PAGE_STORAGE_FILE"
        }
    }
    else {
        Write-Debug "Searching for most recent file in .\$($env:AtlassianPowerKit_PROFILE_NAME)\$CONFLUENCE_SPACE_KEY\$CONFLUENCE_PAGE_TITLE_ENCODED\$($CONFLUENCE_PAGE_TITLE_ENCODED)_*.xml..."
        $CONFLUENCE_PAGE_TITLE = $REST_RESULTS.title
        $CONFLUENCE_PAGE_TITLE_ENCODED = [System.Web.HttpUtility]::UrlEncode($CONFLUENCE_PAGE_TITLE)
        $FILE_PATH = ".\$($env:AtlassianPowerKit_PROFILE_NAME)\$CONFLUENCE_SPACE_KEY\$CONFLUENCE_PAGE_TITLE_ENCODED\"
        # Find most recent file in file path that matches "$CONFLUENCE_PAGE_TITLE_ENCODED*.xml"
        $MOST_RECENT_FILE = Get-ChildItem -Path $FILE_PATH -Filter "$CONFLUENCE_PAGE_TITLE_ENCODED*.xml" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($MOST_RECENT_FILE) {
            $CONFLUENCE_PAGE_STORAGE_FILE = $MOST_RECENT_FILE.FullName
            Write-Debug "Most recent file: $MOST_RECENT_FILE_PATH"
            $CONFLUENCE_PAGE_STORAGE = Get-Content -Path $CONFLUENCE_PAGE_STORAGE_FILE -Raw
        }
        else {
            Write-Debug 'You can optionally provide a file path to a storage format file to update the page with parameter -CONFLUENCE_PAGE_STORAGE_FILE'
            Write-Error "Exiting as no file found in $FILE_PATH with name like $CONFLUENCE_PAGE_TITLE_ENCODED*.xml"
        }
    }
    $CONFLUENCE_PAGE_TITLE = $REST_RESULTS.title
    Write-Debug 'Validating content is somewhat valid...'
    Test-ConfluenceStorageFormat -FilePath $CONFLUENCE_PAGE_STORAGE_FILE
    Write-Debug "Making backup of current page ID: $CONFLUENCE_PAGE_ID in space: $CONFLUENCE_SPACE_KEY..."
    #Export-ConfluencePageStorageFormat -CONFLUENCE_SPACE_KEY $CONFLUENCE_SPACE_KEY -CONFLUENCE_PAGE_ID $CONFLUENCE_PAGE_ID
    # Remove pretty formatting, whitepassed, and newlines
    $CONFLUENCE_PAGE_STORAGE = $CONFLUENCE_PAGE_STORAGE -replace '\s+', ' '

    

    $PAGE_PAYLOAD = @{
        id      = $CONFLUENCE_PAGE_ID
        version = @{
            number = $REST_RESULTS.version.number + 1
        }
        status  = 'current'
        title   = "$CONFLUENCE_PAGE_TITLE"
        type    = 'page'
        body    = @{
            representation = 'storage'
            value          = $CONFLUENCE_PAGE_STORAGE
        }
    }
    $PAGE_PAYLOAD = $PAGE_PAYLOAD | ConvertTo-Json -Depth 10
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
        Write-Debug "Exporting page storage format for page ID: $($_.id) in space: $CONFLUENCE_SPACE_KEY..."
        Export-ConfluencePageStorageFormat -CONFLUENCE_SPACE_KEY $CONFLUENCE_SPACE_KEY -CONFLUENCE_PAGE_ID $($_.id)
        if (($DepthLimit -eq 0) -or ($DepthCount -lt $DepthLimit)) {
            $DepthCount++
            Export-ConfluencePageStorageFormatForChildren -CONFLUENCE_SPACE_KEY $CONFLUENCE_SPACE_KEY -CONFLUENCE_PARENT_PAGE_TITLE $($_.title) -DepthLimit $DepthLimit -DepthCount $DepthCount
        }
    }
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

# Function to convert a JSON file of JIRA issues to a Confluence page table in storage format
function Convert-JiraFilterToConfluencePageTable {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_PAGE_TITLE,
        [Parameter(Mandatory = $true)]
        [string]$JSON_FILE,
        [Parameter(Mandatory = $true)]
        [array]$FIELD_LIST
    )
    # If file contains valid JSON, send it to the API else error out
    if (-not (Test-Json -Path $JSON_FILE)) {
        Write-Debug "File not found or invalid JSON: $JSON_FILE"
        return
    }
    try {
        $content = Get-Content $JSON_FILE
        # validate the JSON content
        $json = $content | ConvertFrom-Json
    }
    catch {
        Write-Debug "File not found or invalid JSON: $JSON_FILE"
        return
    }
    $CONFLUENCE_PAGE_STORAGE_STRING = @()
    $CONFLUENCE_PAGE_TABLE += '| Key | Summary | Status | Assignee | Created | Updated |'
    $CONFLUENCE_PAGE_TABLE += '|----|----|----|----|----|----|'
    $json.issues | ForEach-Object {
        # Where field name is in the FIELD_LIST, add it to the table
        $_.fields | Where-Object { $FIELD_LIST -contains $_.name } | ForEach-Object {
            $CONFLUENCE_PAGE_TABLE += "| $($_.key) | $($_.fields.summary) | $($_.fields.status.name) | $($_.fields.assignee.name) | $($_.fields.created) | $($_.fields.updated) |"
        }

    }
    $CONFLUENCE_PAGE_TABLE
}