function ParseJIRAIssueJSONForConfluence {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$JSON_PART_FILE
    )
    $REPLACE_FILTER = @{}

    # Write-Output "JSON_PART_FILE: $JSON_PART_FILE"  
    $HASH_ARRAYLIST = @(
        Get-Content $JSON_PART_FILE -Raw | ConvertFrom-Json -Depth 100 | ForEach-Object {
    
            $ISSUE_Key = $_.key
            $ISSUE_FIELDS = $_.fields
            # Write-Output '----------------------'
            # Write-Output "Key: $ISSUE_Key"
            # Write-Output 'FIELDS:  --------------'
            $FIELDS_HASH = @{}
            $ISSUE_FIELDS | Get-Member -MemberType Properties | ForEach-Object {
                #Write-Debug "------- $($ISSUE_Key): $($_.Name) -------"
                # Get the value of the field
                $FIELD_NAME = $($_.Name)
                $FIELD_VALUE = $ISSUE_FIELDS.$FIELD_NAME
    
                # Check if the value is not null
                $RETURN_STRING = ''
                if ($null -ne $FIELD_VALUE) {
                    $valueType = $FIELD_VALUE.GetType().Name
                    #Write-Debug "$FIELD_NAME : $FIELD_VALUE ------------------------ $valueType"
        
                    switch ($valueType) {
                        'PSCustomObject' {
                            # Handle PSCustomObject values
                            if ($FIELD_VALUE.PSObject.Properties['iconUrl']) { 
                                $RETURN_STRING += '<ac:image ac:align="center" ac:layout="center" ac:width="20" ac:height="20" ><ri:url ri:value=' + $FIELD_VALUE.PSObject.Properties['iconUrl'] + ' /></ac:image>' 
                            }
                            elseif ($FIELD_VALUE.PSObject.Properties['value']) { 
                                $RETURN_STRING += $FIELD_VALUE.PSObject.Properties['value']
                                $RETURN_STRING = [string]($RETURN_STRING -replace '"', '')
                            }
                            else {
                                # Return all properties and values as a string
                                $FIELD_VALUE.PSObject.Properties | ForEach-Object {
                                    $RETURN_STRING += "$($_.Name): $($_.Value)"
                                }
                                $RETURN_STRING += "`n (unparsed PSCustomObject)"
                                $RETURN_STRING = [string]($RETURN_STRING -replace '"', '')
                            }   
                        }
                        'System.Object[]' {
                            # Handle array values
                            #Write-Output 'Array value:'
                            $RETURN_STRING += $FIELD_VALUE | ForEach-Object {
                                $RETURN_STRING += "$_"
                            }
                            $RETURN_STRING += "`n (unparsed PSCustomObject)"
                            $RETURN_STRING = [string]($RETURN_STRING -replace '"', '')
                        }
                        'Object[]' {
                            # Handle arrays of objects
                            #Write-Debug 'Object[] value:'
                            $DISPLAY_NAMES = @()
                            foreach ($item in $FIELD_VALUE) {
                                if ($item -is [PSCustomObject]) {
                                    if ($item.PSObject.Properties['displayName']) { 
                                        $DISPLAY_NAMES += "* $($item.displayName)"
                                    }
                                    elseif ($item.PSObject.Properties['value']) { 
                                        $DISPLAY_NAMES += "* $($item.value)"
                                    }
                                    elseif ($item.PSObject.Properties['name']) { 
                                        $DISPLAY_NAMES += "* $($item.name)"
                                    }
                                    elseif ($item.PSObject.Properties['emailAddress']) { 
                                        $DISPLAY_NAMES += "* $($item.emailAddress)"
                                    }
                                    elseif ($item.PSObject.Properties['key']) { 
                                        $DISPLAY_NAMES += "* $($item.key)"
                                    }
                                    else {
                                        $DISPLAY_NAMES += "* $($item)"
                                    }
                                }
                            }
                            if ($DISPLAY_NAMES.Count -gt 0) {
                                $RETURN_STRING = [string]($DISPLAY_NAMES -join ' ')
                            }
                            else {
                                $RETURN_STRING = [string]$FIELD_VALUE
                                $RETURN_STRING = [string]($RETURN_STRING -replace '"', '')
                            }
                        }
                        default {
                            # Handle other types of values
                            # Remove leading 'string '
                            $RETURN_STRING = [string]$FIELD_VALUE
                        
                        }
                    }
                    # Remove leading and trailing whitespace, quotes, and commas
                    $RETURN_STRING = [string]($RETURN_STRING -replace '^string ', '')
                    $RETURN_STRING = [string]($RETURN_STRING -replace 'value=', '')
                    $RETURN_STRING = $RETURN_STRING.Trim().Trim('"').Trim(',')
                } 
                else {
                    $RETURN_STRING = 'NULL'
                }
                $FIELDS_HASH[$FIELD_NAME] = $RETURN_STRING
            }
            $RETURN_HASH = @{
                'Key'    = $ISSUE_Key
                'Fields' = $FIELDS_HASH
            }
            return $RETURN_HASH
        }
    )
    return $HASH_ARRAYLIST
}