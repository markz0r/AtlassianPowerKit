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
function Get-JiraIssueChangeNullsFromJQL {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JQL_STRING
    )
    $REST_RESULTS = Get-JiraCloudJQLQueryResult -JQL_STRING $JQL_STRING
    $REST_RESULTS.issues | ForEach-Object {
        Write-Debug "Getting change nulls for issue: $($_.key)"
        Get-JiraIssueChangeNulls -Key $_.key
    }
}
# Function to list all JSON fields in a JSON object array only if the field contains a value that is not null in at least one object, include example of the field value, don't repeat the field name
function Get-JSONFieldsWithData {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JSON_FILE_PATH
    )
    $EXCLUDED_FIELDS = @('Time to resolution', 'Time to first response', 'customfield_10062', 'assignee', 'aggregatetimeoriginalestimate', 'aws-json-field__ad4c4b0c-406f-47c1-a8e3-df46e38dabf2', 'customfield_10291', 'customfield_10292', 'customfield_10294', 'customfield_10295', 'reporter' )
    $DATA_FIELD_LIST = @{}
    $JSON_OBJECT = Get-Content -Path $JSON_FILE_PATH | ConvertFrom-Json -Depth 30
    # Write a sub-function that gets all fields in a JSON object array that are not null, adding the field to a hash table with key as the field name and value as the field value, if the key already exists, skip, the function takes a JSON object array as a parameter if the field is an object, write the field name and object type is an object, if the field is an array, write the field name and object type is an array, call self with the array as a parameter
    function Search-JSONObjectArray {
        param (
            [Parameter(Mandatory = $true)]
            [object]$JSON_OBJECT
        )
        $JSON_OBJECT | ForEach-Object {
            $OBJECT = $_
            $OBJECT.PSObject.Properties | ForEach-Object {
                if ($null -eq $_.Value -or $_.Key -in $EXCLUDED_FIELDS -or $_.Name -in $EXCLUDED_FIELDS) {
                    return
                }
                if ($_.Value -is [object]) {
                    if ($_.Value -is [array]) {
                        #Write-Debug "Field: $($_.Name) - Type: array"
                        Search-JSONObjectArray -JSON_OBJECT $_.Value
                    }
                    else {
                        #Write-Debug "Field: $($_.Name) - Type: object"
                        Search-JSONObjectArray -JSON_OBJECT $_.Value
                    }
                }
                else {
                    if (-not $DATA_FIELD_LIST.ContainsKey($_.Name)) {
                        $DATA_FIELD_LIST[$_.Name] = $_.Value
                    }
                }
            }
        }
    }
    Search-JSONObjectArray -JSON_OBJECT $JSON_OBJECT
    Write-Debug 'Fields with data:'
    $DATA_FIELD_LIST.GetEnumerator() | ForEach-Object {
        Write-Debug "$($_.Key): $($_.Value)"
    }
}



# Function to remove fields from JSON object array, writing a filtered JSON object array to a file, fields to retain as an array parameter
function Select-JSONExportDataFields {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JSON_FILE_PATH,
        [Parameter(Mandatory = $true)]
        [string[]]$FIELDS_TO_RETAIN
    )
    $JSON_OBJECT = Get-Content -Path $JSON_FILE_PATH | ConvertFrom-Json -Depth 30
    $JSON_FILE_PATH = $JSON_FILE_PATH -replace '.json', '-Filtered.json'
    $JSON_OBJECT | ForEach-Object {
        $OBJECT = $_
        $OBJECT.PSObject.Properties | ForEach-Object {
            if (-not $FIELDS_TO_RETAIN.Contains($_.Name)) {
                $OBJECT.PSObject.Properties.Remove($_.Name)
            }
        }

    }
    $JSON_OBJECT | ConvertTo-Json -Depth | Out-File -FilePath $JSON_FILE_PATH
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
        $JSON_FILE_PATH = "$-JQLExport-$((Get-Date).ToString('yyyyMMdd-HHmmss'))"
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
        [string]$JSON_FILE_PATH,
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
    $JSON_FILE_PREFIX = "$($env:AtlassianPowerKit_AtlassianAPIEndpoint)-JQLExport-$((Get-Date).ToString('yyyyMMdd-HHmmss'))"

    if ($JSON_FILE_PATH) {
        if (-not (Test-Path $JSON_FILE_PATH)) {
            New-Item -ItemType Directory -Path $JSON_FILE_PATH
        }
    }
    else {
        $JSON_FILE_PATH = $JSON_FILE_PREFIX
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
        $jsonFilePath = "$JSON_FILE_PATH\$JSON_FILE_PREFIX-$STARTAT.json"
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
    return $ISSUES_LIST
}

# Function to get change log for a Jira issue
function Get-JiraIssueChangeLog {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Key
    )
    Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/3/issue/$Key/changelog" -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get
}

# Function to edit a Jira issue field given the issue key, field name, and new value
function Set-JiraIssueField {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ISSUE_KEY,
        [Parameter(Mandatory = $true)]
        [string]$Field_Ref,
        [Parameter(Mandatory = $true)]
        [string]$New_Value,
        [Parameter(Mandatory = $true)]
        [string]$FieldType
    )
    $FIELD_PAYLOAD = @{}
    function Set-MutliSelectPayload {
        @{
            update = @{
                $Field_Ref = @(
                    $New_Value.Split(',') | ForEach-Object {
                        @{ add = @{ value = $_ } }
                    }
                )
            }
        }
    }
    Write-Debug "Field Type: $FieldType"
    switch -regex ($FieldType) {
        'multi-select' { $FIELD_PAYLOAD = $(Set-MutliSelectPayload) }
        'single-select' { $FIELD_PAYLOAD = @{fields = @{"$Field_Ref" = @{value = "$New_Value" } } } }
        'text' { $FIELD_PAYLOAD = @{fields = @{"$Field_Ref" = "$New_Value" } } }
        Default { $FIELD_PAYLOAD = @{fields = @{"$Field_Ref" = "$New_Value" } } }
    }

    try {
        Write-Debug "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/3/issue/$ISSUE_KEY&notifyUsers=false&overrideEditableFlag=true"
        Write-Debug $($FIELD_PAYLOAD | ConvertTo-Json -Depth 10)
        Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/3/issue/$ISSUE_KEY" -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Put -Body ($FIELD_PAYLOAD | ConvertTo-Json -Depth 10) -ContentType 'application/json'
        # Write-Debug $REST_RESULTS.getType()
        #Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
    }
    catch {
        Write-Debug 'StatusCode:' $_.Exception.Response.StatusCode.value__
        Write-Debug 'Full:' $_ | Select-Object -Property * -ExcludeProperty psobject
    }
}

# function to get changes from a Jira issue change log that are from a value to null
function Get-JiraIssueChangeNulls {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [Parameter(Mandatory = $false)]
        [string]$Field_Name,
        [Parameter(Mandatory = $false)]
        [string]$Field_ID
    )
    $CHECK_MONTHS = -3
    $EXCLUDED_FIELDS = @('Category', 'BCMS: Disaster Recovery Procedures', 'BCMS: Backup Description', 'Incident Contacts', 'Internal / Third Party service', 'BCMS: RPO', 'BCMS: RTO', 'BCMS: MTDP', 'BCMS: MBCO', 'Persistent data stored', 'Monitoring and Alerting', 'SLA/OLA/OKRs', 'Endpoints', 'Service Criticality', 'Service Type', 'Service Status')
    $CHANGE_LOG = Get-JiraIssueChangeLog -Key $Key
    #$CHANGE_LOG | Get-Member
    if (! $CHANGE_LOG.isLast) {
        Write-Warning 'There are more than 100 changes for this issue. This function only returns the first 100 changes.'
    }
    $ISSUE_LINK = "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/browse/$Key"
    #Write-Debug $($CHANGE_LOG | ConvertTo-Json -Depth 10)
    $NULL_CHANGE_ITEMS = @()
    $CHANGE_LOG.values | ForEach-Object {
        $MAMMA = $_
        $NULL_CHANGE_ITEMS += $MAMMA.items | Where-Object {
            ($MAMMA.created -gt (Get-Date).AddMonths($CHECK_MONTHS)) -and ((-not $_.toString) -and ( -not $_.to)) -and (-not $_.field.StartsWith('BCMS')) -and (-not $EXCLUDED_FIELDS.Contains($_.field))
        }
    }
    if ($NULL_CHANGE_ITEMS) {
        Write-Debug "Nulled Change log entry items found for issue [$ISSUE_LINK] in $CHECK_MONTHS months: $($NULL_CHANGE_ITEMS.count)..." -ForegroundColor Red
        $NULL_CHANGE_ITEMS | ForEach-Object {
            $_ | Add-Member -MemberType NoteProperty -Name 'issue' -Value $ISSUE_LINK
            $_ | Add-Member -MemberType NoteProperty -Name 'key' -Value $Key
            $_ | Add-Member -MemberType NoteProperty -Name 'id' -Value $MAMMA.id
            $_ | Add-Member -MemberType NoteProperty -Name 'created' -Value $MAMMA.created
            $_ | Add-Member -MemberType NoteProperty -Name 'author' -Value $MAMMA.author.emailAddress
            Write-Debug $_ | Select-Object -Property * -ExcludeProperty psobject
            $fieldType = ''
            $fieldRef = ''
            switch -regex ($_.field) {
                'Service Categories' { $fieldType = 'multi-select'; $fieldRef = 'customfield_10316' }
                'Sensitivity Classification' { $fieldType = 'single-select'; $fieldRef = 'customfield_10275' }
                Default { $fieldType = 'text' }
            }
            Set-JiraIssueField -ISSUE_KEY $_.key -Field_Ref $fieldRef -New_Value $_.fromString -FieldType $fieldType
        }
    }
}

# Function to list fields with field ID and field name for a Jira Cloud instance
function Get-JiraFields {
    $REST_RESULTS = Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/3/field" -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get -ContentType 'application/json'
    #Write-Debug $REST_RESULTS.getType()
    #Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
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
        Write-Debug 'StatusCode:' $_.Exception.Response.StatusCode.value__
        Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
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
        Write-Debug 'StatusCode:' $_.Exception.Response.StatusCode.value__
        Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
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
        Write-Debug 'StatusCode:' $_.Exception.Response.StatusCode.value__
        Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
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
        [string]$JiraCloudProjectKey
    )
    $REST_RESULTS = Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/3/issue/createmeta/$JiraCloudProjectKey/issuetypes" -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get
    Write-Debug $REST_RESULTS.getType()
    foreach ($issueType in $REST_RESULTS.issueTypes) {
        Write-Debug "############## Issue Type: $($issueType.name) ##############"
        #Write-Debug "Issue Type: $($issueType | Get-Member -MemberType Properties)"
        Write-Debug "Issue Type ID: $($issueType.id)"
        $ISSUE_FIELDS = Invoke-RestMethod -Uri "https://$($env:AtlassianPowerKit_AtlassianAPIEndpoint)/rest/api/3/issue/createmeta/$JiraCloudProjectKey/issuetypes/$($issueType.id)" -Headers $(ConvertFrom-Json -AsHashtable $env:AtlassianPowerKit_AtlassianAPIHeaders) -Method Get
        Write-Debug (ConvertTo-Json $ISSUE_FIELDS -Depth 10)
        Write-Debug '######################################################################'
    }
    #Write-Debug (ConvertTo-Json $REST_RESULTS -Depth 10)
    # $JiraProjectProperties | Get-Member -MemberType Properties | ForEach-Object {
    #     Write-Debug "$($_.Name) - $($_.Definition) - ID: $($_.Definition.split('/')[-1])"
    # }
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
        Write-Debug 'StatusCode:' $_.Exception.Response.StatusCode.value__
        Write-Debug 'StatusDescription:' $_.Exception.Response.StatusDescription
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