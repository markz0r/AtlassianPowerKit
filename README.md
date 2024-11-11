# AtlassianPowerKit

- Various functions in PowerShell to interact with Atlassian Cloud APIs

## Quick Start

```powershell
git clone https://github.com/OrganisationServiceManagement/AtlassianPowerKit.git
cd .\AtlassianPowerKit; Import-Module "AtlassianPowerKit.psd1"
AtlassianPowerKit
```

## Usage

```powershell
# Text UI
AtlassianPowerKit
# Direct invocation (after profile configured)
AtlassianPowerKitFunction -FunctionName "Get-JiraIssue" -FunctionParameters @{"Key"="TEST-1"} -Profile "zoak"
```

```docker
# Windows
mkdir .\osm_home
docker run --rm -v ${PWD}\osm_home:/mnt/osm -v "$Env:LOCALAPPDATA\Microsoft\PowerShell\secretmanagement\:/root/.secretmanagement/" -it markz0r/atlassian-powerkit:latest

# Linux
mkdir ./osm_home
docker run -it --rm -v ${PWD}/osm_home:/mnt/osm -v "$HOME/.local/share/powershell/secretmanagement/ "
```

```powershell

## Prerequisites

- Windows PowerShell 7.0 or later

## Contributing

Contributions are welcome! If you find any issues or have suggestions for improvements, please open an issue or submit a pull request.

## License

See [LICENSE](LICENSE.md) file.

## Disclaimer

This module is provided as-is without any warranty or support. Use it at your own risk.
```
