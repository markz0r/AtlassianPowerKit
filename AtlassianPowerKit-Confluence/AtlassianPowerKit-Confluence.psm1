$ErrorActionPreference = 'Stop'; $DebugPreference = 'Continue'
$script:CONFLUENCE_SPACE_MAP = @{}
    
# Function to create a mapping of Confluence spaces and their IDs, that is accessible to all functions
function Get-ConfluenceSpaces {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$PROFILE
    )
    
    $CONFLUENCE_SPACES_ENDPOINT = "https://$PROFILE.AtlassianAPIEndpoint/wiki/api/v2/spaces"
    try {
        $REST_RESULTS = Invoke-RestMethod -Uri $CONFLUENCE_SPACES_ENDPOINT -Headers $PROFILE.AtlassianAPIHeaders -Method Get -ContentType 'application/json'
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

# Function to get a Confleunce page
function Get-ConfluencePage {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_SPACE_KEY,
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_PAGE_TITLE
    )
    Get-AtlassianAPIEndpoint
    $CONFLUENCE_PAGE_TITLE_ENCODED = [System.Web.HttpUtility]::UrlEncode($CONFLUENCE_PAGE_TITLE)
    Write-Debug "Confluence Space Key: $CONFLUENCE_SPACE_KEY"
    Write-Debug "Confluence Page Title: $CONFLUENCE_PAGE_TITLE"
    Write-Debug "Confluence Page Title Encoded: $CONFLUENCE_PAGE_TITLE_ENCODED"
    $CONFLUENCE_PAGE_ENDPOINT = "https://$PROFILE.AtlassianAPIEndpoint/wiki/api/v2/pages?spaceKey=$CONFLUENCE_SPACE_KEY&title=$CONFLUENCE_PAGE_TITLE_ENCODED&body-format=storage&expand=body.view,version"
    try {
        $REST_RESULTS = Invoke-RestMethod -Uri $CONFLUENCE_PAGE_ENDPOINT -Headers $PROFILE.AtlassianAPIHeaders -Method Get
        Write-Debug $REST_RESULTS.getType()
        Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
    }
    catch {
        Write-Debug 'StatusCode:' $_.Exception.Response.StatusCode.value__
        Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
    }
    Write-Debug "Found $($REST_RESULTS.results.count) pages..."
    $REST_RESULTS
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

# Function to get a Confluence page's storage format export by the page ID, writing to a file in ./spacekey/pageid_<YYYMMDD-HHMMSS>.xml
function Export-ConfluencePageStorageFormat {
    param (
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_SPACE_KEY,
        [Parameter(Mandatory = $true)]
        [string]$CONFLUENCE_PAGE_ID
    )
    Get-AtlassianAPIEndpoint
    $CONFLUENCE_PAGE_ENDPOINT = "https://$PROFILE.AtlassianAPIEndpoint/wiki/api/v2/pages/$CONFLUENCE_PAGE_ID?expand=body.storage"
    try {
        $REST_RESULTS = Invoke-RestMethod -Uri $CONFLUENCE_PAGE_ENDPOINT -Headers $PROFILE.AtlassianAPIHeaders -Method Get
        Write-Debug $REST_RESULTS.getType()
        Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
    }
    catch {
        Write-Debug 'StatusCode:' $_.Exception.Response.StatusCode.value__
        Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
    }
    $CONFLUENCE_PAGE_STORAGE = $REST_RESULTS.body.storage.value
    $CURRENT_DATE_TIME = Get-Date -Format 'yyyyMMdd-HHmmss'
    $FILE_NAME = "$($CONFLUENCE_SPACE_KEY)_EXPORT/pageid_$CONFLUENCE_PAGE_ID_$CURRENT_DATE_TIME.xml"
    $CONFLUENCE_PAGE_STORAGE | Out-File -FilePath $FILE_NAME
    Write-Debug "Page storage format exported to: $FILE_NAME"
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
        $REST_RESULTS = Invoke-RestMethod -Uri "https://$PROFILE.AtlassianAPIEndpoint/wiki/api/v2/pages" -Headers $PROFILE.AtlassianAPIHeaders -Method Post -Body ($PAGE_PAYLOAD | ConvertTo-Json -Depth 10) -ContentType 'application/json'
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
            Invoke-Rest -Uri "https://$PROFILE.AtlassianAPIEndpoint/wiki/rest/api/content/$PAGE_ID" -Headers $PROFILE.AtlassianAPIHeaders -Method Put -Body ($PAGE_PAYLOAD | ConvertTo-Json -Depth 10) -ContentType 'application/json'
        }
        catch {
            Write-Debug 'StatusCode:' $_.ToString()
            Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
        }
        Write-Debug '###############################################'
        Write-Debug "Querying the page to confirm the value was set... $CONFLUENCE_PAGE_TITLE in $CONFLUENCE_SPACE_KEY via $PROFILE.AtlassianAPIEndpoint"
        Get-ConfluencePage -CONFLUENCE_SPACE_KEY $CONFLUENCE_SPACE_KEY -CONFLUENCE_PAGE_TITLE $CONFLUENCE_PAGE_TITLE
        Write-Debug '###############################################'
    }
}