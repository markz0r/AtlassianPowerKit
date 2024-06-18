<#
.SYNOPSIS
    Atlassian Cloud PowerShell Module for handy functions to interact with Attlassian Cloud APIs.

.DESCRIPTION
    Atlassian Cloud PowerShell Module for Jira Cloud and Opsgenie API functions.
    - Key functions are:
        - Setup:
            -             - New-AtlassianAPIEndpoint -AtlassianAPIEndpoint 'https://yourdomain.atlassian.net'
        - JIRA
            - Issues
                - Get-JiraCloudJQLQueryResult -JQL_STRING $JQL_STRING -JSON_FILE_PATH $JSON_FILE_PATH
                - Get-JiraIssueJSON -Key $Key
                - Get-JiraIssueChangeNullsFromJQL -JQL_STRING $JQL_STRING
                    - Get-JiraIssueChangeNulls -Key $Key
                - Get-JiraIssueChangeLog -Key $Key
                - Get-JiraFields
                - Set-JiraIssueField -ISSUE_KEY $ISSUE_KEY -Field_Ref $Field_Ref -New_Value $New_Value -FieldType $FieldType
                - Set-JiraCustomField -FIELD_NAME $FIELD_NAME -FIELD_TYPE $FIELD_TYPE
            - Project
                - Get-JiraProjectProperty
                - Get-JiraProjectProperties
                    - Set-JiraProjectProperty
                    - Clear-JiraProjectProperty
                - Get-JiraProjectIssuesTypes
            - Other
                - Get-OpsgenieServices -Output ready for Set-JiraProjectProperty
            - Users and Groups
                - Get-AtlassianGroupMembers
                - Get-AtlassianUser
    - To list all functions in this module, run: Get-Command -Module AtlassianPowerKit
    - Debug output is enabled by default. To disable, set $DisableDebug = $true before running functions.

.PARAMETER AtlassianAPIEndpoint
    The Jira Cloud API endpoint for your Jira Cloud instance. This is required for all functions that interact with the Jira Cloud API. E.g.: 'yourdomain.atlassian.net'

.PARAMETER OpsgenieAPIEndpoint
    The Opsgenie API endpoint for your Opsgenie instance. This is required for all functions that interact with the Opsgenie API. Defaults to: 'api.opsgenie.com'

.EXAMPLE
    New-AtlassianAPIEndpoint -AtlassianAPIEndpoint 'https://yourdomain.atlassian.net'
    
    This example sets the Jira Cloud API endpoint and then gets the Jira Cloud API endpoint.

.EXAMPLE
    Get-JiraCloudJQLQueryResult -JQL_STRING 'project = "OSM" AND status = "Open"' -JSON_FILE_PATH 'C:\Temp\OSM-Open-Issues.json'

    This example gets the Jira Cloud JQL query results for all open issues in the OSM project and exports the results to a JSON file at 'C:\Temp\OSM-Open-Issues.json'.

.EXAMPLE
    Get-JiraIssueJSON -Key 'OSM-123'

    This example gets the Jira issue with the key 'OSM-123' and exports the results to a JSON file at '.\OSM-123.json'.

.EXAMPLE
    Get-JiraIssueChangeNullsFromJQL -JQL_STRING 'project = "OSM" AND status = "Open"'

    This example gets the Jira Cloud JQL query results for all open issues in the OSM project and then gets the change nulls for each issue.

.EXAMPLE
    Get-Jira-CloudJQLQueryResults -JQL_STRING 'project is not EMPTY' -JSON_FILE_PATH 'All-Issues.json'

    This example gets the Jira Cloud JQL query results for all issues in all projects.

.LINK
GitHub: https://github.com/markz0r/AtlassianPowerKit

#>
$ErrorActionPreference = 'Stop'; $DebugPreference = 'Continue'

function Get-JiraFilterResults {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FILTER_ID
    )
    
    $FILTER_INFO = Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/3/filter/$($FILTER_ID)" -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get -ContentType 'application/json'
    #self|https://auda.atlassian.net/rest/api/3/filter/10242], [id|10242], [name|GRCosm: Annex A - ISO27001:2022 Requirements], [description|], [owner|@{self=https://auda.atlassian.net/rest/api/3/user?accountId=557058:2977d27c-4718-41e0-95ed-2a877ceadf78; accountId=557058:2977d27c-4718-41e0-95ed-2a877ceadf78; avatarUrls=; displayName=Mark Culhane; active=True}], [jql|project = GRCOSM and type = Requirement and statuscategory in (New, "In Progress") and labels in (ISO27001_2022_AnnexA)], [                      ORDER BY labels,cf[10312]], [viewUrl|https://auda.atlassian.net/issues/?filter=10242], [searchUrl|https://auda.atlassian.net/rest/api/3/search?jql=project%20%3D%20GRCOSM%20and%20type%20%3D%20Requirement%20and%20statuscategory%20in%20%28New%2C%20%22In%20Progress%22%29%20and%20labels%20in%20%28ISO27001_2022_AnnexA%29%0AORDER%20BY%20labels%2Ccf%5B10312%5D], [favourite|True], [favouritedCount|1], [sharePermissions|{@{id=10919; type=loggedin}}], [editPermissions|{@{id=10916; type=group; group=}, @{id=10918; type=project; project=; role=}, @{id=10917; type=group; group=}}], [isWritable|True], [sharedUsers|@{size=54; items=System.Object[]; max-results=1000; start-index=0; end-index=0}], [subscriptions|@{size=0; items=System.Object[]; max-results=1000; start-index=0; end-index=0}], [approximateLastUsed|17/06/2024 12:07:19 AM

    $FILTER_COLUMNS = Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/3/filter/$($FILTER_ID)/columns" -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get -ContentType 'application/json'
    Write-Debug "Filter Columns [$($FILTER_COLUMNS.columns.count)]: $($FILTER_COLUMNS.columns)"
    $FILTER_ISSUES = Export-JiraIssueLinksFromJQL -JQL_STRING "filter = $FILTER_ID"

    $CONFLUENCE_STORAGE_RAW_HEADER = "<hr /><ul><li><p>Updated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p></li><li><p>Source: <a href=""$($FILTER_INFO.viewURL)"">$($FILTER_INFO.name)</a></p></li></ul><hr />"

    
}

function Get-JiraIssueChangeNullsFromJQL {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JQL_STRING
    )
    $FIELD_NAME_OR_ID_OR_NULL = Read-Host 'OPTIONALLY, Enter a custom field name or ID (customfield_\d+) to check for nulls, or press Enter to skip...'
    Write-Debug "JQL Query: $JQL_STRING running..."
    $NULL_CHANGE_ITEMS = @()
    $REST_RESULTS = Get-JiraCloudJQLQueryResult -JQL_STRING $JQL_STRING
    if (!$FIELD_NAME_OR_ID_OR_NULL) {
        #Get-JiraIssueChangeNulls -Key $_.key
        Write-Debug 'No field name or ID provided, checking all fields...'
        $NULL_CHANGE_ITEMS = $REST_RESULTS.issues | ForEach-Object {
            Get-JiraIssueChangeNulls -Key $_.key
        }
    }
    else {
        Write-Debug "Field name or ID provided: $FIELD_NAME_OR_ID_OR_NULL"
        $NULL_CHANGE_ITEMS = $REST_RESULTS.issues | ForEach-Object {
            Get-JiraIssueChangeNulls -Key $_.key -SELECTOR "$FIELD_NAME_OR_ID_OR_NULL"
        }
    }
    # Write formated list of null changes to terminal
    $NULL_CHANGE_ITEMS | ForEach-Object {
        Write-Debug "$($_.key) - Field: $($_.field) (ID: $($_.fieldId)), Type: $($_.fieldtype) --- Value nulled: $($_.from)           [Created: $($_.created) - Author: $($_.author)]"
        #Write-Debug "Restore with: Set-JiraIssueField -ISSUE_KEY $($_.key) -Field_Ref $($_.fieldId) -New_Value $($_.from) -FieldType $($_.fieldtype)"
    }
    $ATTEMPT_RESTORE = Read-Host 'Do you want to attempt to restore the nulled values? Y/N [N]'
    if ($ATTEMPT_RESTORE -eq 'Y') {
        # if $($_.fromString) appears to be an array, restore as an array
        $NULL_CHANGE_ITEMS | ForEach-Object {
            if ($_.fieldtype -eq 'custom') {
                if ($_.fieldId -ne 'customfield_10163') {
                    $New_Value = $_.fromString
                }
                else {
                    $New_Value = $_.from
                }
                $New_Value = $New_Value -replace '[\[\]\s]', ''
                $New_Value = $New_Value.Split(',')
            }
            else {
                $New_Value = , @($_.from)
            }
            if ($_.fieldId -eq 'customfield_10163') {
                $TARGET_FIELD = 'customfield_10370'
            }
            else {
                $TARGET_FIELD = $_.fieldId
            }

            Set-JiraIssueField -ISSUE_KEY $_.key -Field_Ref $TARGET_FIELD -New_Value $New_Value -FieldType $_.fieldtype
            Write-Debug "Updated: $($_.issue) - Field: $($_.field): Value restored: $($_.fromString)       --- data_val:[$($_.from)]"
        }

    }
}
# Function to list all JSON fields in a JSON object array only if the field contains a value that is not null in at least one object, include example of the field value, don't repeat the field name
function Get-JSONFieldsWithData {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FILE_PATH
    )
    # TO BE MOVED TO CONFIG
    $EXCLUDED_FIELDS = @('Time to resolution', 'Time to first response', 'customfield_10062', 'assignee', 'aggregatetimeoriginalestimate',
        'aws-json-field__ad4c4b0c-406f-47c1-a8e3-df46e38dabf2', 'customfield_10291', 'customfield_10292', 'customfield_10294', 'customfield_10295', 'reporter'
        'progress', 'issuetype', 'project', 'customfield_10036', 'watches', 'customfield_10018', 'customfield_10019', 'updated', 'customfield_10010', 'customfield_10011', 'currentStatus', 'timetracking',
        'aws-json-field__b72236ec-c3c4-43ea-a646-84d08f224ab5', 'statuscategorychangedate', 'versions', 'timeestimate', 'status', 'creator', 'aggregateprogress', 'workratio', 'issuerestriction', 'created')
    $DATA_FIELD_LIST = @{}
    # For each json file in the directory, get the content and extract the fields
    # Write a sub-function that gets all fields in a JSON object array that are not null, adding the field to a hash table with key as the field name and value as the field value, if the key already exists, skip, the function takes a JSON object array as a parameter if the field is an object, write the field name and object type is an object, if the field is an array, write the field name and object type is an array, call self with the array as a parameter
    function Search-JSONObjectArray {
        param (
            [Parameter(Mandatory = $true)]
            [object]$JSON_OBJECT
        )
        $JIRA_FIELD_ARRAY = Get-JiraFields -SUPRESS_OUTPUT
        $JSON_OBJECT = $JSON_OBJECT | ConvertFrom-Json -Depth 30
        $JSON_OBJECT | ForEach-Object {
            $OBJECT = $_
            # Create a hash table of the 'fields' nested object
            $FIELDS = $OBJECT.fields
            # For each item in the fields, get the field name and value
            $FIELDS.PSObject.Properties | ForEach-Object {
                $FIELD = $_
                #Write-Debug "Processing field: $FIELD"
                #Write-Debug "Processing field: Name: $($FIELD.Name) - Value: $($FIELD.Value)"
                if ((!$FIELD.Value) -or ($FIELD.Value -eq 'null') -or ($FIELD.Name -in $EXCLUDED_FIELDS)) {
                    return
                }
                else {
                    #Write-Debug '######'
                    #Write-Debug "Field with data: $($FIELD.Name)"
                    $FIELD_INFO = $JIRA_FIELD_ARRAY | Where-Object { $_.id -eq $FIELD.Name }
                    #Write-Debug "Field with data, field info name: $($FIELD_INFO.name)"
                    #Write-Debug "$($($FIELD.Name, $FIELD_INFO, $($FIELD.Value)).ToString())"
                    if (!(($DATA_FIELD_LIST.Count -gt 0) -and ($DATA_FIELD_LIST.ContainsKey($FIELD_INFO.name)))) {
                        #Write-Debug "Adding new field to DATA_FIELD_LIST: $FIELD.Name ----> $FIELD_INFO.name"
                        $DATA_FIELD_LIST[$($FIELD_INFO.name)] = "$($FIELD_INFO.name), $($FIELD.Name), $($($FIELD_INFO | ConvertTo-Json -Depth 1 -Compress) -replace(',', ' ')), $($($($FIELD.Value) | ConvertTo-Json -Depth 1 -Compress) -replace(',', ' '))"
                    }
                    #Write-Debug '######'
                }
            }
        }
    }
    Get-ChildItem -Path $FILE_PATH -Recurse -Filter *.json | ForEach-Object {
        $FILE = $_
        Write-Debug "Processing file: $($FILE.FullName)"
        $JSON_OBJECT = Get-Content -Path $_.FullName -Raw
        Search-JSONObjectArray -JSON_OBJECT $JSON_OBJECT
    }
    # Write $DATA_FIELD_LIST to a file
    $OUTPUT_FILE = "$env:AtlassianPowerKit_PROFILE_NAME\$env:AtlassianPowerKit_PROFILE_NAME-FieldsWithData-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
    if (-not (Test-Path $OUTPUT_FILE)) {
        New-Item -ItemType File -Path $OUTPUT_FILE -Force | Out-Null
    }
    # Write the field list to a CSV file with headers
    $CSV_DATA = @() 
    $CSV_DATA += 'Field Name, Field ID, Field Info, Field Value'
    # sort the data field list by field name and write values to the CSV file
    Write-Debug "DATA_FIELD_LIST: $($DATA_FIELD_LIST.GetType())"
    Write-Debug "Fields with data: $($DATA_FIELD_LIST.Count)"
    $DATA_FIELD_LIST.GetEnumerator() | Sort-Object -Property Name | ForEach-Object {
        # Write each of the array values to the CSV file
        # Make a csv entry for the value object
        $Entry = $_.Value
        Write-Debug "Entry: $Entry"
        Write-Debug "Entry Type: $($Entry.GetType())"
        $CSV_DATA += $Entry
    }
    Write-Debug "CSV_DATA: $CSV_DATA"
    Write-Debug "CSV_DATA: $($CSV_DATA.GetType())"
    $CSV_DATA | Out-File -FilePath $OUTPUT_FILE -Append
    Write-Debug "Fields with data written to: $((Get-Item -Path $OUTPUT_FILE).Directory.FullName)"
}

# Function to Export all Get-JiraCloudJQLQueryResult to a JSON file
function Export-JiraCloudJQLQueryResultsToJSON {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JQL_STRING,
        [Parameter(Mandatory = $false)]
        [string]$JSON_FILE_PATH
    )
    $JIRA_FIELDS = Get-JiraFields
    $JIRA_FIELDS | ForEach-Object {
        Write-Debug "id: $($_.id), key: $($_.key), name: $($_.name)"
    }
    # Create a hash table of Jira fields with the field key as the key and the field name as the value
    $JIRA_FIELD_MAPS = @{}
    $JIRA_FIELDS | ForEach-Object {
        $JIRA_FIELD_MAPS[$_.id] = $_.name
    }
    # Get the JQL query results and provide the JSON file path if it is defined
    Write-Debug 'Exporting JQL query results to JSON'
    # Advise the user if the JSON file path is not defined so only the results are displayed
    if (-not $JSON_FILE_PATH) {
        $JSON_FILE_PATH = "$($env:AtlassianPowerKit_PROFILE_NAME)-JQLExport-$((Get-Date).ToString('yyyyMMdd-HHmmss'))"
        Write-Debug "JSON file path not defined. creating JSON output dir current directory in $JSON_FILE_PATH"
        # create the directory if it does not exist
        if (-not (Test-Path $JSON_FILE_PATH)) {
            New-Item -ItemType Directory -Path $JSON_FILE_PATH
        }
    }
    Write-Debug "JQL Query: $JQL_STRING running..."
    # wait for Get-JiraCloudJQLQueryResult -JQL_STRING $JQL_STRING -JSON_FILE_PATH $JSON_FILE_PATH to complete and return the results to $REST_RESULTS
    $REST_RESULTS = Get-JiraCloudJQLQueryResult -JQL_STRING $JQL_STRING -JSON_FILE_PATH $JSON_FILE_PATH -JIRA_FIELD_MAPS $JIRA_FIELD_MAPS
    Write-Debug "Total Results: $($REST_RESULTS.total), export complete."
    return $REST_RESULTS
}

# Function to get the issuelinks field from a Jira issue
function Get-JiraIssueLinks {
    param (
        [Parameter(Mandatory = $true)]
        [string]$IssueKey
    )
    try {
        $ISSUE_LINKS = Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/2/issue/$($IssueKey)?fields=issuelinks" -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get -ContentType 'application/json'
    }
    catch {
        Write-Debug ($_ | Select-Object -Property * -ExcludeProperty psobject | Out-String)
        Write-Error "Error updating field: $($_.Exception.Message)"
    }
    $ISSUE_PREFIX = "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)"
    $ISSUE_LINKS.fields.issuelinks | ForEach-Object {
        # if the outwardIssue key is present, write the outwardIssue key and the type.outward to the terminal
        # Write-Debug $_

        if ($_.outwardIssue.Length -gt 0) {
            Write-Debug "$ISSUE_PREFIX/$($_.outwardIssue.key), $($_.type.inward), $IssueKey"
        }
        else {
            Write-Debug "$ISSUE_PREFIX/$($_.inwardIssue.key), $($_.type.outward), $IssueKey"
        }
        # Write the issue links to a file named ./$($env:AtlassianPowerKit_PROFILE_NAME)/$($env:AtlassianPowerKit_PROFILE_NAME)-$IssueKey-IssueLinks-YYYYMMDD_HHMMSS.json
        $ISSUE_LINKS | ConvertTo-Json -Depth 30 | Out-File -FilePath "$($env:AtlassianPowerKit_PROFILE_NAME)\$($env:AtlassianPowerKit_PROFILE_NAME)-$IssueKey-IssueLinks-$((Get-Date).ToString('yyyyMMdd_HHmmss')).json"
    }
}

# Function to export all issue links from issues in a JQL query to a JSON file
function Export-JiraIssueLinksFromJQL {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JQL_STRING
    )
    # Get the JQL query results and provide the JSON file path if it is defined
    $JSON_FILE_PATH = "$($env:AtlassianPowerKit_PROFILE_NAME)/$($env:AtlassianPowerKit_PROFILE_NAME)-JQLExportLinks-$((Get-Date).ToString('yyyyMMdd-HHmmss'))"
    if (-not (Test-Path $($env:AtlassianPowerKit_PROFILE_NAME))) {
        New-Item -ItemType Directory -Path $($env:AtlassianPowerKit_PROFILE_NAME)
    }
    Write-Debug 'Exporting JQL query results to JSON'
    if (-not (Test-Path $JSON_FILE_PATH)) {
        New-Item -ItemType Directory -Path $JSON_FILE_PATH
    }
    $ISSUES = Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/3/search?fields=key" -Headers $args[3] -Method Post -Body $args[0] -ContentType 'application/json'


}

function Get-JiraCloudJQLQueryResultPages {
    param (
        [Parameter(Mandatory = $true)]
        [string]$P_BODY_JSON,
        [Parameter(Mandatory = $false)]
        [string]$JSON_FILE_PATHNAME,
        [Parameter(Mandatory = $false)]
        [System.Object]$JIRA_FIELD_MAPS
    )
    $ISSUES = Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/3/search" -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Post -Body $P_BODY_JSON -ContentType 'application/json'
    # Backoff if the API returns a 429 status code
    if ($ISSUES.statusCode -eq 429) {
        Write-Debug 'API Rate Limit Exceeded. Waiting for 60 seconds...'
        Start-Sleep -Seconds 20
        continue
    }
    Write-Debug "Total: $($ISSUES.total) - Collecting issues: $($P_BODY.startAt) to $($P_BODY.startAt + 100)..."
    if ($ISSUES.issues -and $JSON_FILE_PATHNAME) {
        Write-Debug "Exporting $P_BODY.startAt plus $P_BODY.maxResults to $JSON_FILE_PATHNAME"
        # Replace the field key with the field name in the JSON object
        function Convert-FieldKeyToName {
            param (
                [Parameter(Mandatory = $true)]
                [System.Object]$FIELD_OBJECT,
                [Parameter(Mandatory = $true)]
                [System.Object]$JIRA_FIELD_MAPS
            )
            $OUT_KEY = $FIELD_OBJECT.Key
            if ($JIRA_FIELD_MAPS.ContainsKey($FIELD_KEY)) {
                $OUT_KEY = $JIRA_FIELD_MAPS[$FIELD_KEY]
            }
            return @{ $OUT_KEY = $FIELD_OBJECT.Value }
        }
        $ISSUES.issues | ForEach-Object {
            $ISSUE = $_
            $ISSUE.fields | ForEach-Object {
                $FIELD_KEY = $_.Key
                if ($JIRA_FIELD_MAPS.ContainsKey($FIELD_KEY)) {
                    $_.FieldName = $JIRA_FIELD_MAPS[$FIELD_KEY]
                }
            }
        }
        $ISSUE = $($ISSUES.issues | Select-Object -Property key, fields)
        # Write the issue object to terminal displaying all fields

        $ISSUE_JSON = $ISSUES.issues | Select-Object -Property key, fields | ConvertTo-Json -Depth 30

    }
    #Out-File -FilePath "$JSON_FILE_PATHNAME"
    $ISSUES
}

# Function to return JQL query results as a PowerShell object that includes a loop to ensure all results are returned even if the
# number of results exceeds the maximum number of results returned by the Jira Cloud API
function Get-JiraCloudJQLQueryResult {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JQL_STRING,
        [Parameter(Mandatory = $false)]
        [System.Object]$JIRA_FIELD_MAPS
    )

    $POST_BODY = @{
        fieldsByKeys = $true
        jql          = "$JQL_STRING"
        maxResults   = 1
        startAt      = 0
        fields       = @('name')
    }
    # Get total number of results for the JQL query
    $WARNING_LIMIT = 2000
    do {
        Write-Debug 'Validating JQL Query...'
        $VALIDATE_QUERY = Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/3/search" -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Post -Body ($POST_BODY | ConvertTo-Json) -ContentType 'application/json'
        if ($VALIDATE_QUERY.statusCode -eq 429) {
            Write-Debug 'API Rate Limit Exceeded. Waiting for 60 seconds...'
            Start-Sleep -Seconds 20
            continue
        }
        Write-Debug "Validating JQL Query... Total: $($VALIDATE_QUERY.total)"
    } until ($VALIDATE_QUERY.total)
    if ($VALIDATE_QUERY.total -eq 0) {
        Write-Debug 'No results found for the JQL query...'
        return
    }
    elseif ($VALIDATE_QUERY.total -gt $WARNING_LIMIT) {
        # Advise the user that the number of results exceeds $WARNING_LIMIT and ask if they want to continue
        Write-Warning "The number of results for the JQL query exceeds $WARNING_LIMIT. Do you want to continue? [Y/N]"
        $continue = Read-Host
        if ($continue -ne 'Y') {
            Write-Debug 'Exiting...'
            return
        }
    }
    $POST_BODY.maxResults = 100
    $POST_BODY.fields = @('*all', '-attachments', '-comment', '-issuelinks', '-subtasks', '-worklog')
    # If json file path is defined, create a prefix for the file name and create the file path if it does not exist
    $JSON_FILE_PREFIX = "$($env:AtlassianPowerKit_PROFILE_NAME)\$($env:AtlassianPowerKit_PROFILE_NAME)-JQLExport-$((Get-Date).ToString('yyyyMMdd-HHmmss'))\$($env:AtlassianPowerKit_PROFILE_NAME)-JQLExport-$((Get-Date).ToString('yyyyMMdd-HHmmss'))-Results-"

    if (-not (Test-Path $JSON_FILE_PREFIX)) {
        New-Item -ItemType Directory -Path $JSON_FILE_PREFIX
    }
    $STARTAT = 0; $ISSUES_LIST = @(); $jobs = @(); $maxConcurrentJobs = 100
    while ($STARTAT -lt $VALIDATE_QUERY.total) {
        # If the number of running jobs is equal to the maximum, wait for one to complete
        while (($jobs | Where-Object { $_.State -eq 'Running' }).Count -ge $maxConcurrentJobs) {
            # Wait for any job to complete
            $completedJob = $jobs | Wait-Job -Any
            # Get the result of the completed job
            $ISSUES_LIST += Receive-Job -Job $completedJob
            # Remove the completed job
            Remove-Job -Job $completedJob
            # Remove the completed job from the jobs array
            $jobs = $jobs | Where-Object { $_.Id -ne $completedJob.Id }
        }
        $POST_BODY.startAt = $STARTAT
        $jsonFilePath = "$JSON_FILE_PREFIX-$STARTAT.json"
        $P_BODY_JSON = $POST_BODY | ConvertTo-Json
        Write-Debug "Getting Jira Cloud JQL Query Results Pages... P_BODY_JSON: $P_BODY_JSON, JSON_FILE_PATHNAME: $jsonFilePath"
        $jobs += Start-Job -ScriptBlock {
            $ISSUES = Invoke-RestMethod -Uri "https://$($args[2])/rest/api/3/search?expand=names" -Headers $args[3] -Method Post -Body $args[0] -ContentType 'application/json'
            if ($ISSUES.statusCode -eq 429) {
                Write-Debug 'API Rate Limit Exceeded. Waiting for 60 seconds...'
                Start-Sleep -Seconds 20
                continue
            }
            Write-Debug "Total: $($ISSUES.total) - Collecting issues: $($args[0].startAt) to $($args[0].startAt + 100)..."
            if ($ISSUES.issues -and $args[1]) {
                Write-Debug "Exporting $($args[0].startAt) plus $($args[0].maxResults) to $($args[1])"
                $ISSUES.issues | Select-Object -Property key, fields | ConvertTo-Json -Depth 30 | Out-File -FilePath $args[1]
                # Check file was written
                if (-not (Test-Path $args[1])) {
                    Write-Error "File not written: $($args[1])"
                }
            }
            # Get-JiraCloudJQLQueryResultPages -P_BODY_JSON $args[0] -JSON_FILE_PATHNAME $args[1]
            $ISSUES
        } -ArgumentList @($P_BODY_JSON, $jsonFilePath, $($env:AtlassianPowerKit_AtlassianAPIEndpoint), $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders))
        Write-Debug 'Sleeping for 2 seconds before next iteration...'
        Start-Sleep -Seconds 2
        $STARTAT += 100
    }
    # Wait for all jobs to complete
    Write-Debug 'Waiting for all jobs to complete...'
    # Start timer
    $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $jobs | Wait-Job
    # Stop timer
    $stopWatch.Stop()
    Write-Debug "All jobs completed with wait of $($stopWatch.Elapsed.TotalSeconds) seconds."
    $ISSUES_LIST += $jobs | Receive-Job
    # Remove the remaining jobs
    $jobs | Remove-Job
    # Make a combined JSON file of all the JSON data
    $COMBINED_JSON_FILE = "$($env:AtlassianPowerKit_PROFILE_NAME)\$($env:AtlassianPowerKit_PROFILE_NAME)-JQLExport-$((Get-Date).ToString('yyyyMMdd-HHmmss'))-Results-Combined.json"
    $ISSUES_LIST | ConvertTo-Json -Depth 30 | Out-File -FilePath $COMBINED_JSON_FILE
    return $ISSUES_LIST
}

# Function to get change log for a Jira issue
function Get-JiraIssueChangeLog {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Key
    )
    $CHANGE_LOG = Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/3/issue/$Key/changelog" -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get
    #Write-Debug "Change log for issue: $Key"
    #Write-Debug $($CHANGE_LOG | ConvertTo-Json -Depth 10)
    return $CHANGE_LOG

}

# Function to edit a Jira issue field given the issue key, field name, and new value
function Set-JiraIssueField {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ISSUE_KEY,
        [Parameter(Mandatory = $true)]
        [string]$Field_Ref,
        [Parameter(Mandatory = $true)]
        [array]$New_Value,
        [Parameter(Mandatory = $true)]
        [string]$FieldType
    )
    if ($Field_Ref -eq 'customfield_10181') {
        Write-Debug 'Overiding known field ID change for Service Categories to customfield_10316...'
        $Field_Ref = 'customfield_10316'
    }
    $FIELD_PAYLOAD = @{}
    function Set-MutliSelectPayload {
        @{
            fields = @{
                $Field_Ref = @(
                    $New_Value | ForEach-Object {
                        @{ 'accountId' = "$_" }
                    }
                )
            }
        }
    }
    #$FIELD_PAYLOAD = $FIELD_PAYLOAD | ConvertTo-Json -Depth 10
    Write-Debug "Field Type: $FieldType"
    switch -regex ($FieldType) {
        'custom' { $FIELD_PAYLOAD = $(Set-MutliSelectPayload) }
        'multi-select' { $FIELD_PAYLOAD = $(Set-MutliSelectPayload) }
        'single-select' { $FIELD_PAYLOAD = @{fields = @{"$Field_Ref" = @{value = "$New_Value" } } } }
        'text' { $FIELD_PAYLOAD = @{fields = @{"$Field_Ref" = "$New_Value" } } }
        Default { $FIELD_PAYLOAD = @{fields = @{"$Field_Ref" = "$New_Value" } } }
    }
    $REQUEST_URL = "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/2/issue/$($ISSUE_KEY)" 
    # Run the REST API call to update the field with verbose debug output
    $FIELD_PAYLOAD = $FIELD_PAYLOAD | ConvertTo-Json -Depth 10 -Compress
    Write-Debug "Field Payload: $FIELD_PAYLOAD"
    #Write-Debug "Trying: Invoke-RestMethod -Uri $REQUEST_URL -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Put -Body $FIELD_PAYLOAD -ContentType 'application/json'"
    try {
        $UPDATE_ISSUE_RESPONSE = Invoke-RestMethod -Uri $REQUEST_URL -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Put -Body $FIELD_PAYLOAD -ContentType 'application/json'
    }
    catch {
        Write-Debug ($_ | Select-Object -Property * -ExcludeProperty psobject | Out-String)
        Write-Error "Error updating field: $($_.Exception.Message)"
    }
    Write-Debug "$UPDATE_ISSUE_RESPONSE"
}

# function to get changes from a Jira issue change log that are from a value to null
function Get-JiraIssueChangeNulls {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [Parameter(Mandatory = $false)]
        [string]$SELECTOR
    )
    $CHECK_MONTHS = -6
    $EXCLUDED_FIELDS = @('Category', 'BCMS: Disaster Recovery Procedures', 'BCMS: Backup Description', 'Incident Contacts', 'Internal / Third Party service', 'BCMS: RPO', 'BCMS: RTO', 'BCMS: MTDP', 'BCMS: MBCO', 'Persistent data stored', 'Monitoring and Alerting', 'SLA/OLA/OKRs', 'Endpoints', 'Service Criticality', 'Service Type', 'Service Status')
    $INCLDUED_VALUES = @($null, '[]', '')
    $CHANGE_LOG = Get-JiraIssueChangeLog -Key $Key
    #$CHANGE_LOG | Get-Member
    if (! $CHANGE_LOG.isLast) {
        Write-Warning 'There are more than 100 changes for this issue. This function only returns the first 100 changes.'
    }
    $ISSUE_LINK = "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/browse/$Key"
    #Write-Debug $($CHANGE_LOG | ConvertTo-Json -Depth 10)
    $NULL_CHANGE_ITEMS = @()
    $FINAL_ITEMS = @()
    $CHANGE_LOG.values | ForEach-Object {
        $MAMMA = $_
        if (!$SELECTOR) {
            $NULL_CHANGE_ITEMS += $MAMMA.items | Where-Object {
                ($MAMMA.created -gt (Get-Date).AddMonths($CHECK_MONTHS)) -and ((-not $_.toString) -and ( -not $_.to)) -and (-not $_.field.StartsWith('BCMS')) -and (-not $EXCLUDED_FIELDS.Contains($_.field))
            }
        }
        else {
            $NULL_CHANGE_ITEMS += $MAMMA.items | Where-Object {
                (($SELECTOR -eq $($_.fieldId)) -and ($INCLDUED_VALUES.Contains($_.toString)))
                #Write-Debug "Selector: $SELECTOR"
                #Write-Debug "changelog: $($_.fieldId)"
                #Write-Debug "changelog: $($_.field)"
                #Write-Debug "changelog: $($_.toString)"
                #Write-Debug "changelog: $($_.to)"
            }
            
        }
    }
    Write-Debug "Selector: $SELECTOR"
    Write-Debug "Change Nulls identified: $($NULL_CHANGE_ITEMS.count) for issue: $Key"
    if ($NULL_CHANGE_ITEMS) {
        #Write-Debug "Nulled Change log entry items found for issue [$ISSUE_LINK] in $CHECK_MONTHS months --> $($NULL_CHANGE_ITEMS.count) <-- ..."
        $NULL_CHANGE_ITEMS | ForEach-Object {
            #Write-Debug "Change log entry item for field: $($_.field) - $($_.fieldId) found for issue [$ISSUE_LINK] in $CHECK_MONTHS months..."
            $_ | Add-Member -MemberType NoteProperty -Name 'issue' -Value $ISSUE_LINK
            $_ | Add-Member -MemberType NoteProperty -Name 'key' -Value $Key
            $_ | Add-Member -MemberType NoteProperty -Name 'id' -Value $MAMMA.id
            $_ | Add-Member -MemberType NoteProperty -Name 'created' -Value $MAMMA.created
            $_ | Add-Member -MemberType NoteProperty -Name 'author' -Value $MAMMA.author.emailAddress
            #Write-Debug $_ | Select-Object -Property * -ExcludeProperty psobject
            $FINAL_ITEMS += $_
            # $fieldType = ''
            # $fieldRef = ''
            # switch -regex ($_.field) {
            #     'Service Categories' { $fieldType = 'multi-select'; $fieldRef = 'customfield_10316' }
            #     'Sensitivity Classification' { $fieldType = 'single-select'; $fieldRef = 'customfield_10275' }
            #     Default { $fieldType = 'text' }
            # }
            # Write-Debug "Set-JiraIssueField -ISSUE_KEY $($_.key) -Field_Ref $fieldRef -New_Value $($_.fromString) -FieldType $fieldType"
        }
    }
    $FINAL_ITEMS
}

# Function to list fields with field ID and field name for a Jira Cloud instance
function Get-JiraFields {
    param (
        [Parameter(Mandatory = $false)]
        [switch]$SUPRESS_OUTPUT = $false
    )
    $REST_RESULTS = Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/3/field" -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get -ContentType 'application/json'
    #Write-Debug $REST_RESULTS.getType()
    #Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
    # Write a file with the results to $env:AtlantisPowerKit_PROFILE_NAME-JIRAFields-YYYYMMDD-HHMMSS.json
    if (-not $SUPRESS_OUTPUT) {
        $OUTPUT_FILE = "$env:AtlassianPowerKit_PROFILE_NAME\$env:AtlassianPowerKit_PROFILE_NAME-JIRAFields-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        if (-not (Test-Path $OUTPUT_FILE)) {
            New-Item -ItemType File -Path $OUTPUT_FILE
        }
        $REST_RESULTS | ConvertTo-Json -Depth 10 | Out-File -FilePath $OUTPUT_FILE
        Write-Debug "Jira Fields written to: $OUTPUT_FILE"
    }
    return $REST_RESULTS
}

# Function to create a custom field in Jira Cloud
# https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-fields/#api-rest-api-3-field-post
# Type for OSMEntity is "com.atlassian.jira.plugin.system.customfieldtypes:cascadingselectsearcher"
# # cascadingselectsearcher
function Set-JiraCustomField {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FIELD_NAME,
        [Parameter(Mandatory = $true)]
        [string]$FIELD_TYPE
    )
    $CUSTOM_FIELD_PAYLOAD = @{
        name          = "$FIELD_NAME"
        type          = "$FIELD_TYPE"
        searcherKey   = "com.atlassian.jira.plugin.system.customfieldtypes:$FIELD_TYPE"
        'description' = "OSM custom field for: $FIELD_NAME - support@osm.team"
    }
    try {
        $REST_RESULTS = Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/3/field/search" -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Post -Body ($CUSTOM_FIELD_PAYLOAD | ConvertTo-Json) -ContentType 'application/json'
        Write-Debug $REST_RESULTS.getType()
        Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
    }
    catch {
        Write-Debug ($_ | Select-Object -Property * -ExcludeProperty psobject | Out-String)
        Write-Error "Error updating field: $($_.Exception.Message)"
    }
}

# Function to list all users for a JSM cloud project
function Get-JSMServices {
    # https://community.atlassian.com/t5/Jira-Work-Management-Articles/How-to-automatically-populate-service-related-information-stored/ba-p/2240423
    $JSM_SERVICES_ENDPOINT = "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/service-registry-api/service?query="
    try {
        $REST_RESULTS = Invoke-RestMethod -Uri $JSM_SERVICES_ENDPOINT -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get -ContentType 'application/json'
        Write-Debug $REST_RESULTS.getType()
        Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
    }
    catch {
        Write-Debug ($_ | Select-Object -Property * -ExcludeProperty psobject | Out-String)
        Write-Error "Error updating field: $($_.Exception.Message)"
    }
}

function Get-JSMService {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServiceName
    )
    # https://community.atlassian.com/t5/Jira-Work-Management-Articles/How-to-automatically-populate-service-related-information-stored/ba-p/2240423
    $JSM_SERVICES_ENDPOINT = [uri]::EscapeUriString("https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/service-registry-api/service?query=$ServiceName")
    try {
        $REST_RESULTS = Invoke-RestMethod -Uri $JSM_SERVICES_ENDPOINT -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get -ContentType 'application/json'
        Write-Debug $REST_RESULTS.getType()
        Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
    }
    catch {
        Write-Debug ($_ | Select-Object -Property * -ExcludeProperty psobject | Out-String)
        Write-Error "Error updating field: $($_.Exception.Message)"
    }
}


# Function to list Opsgenie services
function Get-OpsgenieServices {
    $OPSGENIE_SERVICES_ENDPOINT = "https://$($env:AtlassianPowerKit_OpsgenieAPIEndpoint)/v1/services?limit=100&order=asc&offset="
    $OFFSET = 0
    $FINALPAGE = $false
    # Loop through all pages of results and write to a single JSON file
    function collectServices {
        # Create output file with "$OPSGENIE_SERVICES_ENDPOINT-Services-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $OUTPUT_FILE = "$($env:AtlassianPowerKit_OpsgenieAPIEndpoint)-Services-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        if (-not (Test-Path $OUTPUT_FILE)) {
            New-Item -ItemType File -Path $OUTPUT_FILE
        }
        # Start JSON file entry with: { "key": "OpsServiceList", "value": {"Services": [
        $OUTPUT_FILE_CONTENT = "{ `"key`": `"$($env:AtlassianPowerKit_OpsgenieAPIEndpoint)-Services`", `"value`": { `"Services`": ["
        $OUTPUT_FILE_CONTENT | Out-File -FilePath $OUTPUT_FILE
        # Loop through all pages of results and write to the $OUTPUT_FILE (append)
        do {
            Write-Debug "Getting services from $OPSGENIE_SERVICES_ENDPOINT$OFFSET"
            $REST_RESULTS = Invoke-RestMethod -Uri "$OPSGENIE_SERVICES_ENDPOINT$OFFSET" -Headers $($env:AtlassianPowerKit_OpsgenieAPIHeaders) -Method Get -ContentType 'application/json'
            $REST_RESULTS.data | ForEach-Object {
                # Append to file { "id": "$_.id", "name": "$_.name"} ensuring double quotes are used
                $OUTPUT_FILE_CONTENT = "{ `"id`": `"$($_.id)`", `"name`": `"$($_.name)`" }, "
                $OUTPUT_FILE_CONTENT | Out-File -FilePath $OUTPUT_FILE -Append
            }
            #$REST_RESULTS | ConvertTo-Json -Depth 10 | Write-Debug
            # Get next page offset value from   "paging": { 'last': 'https://api.opsgenie.com/v1/services?limit=100&sort=name&offset=100&order=desc'
            if ((($REST_RESULTS.paging.last -split 'offset=')[-1] -split '&')[0] -gt $OFFSET) {
                $OFFSET += 100
            }
            else {
                $FINALPAGE = $true
                # remove the last comma from the file, replace with ]}, ensuring the entire line is written not repeated
                $content = Get-Content $OUTPUT_FILE
                $content[-1] = $content[-1] -replace '},', '}]}}'
                $content | Set-Content $OUTPUT_FILE
                # Test if valid JSON and write to console if it is
                if (Test-Json -Path $OUTPUT_FILE) {
                    Write-Debug "Opsgenie Services JSON file created: $OUTPUT_FILE"
                }
                else {
                    Write-Debug "Opsgenie Services JSON file not created: $OUTPUT_FILE"
                }
            }
        } until ($FINALPAGE)
    }
    collectServices
}

# Funtion to list project properties (JIRA entities)
function Get-JiraProjectIssuesTypes {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JiraCloudProjectKey,
        [Parameter(Mandatory = $false)]
        [string]$OUTPUT_PATH = ".\$env:AtlassianPowerKit_PROFILE_NAME\"
    )
    $FILENAME = "$env:AtlassianPowerKit_PROFILE_NAME-$JiraCloudProjectKey-IssueTypes-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    if (-not (Test-Path $OUTPUT_PATH)) {
        New-Item -ItemType Directory -Path $OUTPUT_PATH
    }
    $OUTPUT_FILE = "$OUTPUT_PATH$FILENAME"
    Write-Debug "Output file: $OUTPUT_FILE"
    # Initiate json file with { "Project": "$JiraCloudProjectKey", "JiraIssueTypes": [
    $OUTPUT_FILE_HEADER = "{ `"Project`": `"$JiraCloudProjectKey`", `"JiraIssueTypes`": ["
    $OUTPUT_FILE_HEADER | Out-File -FilePath $OUTPUT_FILE
    $REST_RESULTS = Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/3/issue/createmeta/$JiraCloudProjectKey/issuetypes" -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get
    Write-Debug $REST_RESULTS.getType()
    foreach ($issueType in $REST_RESULTS.issueTypes) {
        #Write-Debug "############## Issue Type: $($issueType.name) ##############"
        #Write-Debug "Issue Type: $($issueType | Get-Member -MemberType Properties)"
        #Write-Debug "Issue Type ID: $($issueType.id)"
        $ISSUE_FIELDS = Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/3/issue/createmeta/$JiraCloudProjectKey/issuetypes/$($issueType.id)" -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get
        #Write-Debug (ConvertTo-Json $ISSUE_FIELDS -Depth 10)
        #Write-Debug '######################################################################'
        # Append ConvertTo-Json $ISSUE_FIELDS -Depth 10 to the $OUTPUT_FILE
        # Create a JSON object in file to hold the issue type fields
        "{""Issue Type"": ""$($issueType.name)"", ""FieldInfo"":" | Out-File -FilePath $OUTPUT_FILE -Append
        $ISSUE_FIELDS | ConvertTo-Json -Depth 10 | Out-File -FilePath $OUTPUT_FILE -Append
        # Add a comma to the end of the file to separate the issue types
        '},' | Out-File -FilePath $OUTPUT_FILE -Append
    }
    # Remove the last comma from the file, replace with ]}, ensuring the entire line is written not repeated
    $content = Get-Content $OUTPUT_FILE
    $content[-1] = $content[-1] -replace '},', '}]}'
    $PARSED = $content | ConvertFrom-Json
    # Write the content back to the file ensuring JSON formatting is correc
    $PARSED | ConvertTo-Json -Depth 30 | Set-Content $OUTPUT_FILE
    Write-Debug 'Issue Types found: '
    $PARSED.JiraIssueTypes | ForEach-Object {
        $CUSTOM_FIELD_COUNT = ($_.FieldInfo.fields | Where-Object { $_.key -like 'customfield*' }).Count
        Write-Debug "$($_.'Issue Type') - Field Count: $($_.'FieldInfo'.total), Custom Field Count: $CUSTOM_FIELD_COUNT"
    }
    Write-Debug "See Issue Types JSON file created: $OUTPUT_FILE"
}

# Function to get issue type metadata for a Jira Cloud project
function Get-JiraCloudIssueTypeMetadata {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JiraCloudProjectKey
    )
    $REST_RESULTS = Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/3/issue/createmeta/$JiraCloudProjectKey&expand=projects.issuetypes.fields" -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get
    Write-Debug $REST_RESULTS.getType()
    Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
}

# Funtion to print the value project properties (JIRA entity)
function Get-JiraProjectProperties {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JiraCloudProjectKey
    )
    $REST_RESULTS = Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/3/project/$JiraCloudProjectKey/properties" -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get
    Write-Debug $REST_RESULTS.getType()
    Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
}

# Funtion to print the value of a specific project property (JIRA entity)
function Get-JiraProjectProperty {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JiraCloudProjectKey,
        [Parameter(Mandatory = $true)]
        [string]$PROPERTY_KEY
    )
    $REST_RESULTS = Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/3/project/$JiraCloudProjectKey/properties/$PROPERTY_KEY" -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get
    Write-Debug $REST_RESULTS.getType()
    Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
}

# Funtion to put a project property (JIRA entity) - this overwrites!
function Set-JiraProjectProperty {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JiraCloudProjectKey,
        [Parameter(Mandatory = $true)]
        [string]$PROPERTY_KEY,
        [Parameter(Mandatory = $true)]
        [string]$JSON_FILE
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
        $content | Convert-FromJson
        return
    }
    $REST_RESULTS = Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/3/project/$JiraCloudProjectKey/properties/$PROPERTY_KEY" -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Put -Body $content -ContentType 'application/json'
    Write-Debug $REST_RESULTS.getType()
    # Write all of the $REST_RESULTS to the console as PSObjects with all properties
    Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
    Write-Debug '###############################################'
    Write-Debug "Querying the property to confirm the value was set... $PROPERTY_KEY in $JiraCloudProjectKey via $($env:AtlassianPowerKit_AtlassianAPIEndpoint)"
    Get-JiraProjectProperty -JiraCloudProjectKey $JiraCloudProjectKey -PROPERTY_KEY $PROPERTY_KEY
    Write-Debug '###############################################'
}

# Funtion to delete a project property (JIRA entity)
function Clear-JiraProjectProperty {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JiraCloudProjectKey,
        [Parameter(Mandatory = $true)]
        [string]$PROPERTY_KEY
    )
    $REST_RESULTS = Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/3/project/$JiraCloudProjectKey/properties/$PROPERTY_KEY" -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Delete
    Write-Debug $REST_RESULTS.getType()
    Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
    Write-Debug '###############################################'
    Write-Debug "Querying the propertues to confirm the value was deleted... $PROPERTY_KEY in $JiraCloudProjectKey via $($env:AtlassianPowerKit_AtlassianAPIEndpoint)"
    Get-JiraProjectProperties -JiraCloudProjectKey $JiraCloudProjectKey
    Write-Debug '###############################################'
}

# Function to list all users for a JSM cloud project
function Remove-RemoteIssueLink {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JQL_STRING,
        [Parameter(Mandatory = $true)]
        [string]$GLOBAL_LINK_ID
    )
    $GLOBAL_LINK_ID_ENCODED = [System.Web.HttpUtility]::UrlEncode($GLOBAL_LINK_ID)
    Write-Debug "Payload: $GLOBAL_LINK_ID_ENCODE"
    Write-Debug "Global Link ID: $GLOBAL_LINK_ID_ENCODED"

    try {
        $REST_RESULTS = Get-JiraCloudJQLQueryResult -JQL_STRING $JQL_STRING
        $REST_RESULTS.issues | ForEach-Object {
            Write-Debug "Issue Key: $($_.key)"
            Write-Debug "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/3/issue/$($_.key)/remotelink?globalId=$GLOBAL_LINK_ID_ENCODED"
            Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/3/issue/$($_.key)/remotelink?globalId=$GLOBAL_LINK_ID_ENCODED" -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Delete
        }
    }
    catch {
        Write-Debug ($_ | Select-Object -Property * -ExcludeProperty psobject | Out-String)
        Write-Error "Error updating field: $($_.Exception.Message)"
    }
}

# Function to list all roles for a JSM cloud project
function Show-JiraCloudJSMProjectRole {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JiraCloudJSMProjectKey
    )
    $JiraProjectRoles = Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/3/project/$JiraCloudJSMProjectKey/role" -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get
    Write-Debug $JiraProjectRoles.getType()
    $JiraProjectRoles | Get-Member -MemberType Properties | ForEach-Object {
        Write-Debug "$($_.Name) - $($_.Definition) - ID: $($_.Definition.split('/')[-1])"
    }
}