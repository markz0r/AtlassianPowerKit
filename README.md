# AtlassianCloud-PowerKit

- Various functions in PowerShell to interact with JIRA Cloud APIs

## Quick Start

```powershell
git clone 
New-ModuleManifest -Path .\Atlassian-PowerKit.psd1 -RootModule .\Atlassian-PowerKit.psm1

## Usage

```powershell
. .\JiraCloudAPI.ps1 && Get-JiraIssueJSON "HROSM-222"
```

## FunctioAtlassianCloud-PowerKit
- hack for listing functions
- ` Get-ChildItem -Recurse -Filter *.psm1 | ForEach-Object { Select-String -Path $_.FullName -Pattern '^function\s+\w+.*\ ' } | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value } | sort | ForEach-Object{($_ -split "\s+")[1]}`


Export-JiraCloudJQLQueryResultsToJSON
Get-AtlassianGroupMembers
Get-JiraCloudAPIEndpoint
Get-JiraCloudIssueTypeMetadata
Get-JiraCloudJQLQueryResults
Get-JiraCloudJQLQueryResultsPages
Get-JiraCloudJSMProjectRoles
Get-JiraCloudUser
Get-JiraFields
Get-JiraIssueChangeLog
Get-JiraIssueChangeNulls
Get-JiraIssueChangeNullsFromJQL
Get-JiraIssueJSON
Get-JiraProjectIssuesTypes
Get-JiraProjectProperties
Get-JiraProjectProperty
Get-JSMService
Get-JSMServices
Get-OpsgenieAPIEndpoint
Get-OpsgenieServices -- output ready for Set-JIRAProjectProperty (OpsServiceList)
Remove-JiraProjectProperty
Remove-RemoteIssueLink
Set-JiraCloudAPIEndpoint
Set-JiraCustomField
Set-JiraIssueField
Set-JiraProjectProperty


# Get-M365ExchangeAttachmentsBySearch

This PowerShell module provides 2 main functions:

- `Get-M365ExchangeAttachmentsBySearch` allows you to search for and retrieve attachments from Microsoft 365 Exchange mailboxes using a search query based on sent date, sender and subject and attachment name (check psm1 file for more details).

- `Get-M365ExchangeAttachmentsFromSearch` allows you export a previously comp.

## Installation

```powershell
   git clone https://github.com/markz0r/Get-M365ExchangeAttachmentsBySearch.git
   cd .\Get-M365ExchangeAttachmentsBySearch; Import-Module "Get-M365ExchangeAttachmentsBySearch.psd1" -Force
   # To attempt automated installation of dependencies (possibly requires admin rights... but don't think so)
    Get-M365ExchangeAttachments -InstallDepsOnly
```

## Prerequisites

- Windows PowerShell 7.3 or later
- Microsoft 365 Exchange Online account with appropriate permissions
- MS Outlook 2016 or later installed on the machine running the script

## Usage

### Create a new search query and retrieve attachments

```powershell
  Get-M365ExchangeAttachments -MailboxName "user@example.com" -UPN "admin@example.com" -StartDate "2024-04-20" -Subject "Important Policy Docs" -Sender "importantsenderdomainoraddress.com" -AttachmentExtension "pdf"
```

### Retrieve attachments for an existing search query

```powershell
    Get-M365ExchangeAttachmentsFromSearch -AttachmentExtension "pdf" -SkipModules -SkipConnIPS -SkipDownload -SearchName "20240429_015205-Export-Job"
```

## Contributing

Contributions are welcome! If you find any issues or have suggestions for improvements, please open an issue or submit a pull request.

## License

See [LICENSE](LICENSE.md) file.

## Disclaimer

This module is provided as-is without any warranty or support. Use it at your own risk.