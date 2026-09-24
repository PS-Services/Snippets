# Sharp Ninja's PowerShell Snippets

A collection of PowerShell profile tools providing unified package manager access, YAML-backed alias management, module auto-loading, Bing search, Oh-My-Posh setup, and developer utilities across Windows, Linux, WSL, and macOS.

[docs](https://ps-services.github.io/Snippets/) 🏗️

## Setup

### Windows

For Windows PowerShell 5.1, run the installer from this checkout:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows-setup.ps1
```

Or download and run it directly from GitHub in Windows PowerShell 5.1:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
irm https://raw.githubusercontent.com/PS-Services/Snippets/master/windows-setup.ps1 | iex
```

The download command uses `irm` (`Invoke-RestMethod`). With `iwr`
(`Invoke-WebRequest`), use `-UseBasicParsing` and pass `.Content` to `iex`.
Downloaded setup clones into `Documents\PowerShell\Snippets` and requires Git.

Setup installs Oh My Posh when missing, using WinGet or the
[official installer](https://ohmyposh.dev/docs/installation/windows) when WinGet
is unavailable. It refreshes the session PATH and verifies the executable before
writing profiles. Normal profile startup also tries WinGet when Oh My Posh is
missing, refreshes PATH, and registers `posh` only after successful initialization.

The installer reuses this checkout and configures both current-user profiles:
`Documents\WindowsPowerShell\profile.ps1` for Windows PowerShell 5.1 and
`Documents\PowerShell\profile.ps1` for PowerShell 7, covering all hosts in each edition.
It preserves unrelated profile content and backs up an existing profile before
changing it. Rerunning setup replaces the Snippets block without duplicating it.
Setup also backs up and removes old Snippets blocks from console and VS Code
host-specific profiles so each shell loads Snippets once through `profile.ps1`.
Open a new PowerShell session afterward. The installer does not load
snippets; normal startup can install modules configured in `modules.yml`.

Use `-WhatIf` to preview, or `-Destination C:\Tools\Snippets` to clone into a new
location (requires Git). `-ProfilePath` targets only the specified profile instead
of both defaults. Setup configures profiles but does not install PowerShell 7. No .NET SDK
or PowerShell 7 installation is needed for setup. `-ExecutionPolicy Bypass` only
applies to the installer process. Setup checks the policy used by future sessions;
if it blocks profiles, use `-EnableScripts` to set `RemoteSigned` for the current
user, or run the `Set-ExecutionPolicy` command above. Administrator-managed policies
are respected and must be addressed by your administrator.

Manual setup:

1. Clone this repository to `$env:OneDrive\Documents\PowerShell\Snippets`
2. In an Administrator elevated editor, edit `$PROFILE.AllUsersAllHosts`.
3. Add `$env:Snippets="$env:OneDrive\Documents\PowerShell\Snippets"` to the end and save it.

### Linux, WSL, macOS

1. Clone this repository to `~/.config/powershell/Snippets`
2. In an Administrator elevated editor, edit `$PROFILE.AllUsersAllHosts`.
3. Add `$env:Snippets="$env:HOME/.config/powershell/Snippets"` to the end and save it.

___OR___

Execute this script:

```bash
curl 'https://raw.githubusercontent.com/PS-Services/Snippets/master/linux-setup.sh' -v | /bin/bash
```

## Scripts

| Win | \*nix | Script | Alias | Description |
|-----|-------|--------|-------|-------------|
| Yes | | `programs.ps1` | `apps` | Install missing programs from `programs.yml` on command. Supports WinGet, Chocolatey, and Scoop. |
| ✅ | ✅ | `bing.ps1` | `bing` | Search Bing from PowerShell. Requires `$env:BingApiKey`. |
| ✅ | ✅ | `clean-folder.ps1` | `clean` | Remove all `bin` and `obj` folders in current path. |
| ✅ | ✅ | `github.ps1` | `hub` | Navigate to GitHub repositories folder. Auto-detects `$env:GITHUB` or set it manually. |
| ✅ | ✅ | `oh-my-posh-*.ps1` | `posh` | Initializes Oh-My-Posh for the current shell (Windows, Linux, or macOS). |
| ✅ | ✅ | `module-loader.ps1` | `modrl` | Auto-loads PowerShell modules from `modules.yml`. Use `modrl` to reload all or `modrl <name>` for one. |
| ✅ | ✅ | `_aliases.ps1` | `als` | Loads alias mappings from `aliases.yml` and manages them through the alias manager module. |
| ✅ | ✅ | `update-snippets.ps1` | `snipup` / `profileup` | Update Snippets or Profile from GitHub. |
| ✅ | ✅ | `_common.ps1` | `snipps` | Bootstrap script. Navigate to Snippets folder with `snipps`. |
| ✅ | ✅ | `_repos.ps1` | _(see Repositories)_ | Unified package manager query system. |
| ✅ | | `chocolatey.ps1` | | Setup Chocolatey profile in PowerShell. |
| ✅ | | `devmode.ps1` | `devmode` | Start VS 2022 Developer Mode Tools. |

All scripts work in both PowerShell Core and Windows PowerShell 5.1.

## Module Auto-Loader

Modules can be declaratively defined in a `modules.yml` file and will be automatically installed (from PSGallery) and imported during profile initialization. The `powershell-yaml` module is used for YAML parsing and will be auto-installed if missing. If `powershell-yaml` cannot be installed (e.g., no network), the auto-loader degrades gracefully and skips module loading.

### Configuration Path

By default, the loader reads `$env:Snippets\modules.yml`. To use a user-specific configuration (recommended), set `$env:SnippetsModulesYaml` in your `$PROFILE` **before** the Snippets block:

```powershell
$env:Snippets = "$env:OneDrive\Documents\PowerShell\Snippets"
$env:SnippetsModulesYaml = "$env:USERPROFILE\modules.yml"
```

### `modules.yml` Schema

```yaml
modules:
  - name: ModuleName          # Required. Module name.
    version: "1.0.0"          # Optional. Minimum required version (SemVer pre-release suffixes stripped).
    source: PSGallery          # Optional. "PSGallery" (default) or a file path to a .psd1/.psm1.
    required: true             # Optional. Default true. If false, failure is non-fatal.
    parameters: []             # Optional. Arguments passed to Import-Module -ArgumentList.
```

### Behavior

- **PSGallery modules**: Installed automatically to `CurrentUser` scope if missing or below the specified version.
- **Path-based modules**: Imported directly from the specified `.psd1` or `.psm1` file path.
- **Required modules** (`required: true`): Raise an error if they fail to load.
- **Optional modules** (`required: false`): Fail silently with a verbose message.
- **`powershell-yaml`**: Always loaded first as the YAML parser; include it in your `modules.yml` to make the dependency explicit.
- **Reload**: Use `modrl` to reload all modules from YAML, or `modrl <ModuleName>` to reload a single module.

### Example

```yaml
modules:
  - name: powershell-yaml
    required: true
  - name: posh-git
    required: false
  - name: Terminal-Icons
    required: false
    version: "0.11.0"
  - name: MsixTools
    source: "E:\\github\\remote-agent\\scripts\\MsixTools\\MsixTools.psd1"
    required: false
```

## Program Installer

The `apps` snippet installs missing programs from YAML when explicitly invoked.
Loading your profile only registers the command. It follows [FreshBuild's](https://github.com/PS-Services/FreshBuild)
per-program package-source approach with WinGet, Chocolatey, and Scoop.

```powershell
apps list                            # YAML entries, install state, and updates via repos
apps list -Raw                       # Return objects instead of the display table
apps -CheckOnly                      # Report installed/missing programs
apps -WhatIf                         # Preview installations
apps                                 # Install missing programs
apps -Name Git.Git                    # Select exact IDs or display names
apps -Path C:\Config\programs.yml     # Use another definition
```

`apps list` shows `Name`, `Section`, `Active`, `State`, `UpdateState`, and versions
when reported by the manager. Missing and inactive entries remain in the list;
inactive entries are shown as `Disabled` without running detection or update checks.
Use `apps list -Name NVM` to filter, or `apps list -Raw | Format-List` to include
diagnostic messages. Listing does not install missing Required entries and never
upgrades software.

Update checks go through `repos updates -Source <winget|scoop|choco> -Name <id>`.
This read-only command uses WinGet's update-filtered `list`, Chocolatey's
`outdated`, and Scoop's `status`. It does not call `repos upgrade`. Failed checks
or unrecognized output are `Unknown`, not a claim that software is current.
`No update reported` reflects the manager's available metadata; Scoop may report
stale buckets, which are not upgraded by this command. Load the normal profile
to register `repos`; if unavailable, the list retains install state and reports
an unknown update state with a diagnostic.

Configuration defaults to `programs.yml` beside the snippet. Set
`$env:SnippetsProgramsYaml` in your profile to use a personal file. The shipped
list contains required package managers and optional NVM:

```yaml
Required:
  - id: winget
    source: bootstrap
    active: true
  - id: scoop
    source: bootstrap
    active: true
  - id: choco
    source: bootstrap
    active: true
Optional:
  - id: main/nvm
    name: NVM
    source: scoop
    active: true
```

`id` is the exact package ID; `source` defaults to `winget`. Optional fields:
`name` (display name), `active` (boolean, defaults to true), `arguments` (a list of quoted argument
strings), and `scope` (`user` or `machine`, WinGet only). Optional `detect.command`
or `detect.path` recognizes programs installed outside the selected manager;
paths support `%ENVIRONMENT_VARIABLE%` expansion. Otherwise detection uses the
manager's installed-package inventory. WinGet installations use the `winget`
repository. Scoop bucket names may be included in IDs, such as `main/jq`.

Set `active: false` to skip an entry without deleting it. Required entries run
first, regardless of YAML key order; a failed or declined required installation
blocks Optional entries. All active Optional entries run when you invoke `apps`.
`apps -Name NVM` includes the Required entries before NVM. Inactive Required
entries are intentionally skipped. Legacy `programs` lists and `enabled` flags
remain supported; do not mix the old list with the new sections. `Requeired` is
also accepted as an alias for `Required`.

The command requires `powershell-yaml` (included in `modules.yml`). Built-in
`source: bootstrap` entries support only `winget`, `scoop`, and `choco`. They use
Microsoft's `Microsoft.WinGet.Client` repair command or the official Scoop and
Chocolatey installers, then refresh PATH and verify command availability.
Use an administrator PowerShell session when installing Chocolatey. Scoop is
installed for the current user, including when the shell is elevated. These
bootstraps run only through `apps`, never at profile startup. No arbitrary
installer script or URL is read from YAML.
Installed programs are skipped; this command does not upgrade them or enforce
versions. Detection errors prevent installation of the affected program.

Results are objects with `Name`, `Id`, `Section`, `Source`, `Status`, `Message`, and `ExitCode`.
Installation failures do not stop remaining Required entries or unrelated
Optional entries; inspect `Status = Failed` and `Status = Blocked`:

```powershell
$results = apps
$results | Where-Object Status -eq Failed | Format-List
```

The complete YAML list is validated before any package manager runs. Both
`-CheckOnly` and `-WhatIf` perform detection without installing programs.
Run `powershell.exe -NoProfile -File .\tests\Programs.Tests.ps1` and
`powershell.exe -NoProfile -File .\tests\ProgramsList.Tests.ps1` (or use `pwsh`)
for the regression tests; these mock package managers and install no software.

## Alias Manager

The alias manager loads alias mappings from `aliases.yml` during startup and exposes the `als` snippet alias for managing them. It supports plain PowerShell aliases and wrapper commands backed by generated functions.

### Configuration Path

By default, the loader reads `$env:Snippets\aliases.yml`. To use a user-specific alias file, set `$env:SnippetsAliasesYaml` in your `$PROFILE` before the Snippets block:

```powershell
$env:Snippets = "$env:OneDrive\Documents\PowerShell\Snippets"
$env:SnippetsAliasesYaml = "$env:USERPROFILE\aliases.yml"
```

### `aliases.yml` Schema

```yaml
aliases:
  - name: ll
    type: alias
    target: Get-ChildItem
    description: Directory listing
    category: navigation
    scope: Global
    enabled: true

  - name: gst
    type: wrapper
    command: git status
    description: Git status wrapper
    category: git
    scope: Global
    enabled: true

  - name: cdx
    type: wrapper
    command: hub $Name; codex 'Start $start-mcp-session'
    parameters:
      - Name
    description: Jump to a repo and start an MCP Codex flow
    category: mcp
    scope: Global
    enabled: true
```

### Behavior

- **Plain aliases**: Applied with `Set-Alias` when the target command already exists.
- **Wrapper aliases**: Materialized as generated functions so fixed command lines and extra arguments both work.
- **Parameterized wrappers**: Declare `parameters` and reference them in `command` as `$ParameterName` or `${ParameterName}`.
- **Conflicts**: Existing commands are skipped with a warning during startup.
- **Overwrite flow**: `Add-SnippetsAlias` prompts before replacing an existing mapping; `-Force` overwrites immediately.
- **Objects**: `New-SnippetsAliasEntry` creates row-shaped objects that `Add-SnippetsAlias` accepts directly, and `Get-SnippetsAlias -Raw` returns those same objects.

### Examples

```powershell
als list
als add ll Get-ChildItem
als add gst "git status" -Type wrapper
als add cdx 'hub $Name; codex ''Start $start-mcp-session''' -Type wrapper -Parameters Name

$entry = New-SnippetsAliasEntry -Name ga -Value "git add" -Type wrapper -Category git
Add-SnippetsAlias -InputObject $entry -Force
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `$env:Snippets` | **Required.** Path to the Snippets repository. Set in `$PROFILE.AllUsersAllHosts`. |
| `$env:SnippetsModulesYaml` | Optional. Path to user-specific `modules.yml`. Defaults to `$env:Snippets\modules.yml`. |
| `$env:SnippetsAliasesYaml` | Optional. Path to user-specific `aliases.yml`. Defaults to `$env:Snippets\aliases.yml`. |
| `$env:GITHUB` | Optional. Root of your GitHub repositories folder. Defaults to `C:\GitHub` on Windows; auto-detected on other platforms. Existing values are preserved. |
| `$env:BingApiKey` | Optional. Bing Search API subscription key for the `bing` alias. |
| `$env:VerboseStartup` | Optional. Set to `'true'` for verbose profile startup output. |

## Example Windows `$PROFILE`

```powershell
$env:Snippets = "$env:OneDrive\Documents\PowerShell\Snippets"
$env:SnippetsModulesYaml = "$env:USERPROFILE\modules.yml"

if ($env:VerboseStartup -eq 'true') {
    [switch]$Verbose = $true
}
else {
    [switch]$Verbose = $false
}

Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process

try {
    Import-Module Microsoft.PowerShell.Utility

    if (Test-Path $env:Snippets) {
        Push-Location
        Set-Location $env:Snippets
        $snippets = Get-ChildItem *.ps1
        Pop-Location

        $snippets.FullName | ForEach-Object -Process {
            $snippet = $_
            . $snippet -Verbose:$Verbose
        }
    }
    else {
        Write-Verbose "No directory found at [$env:Snippets]" -Verbose:$Verbose
    }

    Write-Verbose 'PowerShell Ready.' -Verbose:$Verbose
}
catch {
    Write-Host $Error
}
finally {
    Write-Verbose "Leaving $Profile" -Verbose:$Verbose
}
```

## Example Linux, WSL, macOS `$PROFILE`

```powershell
# $env:VerboseStartup = 'true'
$profileScript = Split-Path $PROFILE -Leaf

if ((-not $env:Snippets) -or (-not (Test-Path $env:Snippets))) {
    $env:Snippets = "$env:HOME/.config/powershell"
}

$env:SnippetsModulesYaml = "$env:HOME/modules.yml"

if ($env:VerboseStartup -eq 'true') {
    [switch]$MasterVerbose = $true
}
else {
    [switch]$MasterVerbose = $false
}

try {
    Push-Location -Verbose:$MasterVerbose

    Import-Module Microsoft.PowerShell.Utility

    $env:Snippets = Join-Path $env:Snippets -ChildPath Snippets -Verbose:$MasterVerbose

    if (-not (Test-Path $env:Snippets -Verbose:$MasterVerbose)) {
        git clone "https://github.com/PS-Services/Snippets.git"
    }
    else {
        Write-Verbose "[$profileScript] Found $env:Snippets" -Verbose:$MasterVerbose
    }

    if (Test-Path $env:Snippets -Verbose:$MasterVerbose) {
        Push-Location -Verbose:$MasterVerbose
        Set-Location $env:Snippets -Verbose:$MasterVerbose
        $snippets = Get-ChildItem *.ps1 -Verbose:$MasterVerbose -Exclude _common.ps1
        Pop-Location -Verbose:$MasterVerbose

        $resultList = @()
        $snippets.FullName | ForEach-Object -Verbose:$MasterVerbose -Process {
            try {
                $snippet = $_
                $snippetName = Split-Path $snippet -Leaf
                Write-Verbose "[$profileScript]->[$snippetName] Calling with: -Verbose:`$$MasterVerbose" -Verbose:$MasterVerbose
                $result = $null
                $result = . $snippet -Verbose:$MasterVerbose
            }
            catch {
                Write-Error "[$profileScript]->[$snippetName] Error: $_"
            }
            finally {
                $report = "[$snippetName]->[ $result ]"
                $resultList += $report;
            }
        }

        if ($resultList.Length -gt 0) {
            "[$profileScript] Snippet Results`n---`n$([System.String]::Join("`n", $resultList))`n---`n"
        }
        else {
            "[$profileScript] No snippets were executed."
        }
    }
    else {
        Write-Verbose "[$profileScript] No directory found at [$env:Snippets]" -Verbose:$MasterVerbose
    }
}
catch {
    Write-Error "[$profileScript] $_"
}
finally {
    Pop-Location
    Write-Verbose "Leaving $Profile" -Verbose:$MasterVerbose
}

Get-Alias -Verbose:$MasterVerbose `
    | Where-Object -Property Description -imatch 'snippet' -Verbose:$MasterVerbose `
    | Sort-Object -Property Description, Name -Verbose:$MasterVerbose `
    | Format-Table Name, Description -AutoSize -Verbose:$MasterVerbose

Write-Verbose 'PowerShell Ready.' -Verbose:$MasterVerbose
```

## Repositories

The unified repository system (`_repos.ps1`) provides a single interface to query and manage packages across multiple package managers.

### Common (All Platforms)

| Alias | Manager |
|-------|---------|
| `dn` | dotnet |
| `dt` | dotnet tool |
| `ng` | NuGet |
| `np` | NPM |
| `pp` | pip |
| `pps` | pip-search |
| `psg` | PSGallery |

### Windows

| Alias | Manager |
|-------|---------|
| `repos` | Search all OS repos |
| `wg` | winget |
| `scp` | scoop |
| `ch` | chocolatey |

### Linux / macOS

| Alias | Manager |
|-------|---------|
| `repos` | Search all OS repos |
| `ap` | apt |
| `zy` | zypper |
| `sn` | snap |
| `br` | homebrew |

### Usage

Each alias accepts a command followed by arguments: `<alias> <command> <package>`

Common commands: `search`, `install`, `uninstall`, `update`, `list`, `show`

```ps
repos search oh-my-posh

Repo       Command
----       -------
scoop      install oh-my-posh@18.5.0
sudo choco install oh-my-posh --version 18.5.0 -y
winget     install XP8K0HKJFRXGCK -s msstore # oh-my-posh
```

```ps
psg search posh-git

Repo      Command
----      -------
PSGallery Install-Module posh-git -MinimumVersion 1.1.0 -Scope CurrentUser
```

