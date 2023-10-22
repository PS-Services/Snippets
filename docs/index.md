[Tutorial](https://thesharp.ninja/powershell-snippets-tutorial-de75728ba5b0)

# Powershell Snippets System

## Supported Platforms

### Windows

* Windows PowerShell 4.5
* Powershell Core 6.\*, 7.\*

#### Repositories

| Alias | Repo | Use `sudo` | Notes |
| :---: | :--- | :--------: | :---- |
| wg | winget | no | Defaults to `winget` store.<br/>Add `-Store` parameter to change. |
| scp | scoop | no | Defaults to `main` bucket.<br/>Add `-Store` parameter to change. |
| ch | choco | yes | Always adds `-y` parameter |

### Linux

* Powershell Core 6.\*, 7.\*

#### Repositories

| Alias | Repo | Use `sudo` | Notes |
| :---: | :--- | :--------: | :---- |
| ap | apt | yes | Adds `-y` parameter as appropriate. |
| br | brew | no |  |
| sn | snap | yes |  |

## Features

### Standard Snippets

| Platform | Snippet File | Alias | Description |
| :------- | :----------- | :---: | :---------- |
| Windows, Linux | clean-folder.ps1 | `clean` | Usage: `clean -r -f` Removes all `obj` and `bin` folders recursively. |
| Windows | chocolatey.ps1 | N/A | Automatically imports the Chocolatey Profile module. |
| Windows | devmode.ps1 | `devmode` | Loads the Visual Studio Developer Powershell Module for the default VS instance. |
| Windows, Linux | gh_completions.ps1 | N/A | Imports the GitHub CLI completions for PowerShell. |
| Windows, Linux | github.ps1 | `hub` | Set-Location to the first directory found name `github` |
| Windows | oh-my-posh-windows.ps1 | `posh` | Installs (if necessary), Initializes and Executes OH-MY-POSH with the themplate named `ninja.omp.json` |
| Linux | oh-my-posh-linus.ps1 | `posh` | Installs (if necessary), Initializes and Executes OH-MY-POSH with the themplate named `ninja.omp.json` |
| Windows, Linux | _repos.ps1 | `repos` | Applies command specified to all package managers. |
| Linux | _repos.ps1 | `ap` | Applies command via `apt` |
| Linux | _repos.ps1 | `br` | Applies command via `brew` |
| Linux | _repos.ps1 | `sn` | Applies command via `snap` |
| Windows | _repos.ps1 | `wg` | Applies command via `winget` |
| Windows | _repos.ps1 | `scp` | Applies command via `scoop` |
| Windows | _repos.ps1 | `ch` | Applies command via `choco` |
| Windows, Linux | update-snippet.ps1 | `snipps` | Set-Location to the folder where PowerShell Snippets is installed. |
| Windows, Linux | update-snippet.ps1 | `snipup` | Pulls the latest version of PowerShell Snippets from GitHub and updates `$PROFILE` with latest code. |
