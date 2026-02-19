# Sharp Ninja's PowerShell Snippets

A collection of PowerShell profile tools providing a unified package manager abstraction, module auto-loading, Bing search, Oh-My-Posh setup, and developer utilities across Windows, Linux, WSL, and macOS.

[docs](https://ps-services.github.io/Snippets/) 🏗️

## Setup

### Windows

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
| ✅ | ✅ | `bing.ps1` | `bing` | Search Bing from PowerShell. Requires `$env:BingApiKey`. |
| ✅ | ✅ | `clean-folder.ps1` | `clean` | Remove all `bin` and `obj` folders in current path. |
| ✅ | ✅ | `github.ps1` | `hub` | Navigate to GitHub repositories folder. Auto-detects `$env:GITHUB` or set it manually. |
| ✅ | ✅ | `oh-my-posh-*.ps1` | `posh` | Initializes Oh-My-Posh for the current shell (Windows, Linux, or macOS). |
| ✅ | ✅ | `module-loader.ps1` | `modrl` | Auto-loads PowerShell modules from `modules.yml`. Use `modrl` to reload all or `modrl <name>` for one. |
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

## Environment Variables

| Variable | Description |
|----------|-------------|
| `$env:Snippets` | **Required.** Path to the Snippets repository. Set in `$PROFILE.AllUsersAllHosts`. |
| `$env:SnippetsModulesYaml` | Optional. Path to user-specific `modules.yml`. Defaults to `$env:Snippets\modules.yml`. |
| `$env:GITHUB` | Optional. Root of your GitHub repositories folder. Auto-detected if not set. |
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

