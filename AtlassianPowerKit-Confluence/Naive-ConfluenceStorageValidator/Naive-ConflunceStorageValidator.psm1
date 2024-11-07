# Powershell function that validates a file adheres to https://confluence.atlassian.com/doc/confluence-storage-format-790796544.html
$ErrorActionPreference = 'Stop'; $DebugPreference = 'Continue'
function Compress-ConfluenceStorageFormat {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    # Define the replacement map
    $PARSE_REPLACEMENT_MAP = @{
        '&mdash;'  = '&#8212;'
        '&rsquo;'  = '&#8217;'
        '&lsquo;'  = '&#8216;'
        '&ldquo;'  = '&#8220;'
        '&rdquo;'  = '&#8221;'
        '&ndash;'  = '&#8211;'
        '&hellip;' = '&#8230;'
        '&amp;'    = '&'
        '&lt;'     = '<'
        '&gt;'     = '>'
        '&quot;'   = '"'
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
            $namespaceManager.AddNamespace($prefix, $nameSpaceName)
        }
        $xml = Get-Content -Path $FilePath -Raw
        # Apply replacements from the map
        foreach ($key in $PARSE_REPLACEMENT_MAP.Keys) {
            $xml = $xml -replace [regex]::Escape($key), $PARSE_REPLACEMENT_MAP[$key]
        }
        # Dynamically construct namespace declarations
        $namespaceDeclarations = $prefixes | ForEach-Object { "xmlns:$_='$nameSpaceName'" } -join ' '

        # Construct the XML string with dynamic namespaces
        $xml = "<root $namespaceDeclarations>$xml</root>"
        Write-Debug "XML before compression: $xml"
        $xmlContent.LoadXml($xml)

        # Remove unnecessary whitespace, carriage returns, and line breaks
        $compressedXml = $xmlContent.OuterXml -replace '\s+', ' ' -replace '>\s+<', '><'

        Write-Debug "Compressed XML: $compressedXml"

        # Save the compressed XML content
        $compressedFilePath = [System.IO.Path]::ChangeExtension($FilePath, '.compressed.xml')
        [System.IO.File]::WriteAllText($compressedFilePath, $compressedXml)
    }
    catch {
        Write-Output "Failed to load or compress XML content: $_"
        return
    }

    Write-Debug "Success - Compressed XML content saved to $compressedFilePath"
}