# AtlassianPowerKit

- Various functions in PowerShell to interact with JIRA Cloud APIs

## TODO

## Maybe

- 1password vault integration

## Quick Start

```powershell
git clone https://github.com/markz0r/AtlassianPowerKit.git
cd .\AtlassianPowerKit; Import-Module "AtlassianPowerKit.psd1" -Force
```

## Usage

```powershell
# Text UI
AtlassianPowerKit
# Direct invocation
Invoke-AtlassianPowerKitFunction -FunctionName "Get-JiraIssue" -FunctionParameters @{"Key"="TEST-1"} -Profile "zoak"
```

## Prerequisites

- Windows PowerShell 7.0 or later

## Contributing

Contributions are welcome! If you find any issues or have suggestions for improvements, please open an issue or submit a pull request.

## License

See [LICENSE](LICENSE.md) file.

## Disclaimer

This module is provided as-is without any warranty or support. Use it at your own risk.
