# Compatible with Windows PowerShell 5.1 and PowerShell 7.

function Invoke-SnippetsPackageCommand {
    param([string]$Source, [string[]]$Arguments)
    $command = Get-Command $Source -CommandType Application, ExternalScript -ErrorAction Stop
    $savedExitCode = $global:LASTEXITCODE
    $savedPreference = $ErrorActionPreference
    try {
        $global:LASTEXITCODE = 0
        $PSNativeCommandUseErrorActionPreference = $false
        $ErrorActionPreference = 'Continue'
        $output = @(& $command @Arguments 2>&1 6>&1)
        $succeeded = $?
        $exitCode = $LASTEXITCODE
        if (-not $succeeded -and $exitCode -eq 0) { $exitCode = 1 }
        [pscustomobject]@{ ExitCode = $exitCode; Output = ($output | Out-String).Trim(); Items = $output }
    } finally {
        $global:LASTEXITCODE = $savedExitCode
        $ErrorActionPreference = $savedPreference
    }
}

function Read-SnippetsPrograms {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Programs YAML file not found: $Path" }
    try { Import-Module powershell-yaml -ErrorAction Stop -Verbose:$false }
    catch { throw 'The powershell-yaml module is required. Run Install-Module powershell-yaml -Scope CurrentUser, then retry.' }
    $config = ConvertFrom-Yaml (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop) -ErrorAction Stop
    if ($config -isnot [System.Collections.IDictionary]) { throw "Expected Required and Optional YAML lists in '$Path'." }
    if ($config.Contains('Requeired')) {
        if ($config.Contains('Required')) { throw 'Use Required or Requeired, not both.' }
        $config['Required'] = $config.Requeired
    }
    $sections = @('Required', 'Optional')
    if ($config.Contains('programs')) {
        if ($config.Contains('Required') -or $config.Contains('Optional')) { throw 'Do not mix programs with Required/Optional sections.' }
        $sections = @('programs')
    } elseif (-not $config.Contains('Required') -and -not $config.Contains('Optional')) {
        throw "Expected Required and Optional lists in '$Path'."
    }
    foreach ($section in $sections) {
        if ($config.Contains($section) -and $config[$section] -isnot [System.Collections.IList]) {
            throw "$section must be a YAML list; use ${section}: [] for an empty section."
        }
    }
    $seen = @{}
    foreach ($section in $sections) {
    foreach ($entry in $config[$section]) {
        if ($entry -isnot [System.Collections.IDictionary]) { throw 'Each program must be a YAML mapping with an id.' }
        $id = [string]$entry.id
        if ($id -notmatch '^[A-Za-z0-9][A-Za-z0-9._+/-]*$') { throw "Invalid program id '$id'. Use an exact package ID." }
        $source = if ($entry.source) { ([string]$entry.source).ToLowerInvariant() } else { 'winget' }
        if ($source -notin @('winget', 'choco', 'scoop', 'bootstrap')) { throw "Unsupported source '$source' for '$id'." }
        if ($source -eq 'bootstrap' -and $id -notin @('winget', 'scoop', 'choco')) { throw "Unsupported bootstrap program '$id'." }
        if ($seen.ContainsKey("${source}:$id")) { throw "Duplicate program '${source}:$id'." }
        $seen["${source}:$id"] = $true
        if ($entry.Contains('enabled') -and $entry.enabled -isnot [bool]) { throw "enabled must be true or false for '$id'." }
        if ($entry.Contains('active') -and $entry.active -isnot [bool]) { throw "active must be true or false for '$id'." }
        if ($entry.Contains('active') -and $entry.Contains('enabled') -and $entry.active -ne $entry.enabled) {
            throw "active and enabled disagree for '$id'; use active only."
        }
        if ($source -eq 'bootstrap' -and ($entry.Contains('arguments') -or $entry.Contains('detect'))) {
            throw "Bootstrap entries use built-in detection and arguments ('$id')."
        }
        if ($entry.scope -and ($source -ne 'winget' -or $entry.scope -notin @('user', 'machine'))) {
            throw "scope is supported only for winget and must be user or machine ('$id')."
        }
        if ($entry.Contains('arguments')) {
            if ($entry.arguments -isnot [System.Collections.IList]) { throw "arguments must be a YAML list for '$id'." }
            foreach ($argument in $entry.arguments) {
                if ($argument -isnot [string]) { throw "Each argument must be a quoted string for '$id'." }
            }
        }
        $detect = $entry.detect
        if ($detect) {
            if ($detect -isnot [System.Collections.IDictionary]) { throw "detect must be a mapping for '$id'." }
            foreach ($key in $detect.Keys) {
                if ($key -notin @('command', 'path') -or $detect[$key] -isnot [string] -or -not $detect[$key]) {
                    throw "detect supports nonempty command and path strings only ('$id')."
                }
            }
        }
        [pscustomobject]@{
            Id = $id
            Name = if ($entry.name) { [string]$entry.name } else { $id }
            Source = $source
            Section = if ($section -eq 'programs') { 'Optional' } else { $section }
            Active = if ($entry.Contains('active')) { $entry.active } else { -not $entry.Contains('enabled') -or $entry.enabled }
            Scope = [string]$entry.scope
            Arguments = [string[]]@($entry.arguments)
            Detect = $detect
        }
    }
    }
}

function Install-SnippetsPackageManager {
    param([ValidateSet('winget', 'scoop', 'choco')][string]$Name)
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($Name -eq 'choco' -and -not $isAdmin) { throw 'Open PowerShell as administrator to install Chocolatey, then rerun apps.' }
    $installerPath = Join-Path ([IO.Path]::GetTempPath()) ('snippets-bootstrap-' + [guid]::NewGuid().ToString('N') + '.ps1')
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        if ($Name -eq 'winget') {
            @'
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -Scope CurrentUser -Force -ErrorAction Stop | Out-Null
}
if (-not (Get-Module Microsoft.WinGet.Client -ListAvailable)) {
    $options = @{ Name = 'Microsoft.WinGet.Client'; Scope = 'CurrentUser'; Repository = 'PSGallery'; Force = $true; ErrorAction = 'Stop' }
    if ((Get-Command Install-Module).Parameters.ContainsKey('AcceptLicense')) { $options.AcceptLicense = $true }
    Install-Module @options
}
Import-Module Microsoft.WinGet.Client -ErrorAction Stop
Repair-WinGetPackageManager -Latest -Force -ErrorAction Stop
'@ | Set-Content -LiteralPath $installerPath -Encoding UTF8 -ErrorAction Stop
        } else {
            $uri = if ($Name -eq 'scoop') { 'https://get.scoop.sh' } else { 'https://community.chocolatey.org/install.ps1' }
            Invoke-WebRequest -Uri $uri -UseBasicParsing -OutFile $installerPath -ErrorAction Stop
        }
        $shellName = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh.exe' } else { 'powershell.exe' }
        $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $installerPath)
        if ($Name -eq 'scoop' -and $isAdmin) { $arguments += '-RunAsAdmin' }
        $result = Invoke-SnippetsPackageCommand (Join-Path $PSHOME $shellName) $arguments
        if ($result.ExitCode -ne 0) { throw "$Name bootstrap failed ($($result.ExitCode)): $($result.Output)" }
        foreach ($scope in @('Machine', 'User')) {
            foreach ($entry in ([Environment]::GetEnvironmentVariable('Path', $scope) -split ';')) {
                if ($entry -and $entry -notin ($env:Path -split ';')) { $env:Path += ";$entry" }
            }
        }
        return $result
    } finally {
        if (Test-Path -LiteralPath $installerPath) { Remove-Item -LiteralPath $installerPath -Force }
    }
}

function Test-SnippetsProgramInstalled {
    param($Program)
    if ($Program.Source -eq 'bootstrap') {
        return [bool](Get-Command $Program.Id -CommandType Application, ExternalScript -ErrorAction SilentlyContinue)
    }
    if ($Program.Detect) {
        if ($Program.Detect.command -and (Get-Command $Program.Detect.command -CommandType Application, ExternalScript -ErrorAction SilentlyContinue)) { return $true }
        if ($Program.Detect.path -and (Test-Path -LiteralPath ([Environment]::ExpandEnvironmentVariables($Program.Detect.path)))) { return $true }
    }
    switch ($Program.Source) {
        'winget' {
            $arguments = @('list', '--id', $Program.Id, '--exact', '--accept-source-agreements', '--disable-interactivity')
            $query = Invoke-SnippetsPackageCommand winget $arguments
            if ($query.ExitCode -eq 0) { return $true }
            # APPINSTALLER_CLI_ERROR_NO_APPLICATIONS_FOUND; other failures are not absence.
            if ($query.ExitCode -eq -1978335212 -or $query.ExitCode -eq 2316632084) { return $false }
            throw "WinGet detection failed ($($query.ExitCode)): $($query.Output)"
        }
        'choco' {
            $version = Invoke-SnippetsPackageCommand choco @('--version')
            if ($version.ExitCode -ne 0 -or $version.Output -notmatch '^(\d+)\.') { throw "Cannot determine Chocolatey version: $($version.Output)" }
            $arguments = @('list', $Program.Id, '--exact', '--limit-output')
            if ([int]$Matches[1] -lt 2) { $arguments += '--local-only' }
            $query = Invoke-SnippetsPackageCommand choco $arguments
            if ($query.ExitCode -ne 0) { throw "Chocolatey detection failed ($($query.ExitCode)): $($query.Output)" }
            return $query.Output -match ('(?im)^' + [regex]::Escape($Program.Id) + '\|')
        }
        'scoop' {
            $query = Invoke-SnippetsPackageCommand scoop @('export')
            if ($query.ExitCode -ne 0) { throw "Scoop detection failed ($($query.ExitCode)): $($query.Output)" }
            $inventory = ConvertFrom-Json $query.Output -ErrorAction Stop
            if (-not $inventory.PSObject.Properties['apps']) { throw 'Scoop export did not return an apps inventory.' }
            $appName = ($Program.Id -split '/')[-1]
            return @($inventory.apps | Where-Object { $_.Name -ieq $appName }).Count -gt 0
        }
    }
}

function Install-SnippetsPrograms {
    <#
    .SYNOPSIS
    Install missing programs from programs.yml using WinGet, Chocolatey, or Scoop.
    .EXAMPLE
    Install-SnippetsPrograms -WhatIf
    .EXAMPLE
    Install-SnippetsPrograms -Name Git.Git -Path C:\Config\programs.yml
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$Path,
        [string[]]$Name,
        [switch]$CheckOnly
    )
    if ($env:OS -ne 'Windows_NT') { throw 'This program installer currently supports Windows.' }
    if (-not $Path) {
        $Path = if ($env:SnippetsProgramsYaml) { $env:SnippetsProgramsYaml } else { Join-Path $PSScriptRoot 'programs.yml' }
    }
    # Validate the complete definition before running any package manager.
    $programs = @(Read-SnippetsPrograms -Path $Path)
    if ($Name) {
        foreach ($requested in $Name) {
            if (-not @($programs | Where-Object { $_.Id -ieq $requested -or $_.Name -ieq $requested }).Count) {
                throw "Program '$requested' is not defined in '$Path'."
            }
        }
        $programs = @($programs | Where-Object { $_.Section -eq 'Required' -or $_.Id -in $Name -or $_.Name -in $Name })
    }
    $requiredFailed = $false
    $pendingManagers = @{}
    foreach ($program in $programs) {
        $result = [ordered]@{ Name = $program.Name; Id = $program.Id; Section = $program.Section; Source = $program.Source; Status = ''; Message = ''; ExitCode = $null }
        try {
            if (-not $program.Active) { $result.Status = 'Disabled' }
            elseif ($program.Section -eq 'Optional' -and $requiredFailed) {
                $result.Status = 'Blocked'; $result.Message = 'A required entry failed or was skipped. Resolve it and rerun apps.'
            }
            elseif (($CheckOnly -or $WhatIfPreference) -and $pendingManagers.ContainsKey($program.Source)) {
                $result.Status = if ($CheckOnly) { 'Missing' } else { 'Would install' }
                $result.Message = 'Detection is deferred until the required package manager is installed.'
            }
            elseif (Test-SnippetsProgramInstalled $program) { $result.Status = 'Already installed' }
            elseif ($CheckOnly) { $result.Status = 'Missing' }
            elseif (-not $PSCmdlet.ShouldProcess("$($program.Source):$($program.Id)", 'Install missing program')) {
                $result.Status = if ($WhatIfPreference) { 'Would install' } else { 'Skipped' }
            } else {
                if ($program.Source -eq 'bootstrap') {
                    $install = Install-SnippetsPackageManager $program.Id
                } else {
                $arguments = switch ($program.Source) {
                    'winget' {
                        @('install', '--id', $program.Id, '--exact', '--source', 'winget', '--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity')
                        if ($program.Scope) { @('--scope', $program.Scope) }
                    }
                    'choco' { @('install', $program.Id, '--yes', '--no-progress') }
                    'scoop' { @('install', $program.Id) }
                }
                $arguments = @($arguments) + @($program.Arguments | Where-Object { $null -ne $_ })
                $install = Invoke-SnippetsPackageCommand $program.Source $arguments
                }
                $result.ExitCode = $install.ExitCode
                $result.Message = $install.Output
                if ($program.Source -eq 'choco' -and $install.ExitCode -in @(1641, 3010)) {
                    $result.Status = 'Restart required'
                } elseif ($install.ExitCode -ne 0) {
                    throw "Installation failed ($($install.ExitCode)): $($install.Output)"
                } elseif (-not (Test-SnippetsProgramInstalled $program)) {
                    throw 'Installer reported success, but the program was not detected afterward.'
                } else { $result.Status = 'Installed' }
            }
        } catch {
            $result.Status = 'Failed'
            $result.Message = $_.Exception.Message
        }
        if ($program.Section -eq 'Required' -and $result.Status -in @('Failed', 'Skipped', 'Restart required')) { $requiredFailed = $true }
        if ($program.Source -eq 'bootstrap' -and $result.Status -in @('Missing', 'Would install')) { $pendingManagers[$program.Id] = $true }
        [pscustomobject]$result
    }
}

function Get-SnippetsRepositoryUpdates {
    # Read-only backend for repos updates. Never invoke upgrade/install commands.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][ValidateSet('winget', 'scoop', 'choco')][string]$Source,
        [Parameter(Mandatory = $true)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._+/-]*$')][string]$Name
    )
    $row = [ordered]@{ Source = $Source; Id = $Name; UpdateState = 'Unknown'; InstalledVersion = ''; AvailableVersion = ''; Message = '' }
    try {
        switch ($Source) {
            'winget' {
                $query = Invoke-SnippetsPackageCommand winget @('list', '--id', $Name, '--exact', '--upgrade-available', '--accept-source-agreements', '--disable-interactivity')
                if ($query.ExitCode -in @(-1978335212, 2316632084)) { $row.UpdateState = 'No update reported' }
                elseif ($query.ExitCode -ne 0) { throw "WinGet update check failed ($($query.ExitCode)): $($query.Output)" }
                elseif ($query.Output -match ('(?im)(?:^|\s)' + [regex]::Escape($Name) + '\s+(\S+)\s+(\S+)')) {
                    $row.UpdateState = 'Update available'
                    $row.InstalledVersion = $Matches[1]
                    $row.AvailableVersion = $Matches[2]
                } else { $row.Message = 'WinGet returned no recognizable exact package row; output may be truncated or localized.' }
            }
            'choco' {
                $query = Invoke-SnippetsPackageCommand choco @('outdated', '--limit-output', '--no-color')
                if ($query.ExitCode -notin @(0, 2)) { throw "Chocolatey update check failed ($($query.ExitCode)): $($query.Output)" }
                $row.UpdateState = 'No update reported'
                if ($query.Output -match ('(?im)^' + [regex]::Escape($Name) + '\|([^|]+)\|([^|\r\n]+)')) {
                    $row.UpdateState = 'Update available'
                    $row.InstalledVersion = $Matches[1]
                    $row.AvailableVersion = $Matches[2]
                } elseif ($query.Output.Trim() -and $query.Output -notmatch '(?m)^[^|\r\n]+\|[^|\r\n]+\|[^|\r\n]+\|(?:true|false)\s*$') {
                    $row.UpdateState = 'Unknown'
                    $row.Message = 'Chocolatey returned unrecognized update output.'
                }
            }
            'scoop' {
                $query = Invoke-SnippetsPackageCommand scoop @('status')
                if ($query.ExitCode -ne 0) { throw "Scoop update check failed ($($query.ExitCode)): $($query.Output)" }
                $appName = ($Name -split '/')[-1]
                $item = @($query.Items | Where-Object { $_.Name -ieq $appName -and $_.PSObject.Properties['Latest Version'] } | Select-Object -First 1)
                if ($appName -eq 'scoop' -and $query.Output -match 'Scoop out of date') {
                    $row.UpdateState = 'Update available'
                } elseif ($item.Count) {
                    $row.InstalledVersion = [string]$item[0].'Installed Version'
                    $row.AvailableVersion = [string]$item[0].'Latest Version'
                    $row.UpdateState = if ($row.AvailableVersion) { 'Update available' } else { 'No update reported' }
                    $row.Message = [string]$item[0].Info
                } elseif ($query.Output -match 'Everything is ok!' -and $query.Output -notmatch 'out of date|failed|error') {
                    $row.UpdateState = 'No update reported'
                } elseif ($appName -eq 'scoop' -and $query.Output -match 'Scoop is up to date') {
                    $row.UpdateState = 'No update reported'
                } elseif (@($query.Items | Where-Object { $_.PSObject.Properties['Latest Version'] }).Count -and $query.Output -notmatch 'out of date|network|fatal:') {
                    $row.UpdateState = 'No update reported'
                } else { $row.Message = 'Scoop did not confirm current package metadata; inspect repos updates output or refresh Scoop buckets.' }
                if ($query.Output -match 'bucket\(s\) out of date|network|fatal:') {
                    $row.Message = 'Scoop bucket metadata may be stale; available versions reflect local manifests.'
                }
            }
        }
    } catch { $row.Message = $_.Exception.Message }
    [pscustomobject]$row
}

function Get-SnippetsPrograms {
    [CmdletBinding()]
    param([string]$Path, [string[]]$Name)
    if (-not $Path) {
        $Path = if ($env:SnippetsProgramsYaml) { $env:SnippetsProgramsYaml } else { Join-Path $PSScriptRoot 'programs.yml' }
    }
    $programs = @(Read-SnippetsPrograms -Path $Path)
    if ($Name) {
        foreach ($requested in $Name) {
            if (-not @($programs | Where-Object { $_.Id -ieq $requested -or $_.Name -ieq $requested }).Count) { throw "Program '$requested' is not defined in '$Path'." }
        }
        $programs = @($programs | Where-Object { $_.Id -in $Name -or $_.Name -in $Name })
    }
    foreach ($program in $programs) {
        $row = [ordered]@{
            Name = $program.Name; Id = $program.Id; Section = $program.Section; Active = $program.Active
            Source = $program.Source; State = 'Unknown'; UpdateState = 'Not checked'
            InstalledVersion = ''; AvailableVersion = ''; Message = ''
        }
        try {
            if (-not $program.Active) { $row.State = 'Disabled' }
            elseif (-not (Test-SnippetsProgramInstalled $program)) { $row.State = 'Missing' }
            else {
                $row.State = 'Installed'
                $row.UpdateState = 'Unknown'
                $source = $program.Source
                $id = $program.Id
                if ($source -eq 'bootstrap') {
                    $source = $id.ToLowerInvariant()
                    if ($source -eq 'winget') { $id = 'Microsoft.AppInstaller' }
                    if ($source -eq 'choco') { $id = 'chocolatey' }
                }
                $reposCommand = Get-Command repos -ErrorAction Stop
                $updates = @(& $reposCommand -Command updates -Name $id -Source $source -Raw -ErrorAction Stop)
                $update = @($updates | Where-Object { $_.Id -ieq $id -and $_.Source -ieq $source } | Select-Object -First 1)
                if (-not $update.Count) { throw 'repos returned no matching update status.' }
                $row.UpdateState = $update[0].UpdateState
                $row.InstalledVersion = $update[0].InstalledVersion
                $row.AvailableVersion = $update[0].AvailableVersion
                $row.Message = $update[0].Message
            }
        } catch { $row.Message = $_.Exception.Message }
        [pscustomobject]$row
    }
}

function Invoke-SnippetsPrograms {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Position = 0)][ValidateSet('install', 'list')][string]$Command = 'install',
        [string]$Path,
        [string[]]$Name,
        [switch]$CheckOnly,
        [switch]$Raw
    )
    $options = @{}
    if ($Path) { $options.Path = $Path }
    if ($Name) { $options.Name = $Name }
    if ($Command -eq 'list') {
        if ($Raw) { Get-SnippetsPrograms @options }
        else { Get-SnippetsPrograms @options | Format-Table Name, Section, Active, State, UpdateState, InstalledVersion, AvailableVersion -AutoSize }
    } else {
        if ($PSBoundParameters.ContainsKey('WhatIf')) { $options.WhatIf = $PSBoundParameters.WhatIf }
        if ($PSBoundParameters.ContainsKey('Confirm')) { $options.Confirm = $PSBoundParameters.Confirm }
        Install-SnippetsPrograms @options -CheckOnly:$CheckOnly
    }
}

Export-ModuleMember -Function Install-SnippetsPrograms, Get-SnippetsPrograms, Invoke-SnippetsPrograms, Get-SnippetsRepositoryUpdates
