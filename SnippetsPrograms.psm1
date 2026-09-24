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
        $output = @(& $command @Arguments 2>&1)
        $succeeded = $?
        $exitCode = $LASTEXITCODE
        if (-not $succeeded -and $exitCode -eq 0) { $exitCode = 1 }
        [pscustomobject]@{ ExitCode = $exitCode; Output = ($output | Out-String).Trim() }
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
    if ($config -isnot [System.Collections.IDictionary] -or -not $config.Contains('programs') -or
        $config.programs -isnot [System.Collections.IList]) {
        throw "Expected a YAML 'programs' list in '$Path'. Use programs: [] for an empty list."
    }
    $seen = @{}
    foreach ($entry in $config.programs) {
        if ($entry -isnot [System.Collections.IDictionary]) { throw 'Each program must be a YAML mapping with an id.' }
        $id = [string]$entry.id
        if ($id -notmatch '^[A-Za-z0-9][A-Za-z0-9._+/-]*$') { throw "Invalid program id '$id'. Use an exact package ID." }
        $source = if ($entry.source) { ([string]$entry.source).ToLowerInvariant() } else { 'winget' }
        if ($source -notin @('winget', 'choco', 'scoop')) { throw "Unsupported source '$source' for '$id'." }
        if ($seen.ContainsKey("${source}:$id")) { throw "Duplicate program '${source}:$id'." }
        $seen["${source}:$id"] = $true
        if ($entry.Contains('enabled') -and $entry.enabled -isnot [bool]) { throw "enabled must be true or false for '$id'." }
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
            Enabled = -not $entry.Contains('enabled') -or $entry.enabled
            Scope = [string]$entry.scope
            Arguments = [string[]]@($entry.arguments)
            Detect = $detect
        }
    }
}

function Test-SnippetsProgramInstalled {
    param($Program)
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
        $programs = @($programs | Where-Object { $_.Id -in $Name -or $_.Name -in $Name })
    }
    foreach ($program in $programs) {
        $result = [ordered]@{ Name = $program.Name; Id = $program.Id; Source = $program.Source; Status = ''; Message = ''; ExitCode = $null }
        try {
            if (-not $program.Enabled) { $result.Status = 'Disabled' }
            elseif (Test-SnippetsProgramInstalled $program) { $result.Status = 'Already installed' }
            elseif ($CheckOnly) { $result.Status = 'Missing' }
            elseif (-not $PSCmdlet.ShouldProcess("$($program.Source):$($program.Id)", 'Install missing program')) {
                $result.Status = if ($WhatIfPreference) { 'Would install' } else { 'Skipped' }
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
        [pscustomobject]$result
    }
}

Export-ModuleMember -Function Install-SnippetsPrograms
