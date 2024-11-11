# Run.ps1

# Set the environment variable if needed
$env:OSM_HOME = '/mnt/osm'
$env:OSM_INSTALL = '/opt/osm'

# Import necessary modules
Import-Module -Name Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore -Force
Set-Location /opt/osm/AtlassianPowerKit
Import-Module /opt/osm/AtlassianPowerKit/AtlassianPowerKit.psd1 -Force
$env:SECRETSTORE_PATH = $env:OSM_HOME


# Check if arguments were passed to the script
if ($args.Count -gt 0) {
    # Run AtlassianPowerKit with the provided arguments
    AtlassianPowerKit @args
}
else {
    # Default command
    Write-Output 'No arguments provided. Starting Atlassian PowerKit...'
    AtlassianPowerKit 
}

## We can override the default command by passing the command as an argument to the script, e.g.:
## docker run -v osm_home:/mnt/osm --rm --mount osm_home:/mnt/osm -ti markz0r/atlassian-powerkit:latest -FunctionName Get-JiraCloudJQLQueryResult -FunctionParameters @{"JQLQuery"="project in (GRCOSM, HROSM)"}'