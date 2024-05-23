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
        #Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
    }
    catch {
        Write-Debug 'StatusCode:' $_.Exception.Response.StatusCode.value__
        Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
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
            Write-Debug "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
            Write-Debug "Confluence Page exporting: $CONFLUENCE_PAGE_ENDPOINT"
            $REST_RESULTS = Invoke-RestMethod -Uri $CONFLUENCE_PAGE_ENDPOINT -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get
            Write-Debug $REST_RESULTS.getType()
            Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
            Write-Debug "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        } 
        catch {
            Write-Debug 'StatusCode:' $_.Exception.Response.StatusCode.value__
            Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
        }
    
    $CONFLUENCE_PAGE_STORAGE = $REST_RESULTS.body.storage.value
    $CONFLUENCE_PAGE_TITLE = $REST_RESULTS.title
    $CONFLUENCE_PAGE_TITLE_ENCODED = [System.Web.HttpUtility]::UrlEncode($CONFLUENCE_PAGE_TITLE)
    $CURRENT_DATE_TIME = Get-Date -Format 'yyyyMMdd-HHmmss'
    $FILE_NAME = ".\$($env:AtlassianPowerKit_PROFILE_NAME)\$CONFLUENCE_SPACE_KEY\pageid_$($CONFLUENCE_PAGE_TITLE_ENCODED)_$CURRENT_DATE_TIME.xml"
    if (-not (Test-Path ".\$($env:AtlassianPowerKit_PROFILE_NAME)\$CONFLUENCE_SPACE_KEY")) {
        New-Item -ItemType Directory -Path ".\$($env:AtlassianPowerKit_PROFILE_NAME)\$CONFLUENCE_SPACE_KEY"
    }
    $CONFLUENCE_PAGE_STORAGE | Out-File -FilePath $FILE_NAME
    Write-Debug "Page storage format exported to: $FILE_NAME"
}

# Function to export Confluence page storage format to a file for all child pages of a parent page
function Export-ConfluencePageStorageFormatForChildren {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_SPACE_KEY,
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_PARENT_PAGE_TITLE
    )
    $PARENT_PAGE = Get-ConfluencePageByTitle -CONFLUENCE_SPACE_KEY $CONFLUENCE_SPACE_KEY -CONFLUENCE_PAGE_TITLE $CONFLUENCE_PARENT_PAGE_TITLE
    if (-not $PARENT_PAGE) {
        throw "Parent page does not exist: $CONFLUENCE_PARENT_PAGE_TITLE"
    }
    $PARENT_PAGE_ID = $PARENT_PAGE.results[0].id
    Write-Debug "Parent Page ID: $PARENT_PAGE_ID - getting child pages..."
    $CHILD_PAGES = $(Get-ConfluenceChildPages -CONFLUENCE_SPACE_KEY $CONFLUENCE_SPACE_KEY -PARENT_ID $PARENT_PAGE_ID)
    Write-Debug "Found $($CHILD_PAGES.results.count) child pages..."
    $CHILD_PAGES.results | ForEach-Object {
        Write-Debug "Exporting page storage format for page ID: $($_.id) in space: $CONFLUENCE_SPACE_KEY..."
        Export-ConfluencePageStorageFormat -CONFLUENCE_SPACE_KEY $CONFLUENCE_SPACE_KEY -CONFLUENCE_PAGE_ID $($_.id)
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

# Function to extract all of the UNIQUE Placeholders from a Confluence page storage format, the placeholders are in the format of &lt;&lt;Tsfdalsdkfj&gt;&gt; - read the confluence storage data from file and return an array of unique placeholders
function Get-OSMPlaceholders {
    param (
        [Parameter(Mandatory = $true)]
        [string]$PATH_TO_STORAGE_EXPORTS,
        [Parameter(Mandatory = $false)]
        [string]$PATTERN_TO_FIND
    )
    if (-not $PATTERN_TO_FIND) {
        $PATTERN_TO_FIND = '&lt;&lt;.*?&gt;&gt;'
        Write-Debug "No pattern provided, using default: $PATTERN_TO_FIND"
    }

    # Check if the directory exists and contains files
    if (-not (Test-Path $PATH_TO_STORAGE_EXPORTS)) {
        Write-Debug "Directory does not exist or is empty: $PATH_TO_STORAGE_EXPORTS"
        return
    }
    # For each file in the directory, get the content and extract the placeholders
    Write-Debug "Getting placeholders from files in: $($(Get-ChildItem -Recurse -Path $PATH_TO_STORAGE_EXPORTS -Filter *.xml ).FullName)"
    $PLACEHOLDERS = @()
    Get-ChildItem -Path $PATH_TO_STORAGE_EXPORTS -Recurse -Filter *.xml | ForEach-Object {
        $content = Get-Content $_.FullName
        $placeholder = $content | Select-String -Pattern $PATTERN_TO_FIND -AllMatches | ForEach-Object { $_.Matches.Value } | Sort-Object -Unique
        if ($PATTERN_TO_FIND -eq '&lt;&lt;.*?&gt;&gt;') {
            $placeholder = $placeholder | ForEach-Object { $_ -replace '&lt;&lt;', 'PLACEHOLDER_' -replace '&gt;&gt;', ' ' }
        }
        #Write-Debug "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        $FILE = $_
        #Write-Debug "Placeholders found in file: $($FILE.FullName) :"
        #$placeholder | ForEach-Object { Write-Debug "$FILE.FullName: $_"; $PLACEHOLDERS += ,($($FILE.NAME),$_)}
        $placeholder | ForEach-Object {$PLACEHOLDERS += ,($($FILE.NAME),$_)}
        #Write-Debug "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    }
    #$PLACEHOLDERS = $PLACEHOLDERS | Sort-Object -Unique
    #Write-Debug "Placeholders: $($PLACEHOLDERS | ForEach-Object {'Found: ' + $_ }| Out-String)"
    Write-Debug "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    Write-Debug "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    Write-Debug "FULL LIST:"
    $PLACEHOLDERS | ForEach-Object { Write-Debug "$($_[0]): $($_[1])" }
    Write-Debug "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    Write-Debug "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
    #$PLACEHOLDERS
}

# Function to convert a JSON file of JIRA issues to a Confluence page table in storage format
function Convert-JiraIssuesToConfluencePageTable {
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

# Function to create or update a Confleunce page with a JSON file and reference to parent page name
function Set-ConfluencePage {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_SPACE_KEY,
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_PAGE_TITLE,
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_PARENT_PAGE_TITLE,
        [Parameter(Mandatory = $true)]
        [file]$CONF_STORAGE_FORMAT_DOCUMENT
    )
    # CHECK IF FILE EXISTS and IS valid XML noting it is XML, not JSON
    try {
        $content = Get-Content $CONF_STORAGE_FORMAT_DOCUMENT
        # validate the XML content
        #$xml = $content | ConvertFrom-Xml
    }
    catch {
        throw "File does not exist or is not valid XML: $CONF_STORAGE_FORMAT_DOCUMENT"
    }
    Get-ConfluenceSpaces
    $CONFLUENCE_PAGE_TITLE_ENCODED = [System.Web.HttpUtility]::UrlEncode($CONFLUENCE_PAGE_TITLE)
    $CONFLUENCE_PARENT_PAGE_TITLE_ENCODED = [System.Web.HttpUtility]::UrlEncode($CONFLUENCE_PARENT_PAGE_TITLE)
    Write-Debug "Confluence Space Key: $CONFLUENCE_SPACE_KEY"
    Write-Debug "Confluence Page Title: $CONFLUENCE_PAGE_TITLE"
    Write-Debug "Confluence Page Title Encoded: $CONFLUENCE_PAGE_TITLE_ENCODED"
    Write-Debug "Confluence Parent Page Title: $CONFLUENCE_PARENT_PAGE_TITLE"
    Write-Debug "Confluence Parent Page Title Encoded: $CONFLUENCE_PARENT_PAGE_TITLE_ENCODED"
    # Use the Get-ConfluencePage function to get the parent page object and throw an error if it does not exist
    $PARENT_PAGE = Get-ConfluencePage -CONFLUENCE_SPACE_KEY $CONFLUENCE_SPACE_KEY -CONFLUENCE_PAGE_TITLE $CONFLUENCE_PARENT_PAGE_TITLE
    if (-not $PARENT_PAGE) {
        throw "Parent page does not exist: $CONFLUENCE_PARENT_PAGE_TITLE"
    }
    Write-Debug "Parent Page: $($PARENT_PAGE | ConvertTo-Json -Depth 10)"
    $PARENT_PAGE_ID = $PARENT_PAGE.results[0].id
    Write-Debug "Parent Page ID: $PARENT_PAGE_ID"

    $CURRENT_PAGE = Get-ConfluencePage -CONFLUENCE_SPACE_KEY $CONFLUENCE_SPACE_KEY -CONFLUENCE_PAGE_TITLE $CONFLUENCE_PAGE_TITLE
    # Export the current page content to a file in storage format

    if (-not $CURRENT_PAGE) {
        Write-Debug 'Page does not exist. Creating page...'
        $PAGE_PAYLOAD = @{
            spaceId  = $script:CONFLUENCE_SPACE_MAP | Where-Object { $_.key -eq $CONFLUENCE_SPACE_KEY } | Select-Object -ExpandProperty id
            status   = 'current'
            title    = "$CONFLUENCE_PAGE_TITLE"
            parentId = $PARENT_PAGE_ID
            body     = @{
                representation = 'storage'
                value          = "$($content.body)"
            }

        }
        Write-Debug "Page Payload: $($PAGE_PAYLOAD | ConvertTo-Json -Depth 10)"
        $REST_RESULTS = Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/wiki/api/v2/pages" -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Post -Body ($PAGE_PAYLOAD | ConvertTo-Json -Depth 10) -ContentType 'application/json'
        Write-Debug $REST_RESULTS.getType()
        Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
    }
    else {
        Write-Debug 'Page exists. Updating page...'
        $PAGE_ID = $CURRENT_PAGE.results[0].id
        Write-Debug "Page ID: $PAGE_ID"
        $PAGE_PAYLOAD = @{
            version = @{
                number = $CURRENT_PAGE.results[0].version.number + 1
            }
            title   = "$CONFLUENCE_PAGE_TITLE"
            type    = 'page'
            body    = @{
                storage = @{
                    value          = "$($content.body)"
                    representation = 'storage'
                }
            }
        }
        Write-Debug "Page Payload: $($PAGE_PAYLOAD | ConvertTo-Json -Depth 10)"
        try {
            Invoke-Rest -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/wiki/rest/api/content/$PAGE_ID" -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Put -Body ($PAGE_PAYLOAD | ConvertTo-Json -Depth 10) -ContentType 'application/json'
        }
        catch {
            Write-Debug 'StatusCode:' $_.ToString()
            Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
        }
        Write-Debug '###############################################'
        Write-Debug "Querying the page to confirm the value was set... $CONFLUENCE_PAGE_TITLE in $CONFLUENCE_SPACE_KEY via $($env:AtlassianPowerKit_AtlassianAPIEndpoint)"
        Get-ConfluencePage -CONFLUENCE_SPACE_KEY $CONFLUENCE_SPACE_KEY -CONFLUENCE_PAGE_TITLE $CONFLUENCE_PAGE_TITLE
        Write-Debug '###############################################'
    }
}