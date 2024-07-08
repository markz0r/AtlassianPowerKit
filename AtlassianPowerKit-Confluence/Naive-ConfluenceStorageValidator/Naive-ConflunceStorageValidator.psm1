# Powershell function that validates a file adheres to https://confluence.atlassian.com/doc/confluence-storage-format-790796544.html
$ErrorActionPreference = 'Stop'; $DebugPreference = 'Continue'
function Test-ConfluenceStorageFormat {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    # Define the replacement map
    $PARSE_REPLACEMENT_MAP = @{
        '&mdash;' = '&#8212;'
        '&rsquo;' = '&#8217;'
        # Add more replacements as needed
    }

    # Declare known prefixes
    $nameSpaceName = 'http://zoak.solutions/schema/confluence/1.0/'
    $prefixes = @('ac', 'ri')

    try {
        # Attempt to load the XML file with namespace handling
        $xmlContent = New-Object System.Xml.XmlDocument 
        # Add known prefixes to the namespace manager
        $namespaceManager = New-Object System.Xml.XmlNamespaceManager($xmlContent.NameTable)
        foreach ($prefix in $prefixes) {
            $namespaceManager.AddNamespace($prefix, 'http://zoak.solutions/schema/confluence/1.0/')
        }
        $xml = Get-Content -Path $FilePath -Raw
        # Apply replacements from the map
        foreach ($key in $PARSE_REPLACEMENT_MAP.Keys) {
            $xml = $xml -replace $key, $PARSE_REPLACEMENT_MAP[$key]
        }
        # Dynamically construct namespace declarations
        $namespaceDeclarations = $prefixes -join "='$nameSpaceName' xmlns:" | ForEach-Object { "xmlns:$_='$nameSpaceName'" }

        # Construct the XML string with dynamic namespaces
        $xml = "<root $namespaceDeclarations>$xml</root>"
        Write-Debug "XML: $xml"
        $xmlContent.LoadXml($xml)
    }
    catch {
        Write-Host "Failed to load XML content: $_"
        return
    }

    # Check for common root elements in Confluence Storage Format
    $requiredElements = @('ac:layout')
    $expectedElements = @('ac:structured-macro', 'ac:parameter', 'ac:rich-text-body', 'ri:attachment', 'ri:page')

    $isValid = $true

    foreach ($element in $requiredElements) {
        if (-not $xmlContent.OuterXml.Contains($element)) {
            Write-Error "ERROR: Required element not found: $element"
            $isValid = $false
        }
    }

    foreach ($element in $expectedElements) {
        if (-not $xmlContent.OuterXml.Contains($element)) {
            Write-Debug "INFO: Comment element not found: $element"
        }
    }

    if ($isValid) {
        Write-Debug "Success - $FilePath adheres to the basic structure of the Confluence Storage Format."
    }
    else {
        Write-Error "$FilePath does not adhere to the basic structure of the Confluence Storage Format."    
    }
}