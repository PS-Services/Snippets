# Sharp Ninja's Powershell Snippets

A collection of PowerShell tools you can add to your profile.

[docs](https://ps-services.github.io/Snippets/) 🏗️

## Windows

1. Clone this repository to `$env:OneDrive/Documents/Snippets`
2. In an Administrator elevated editor, edit `$PROFILE.AllUsersAllHosts`.
3. Add `$env:Snippets="$env:OneDrive/Documents/PowerShell/Snippets"` to the end and save it.

## Linux, WSL, MacOS

1. Clone this repository to `/opt/microsoft/powershell/7/Snippets`
2. In an Administrator elevated editor, edit `$PROFILE.AllUsersAllHosts`.
3. Add `$env:Snippets="/opt/microsoft/powershell/7/Snippets"` to the end and save it.

___OR___

Execute this script...

```bash
curl 'https://raw.githubusercontent.com/PS-Services/Snippets/master/linux-setup.sh' -v | /bin/bash
```

| Win | *nix | Script           | Description                                                                                                                  |
|-----|------|------------------|------------------------------------------------------------------------------------------------------------------------------|
| :white_check_mark: | :white_check_mark:  | bing.ps1         | Search Bing from Powershell.                                                                                                 |
| :white_check_mark: | :white_check_mark:  | clean&#x2011;folder.ps1 | Remove all `bin` and `obj` folders in current path.                                                                          |
| :white_check_mark: | :white_check_mark:  | github.ps1       | **_Set `$env:GITHUB` first to the root of your github repositories._**  Use `hub` or `hub <repository>` to go to those folders. |
| :white_check_mark: | :white_check_mark:  | oh&#x2011;my&#x2011;posh.ps1   | Initializes Oh-My-Posh for the current PowerShell
| :white_check_mark: | :white_check_mark:  | _repos.ps1       | A unified repository query system. |
| :white_check_mark: |  | chocolatey.ps1   | Setup Chocolatey profile in PowerShell.                                                                                      |
| :white_check_mark: |  | devmode.ps1      | Startup VS 2022 Dev Mode Tools.                                                                                              |

Place calls to these files in your `$PROFILE`

All scripts work in both PowerShell Core and Windows PowerShell 5.1!

## Example Windows `$PROFILE`

```powershell
$env:Snippets="$env:OneDrive\Documents\PowerShell\Snippets"

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
        Write-Verbose "No directory found at [$env:Snippets]" -Verbose:$Verbose~
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

## Example Linux, Wsl, MacOS `$PROFILE`

```powershell
# $env:VerboseStartup = 'true'
$profileScript = Split-Path $PROFILE -Leaf

if((-not $env:Snippets) -or (-not (Test-Path $env:Snippets))) {
    $env:Snippets = "$env:HOME/.config/powershell"
}

if ($env:VerboseStartup -eq 'true') {
    [switch]$MasterVerbose = $true
}
else {
    [switch]$MasterVerbose = $false
}

try {
    Push-Location -Verbose:$MasterVerbose

    Import-Module Microsoft.PowerShell.Utility #-Verbose:$MasterVerbose

    $env:Snippets = Join-Path $env:Snippets -Child Snippets -Verbose:$MasterVerbose

    if (-not (Test-Path $env:Snippets -Verbose:$MasterVerbose)) {
        git clone "https://github.com/sharpninja/Snippets.git"
    } else {
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
            "[$profileScript] No snippets where executed."
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
    | Format-Table Name, Description -AutoSize -Verbose:$MasterVerbose

Write-Verbose 'PowerShell Ready.' -Verbose:$MasterVerbose
```

## Repositories

### Common

- `dn` dotnet
- `dt` dotnet tool
- `np` NPM
- `pp` pip
- `pps` pip-search

### Windows

- `repos` Search all OS repos
- `wq` winget
- `scp` scoop
- `ch` chocolatey

### Linux

- `repos` Search all OS repos
- `ap` apt
- `zy` zypper
- `sn` snap
- `br` homebrew

