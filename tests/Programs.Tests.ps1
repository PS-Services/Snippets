# Run with powershell.exe -NoProfile -File .\tests\Programs.Tests.ps1 (or pwsh).
# Requires powershell-yaml. Package-manager calls are mocked; nothing is installed.
param([string]$Repository = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
function Assert-ProgramTest($Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('snippets-programs-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$savedYaml = $env:SnippetsProgramsYaml
try {
    $modulePath = Join-Path $Repository 'SnippetsPrograms.psm1'
    $module = Import-Module $modulePath -Force -PassThru
    $nativeResult = & $module {
        Invoke-SnippetsPackageCommand -Source $env:ComSpec -Arguments @('/d', '/c', 'echo fixture-output & exit /b 7')
    }
    Assert-ProgramTest ($nativeResult.ExitCode -eq 7 -and $nativeResult.Output -match 'fixture-output') 'Native command output or failure code was lost'
    $nativeResult = & $module {
        Invoke-SnippetsPackageCommand -Source $env:ComSpec -Arguments @('/d', '/c', 'echo fixture-diagnostic 1>&2 & exit /b 0')
    }
    Assert-ProgramTest ($nativeResult.ExitCode -eq 0 -and $nativeResult.Output -match 'fixture-diagnostic') 'Native stderr handling changed the exit code'
    # Exercise actual bootstrap orchestration with downloaded content and child
    # processes mocked, so it cannot change the test computer.
    & $module {
        function Invoke-WebRequest {
            param($Uri, [switch]$UseBasicParsing, $OutFile, $ErrorAction)
            if ($Uri -ne 'https://get.scoop.sh') { throw 'Unexpected bootstrap URL' }
            'param([switch]$RunAsAdmin)' | Set-Content -LiteralPath $OutFile
        }
        function Invoke-SnippetsPackageCommand {
            param($Source, $Arguments)
            if ($Arguments[0] -ne '-NoProfile' -or $Arguments[3] -ne '-File') { throw 'Bootstrap child arguments are incorrect' }
            $script:BootstrapFile = $Arguments[4]
            $errors = $null
            [Management.Automation.Language.Parser]::ParseFile($script:BootstrapFile, [ref]$null, [ref]$errors) | Out-Null
            if ($errors) { throw 'Generated bootstrap script does not parse' }
            [pscustomobject]@{ ExitCode = 0; Output = 'mock bootstrap complete' }
        }
        Install-SnippetsPackageManager winget | Out-Null
        if (Test-Path -LiteralPath $script:BootstrapFile) { throw 'WinGet bootstrap temporary file leaked' }
        Install-SnippetsPackageManager scoop | Out-Null
        if (Test-Path -LiteralPath $script:BootstrapFile) { throw 'Scoop bootstrap temporary file leaked' }
    }
    & $module {
        $script:Calls = New-Object 'System.Collections.Generic.List[object]'
        $script:Installed = @{}
        $script:Failure = ''
        $script:ChocoVersion = '2.4.0'
        function script:Invoke-SnippetsPackageCommand {
            param([string]$Source, [string[]]$Arguments)
            $script:Calls.Add(@{ Source = $Source; Arguments = $Arguments })
            $id = if ($Source -eq 'winget') { $Arguments[2] } else { $Arguments[1] }
            $key = "${Source}:$id"
            $code = 0
            $output = ''
            if ($Arguments[0] -eq 'install') {
                if ($script:Failure -eq 'install') { $code = 5; $output = 'installation denied' }
                elseif ($script:Failure -eq 'reboot') { $code = 3010 }
                elseif ($script:Failure -ne 'verification') { $script:Installed[$key] = $true }
            } elseif ($script:Failure -eq 'query') {
                $code = 9; $output = 'source unavailable'
            } elseif ($Source -eq 'winget') {
                if (-not $script:Installed[$key]) { $code = -1978335212 }
            } elseif ($Source -eq 'choco') {
                if ($Arguments[0] -eq '--version') { $output = $script:ChocoVersion }
                elseif ($script:Installed[$key]) { $output = "$id|1.0.0" }
            } else {
                $apps = @($script:Installed.Keys | Where-Object { $_ -like 'scoop:*' } | ForEach-Object {
                    @{ Name = (($_ -split ':')[1] -split '/')[-1] }
                })
                $output = @{ apps = $apps } | ConvertTo-Json -Depth 4 -Compress
            }
            [pscustomobject]@{ ExitCode = $code; Output = $output }
        }
    }
    $yamlPath = Join-Path $testRoot 'programs.yml'
    @'
programs:
  - id: Git.Git
    name: Git
    source: winget
    scope: user
    arguments: ['--silent']
  - id: 7zip
    source: choco
  - id: main/jq
    source: scoop
  - id: Disabled.App
    enabled: false
'@ | Set-Content -LiteralPath $yamlPath
    $env:SnippetsProgramsYaml = $yamlPath

    $result = @(Install-SnippetsPrograms -CheckOnly)
    Assert-ProgramTest (@($result | Where-Object Status -eq 'Missing').Count -eq 3) 'CheckOnly did not find missing apps'
    Assert-ProgramTest ($result[3].Status -eq 'Disabled') 'Disabled entry was not skipped'
    $result = @(Install-SnippetsPrograms -WhatIf)
    Assert-ProgramTest (@($result | Where-Object Status -eq 'Would install').Count -eq 3) 'WhatIf plan is incorrect'
    $installCount = & $module { @($script:Calls | Where-Object { $_.Arguments[0] -eq 'install' }).Count }
    Assert-ProgramTest ($installCount -eq 0) 'CheckOnly or WhatIf installed software'

    $result = @(Install-SnippetsPrograms)
    Assert-ProgramTest (@($result | Where-Object Status -eq 'Installed').Count -eq 3) "Install failed: $($result | Out-String)"
    $wingetArgs = & $module { @($script:Calls | Where-Object { $_.Source -eq 'winget' -and $_.Arguments[0] -eq 'install' })[0].Arguments }
    Assert-ProgramTest ($wingetArgs -contains '--silent' -and $wingetArgs -contains '--scope') 'Install arguments lost'
    $result = @(Install-SnippetsPrograms)
    Assert-ProgramTest (@($result | Where-Object Status -eq 'Already installed').Count -eq 3) 'Rerun did not skip installed apps'
    $installCount = & $module { @($script:Calls | Where-Object { $_.Arguments[0] -eq 'install' }).Count }
    Assert-ProgramTest ($installCount -eq 3) 'Rerun installed apps again'
    $result = @(Install-SnippetsPrograms -Name Git)
    Assert-ProgramTest ($result.Count -eq 1 -and $result[0].Id -eq 'Git.Git') 'Name selection failed'
    $caught = $false
    try { Install-SnippetsPrograms -Name NotDefined | Out-Null } catch { $caught = $true }
    Assert-ProgramTest $caught 'Unknown program selection was silently ignored'

    foreach ($failure in @('query', 'install', 'verification')) {
        & $module { param($mode) $script:Installed.Clear(); $script:Calls.Clear(); $script:Failure = $mode } $failure
        $result = @(Install-SnippetsPrograms -Name Git.Git)
        Assert-ProgramTest ($result[0].Status -eq 'Failed') "Failure was ignored: $failure"
        if ($failure -eq 'query') {
            $installCount = & $module { @($script:Calls | Where-Object { $_.Arguments[0] -eq 'install' }).Count }
            Assert-ProgramTest ($installCount -eq 0) 'Query failure caused an installation'
        }
    }
    & $module { $script:Failure = 'reboot' }
    $result = @(Install-SnippetsPrograms -Name 7zip)
    Assert-ProgramTest ($result[0].Status -eq 'Restart required') 'Chocolatey reboot status was lost'
    & $module { $script:Failure = ''; $script:ChocoVersion = '1.4.0'; $script:Calls.Clear() }
    Install-SnippetsPrograms -Name 7zip -CheckOnly | Out-Null
    $oldList = & $module { @($script:Calls | Where-Object { $_.Arguments[0] -eq 'list' })[0].Arguments }
    Assert-ProgramTest ($oldList -contains '--local-only') 'Chocolatey v1 queried remote packages'
    & $module { $script:Failure = 'install' }
    $result = @(Install-SnippetsPrograms)
    Assert-ProgramTest ($result.Count -eq 4 -and @($result | Where-Object Status -eq 'Failed').Count -eq 3) 'A failure prevented results for remaining programs'
    & $module { $script:Failure = '' }

    foreach ($invalid in @(
        'programs: bad',
        "programs:`n  - id: Good.App`n  - id: Bad.App`n    source: unknown",
        "programs:`n  - id: Good.App`n    enabled: 'false'",
        "programs:`n  - id: Good.App`n    arguments: '--silent'",
        "programs:`n  - id: Good.App`n  - id: Good.App"
    )) {
        Set-Content -LiteralPath $yamlPath -Value $invalid
        & $module { $script:Calls.Clear() }
        $caught = $false
        try { Install-SnippetsPrograms | Out-Null } catch { $caught = $true }
        Assert-ProgramTest $caught 'Invalid YAML schema was accepted'
        Assert-ProgramTest ((& $module { $script:Calls.Count }) -eq 0) 'Validation occurred after a package-manager call'
    }

    $existingFile = Join-Path $testRoot 'installed.exe'
    Set-Content -LiteralPath $existingFile -Value 'fixture'
    $escapedPath = $existingFile.Replace("'", "''")
    Set-Content -LiteralPath $yamlPath -Value "programs:`n  - id: Outside.Manager`n    detect:`n      path: '$escapedPath'"
    $result = @(Install-SnippetsPrograms)
    Assert-ProgramTest ($result[0].Status -eq 'Already installed') 'Custom file detection failed'
    Assert-ProgramTest ((& $module { $script:Calls.Count }) -eq 0) 'Custom detection still required a package manager'

    # Required manager bootstraps must run before optional packages, without
    # installing anything in the test process.
    & $module {
        $script:Managers = @{}
        $script:BootstrapFailure = $false
        function script:Get-Command {
            param($Name, $CommandType, $ErrorAction)
            if ($Name -in @('winget', 'scoop', 'choco')) {
                if ($script:Managers[$Name]) { [pscustomobject]@{ Name = $Name } }
            } else { Microsoft.PowerShell.Core\Get-Command $Name -ErrorAction Stop }
        }
        function script:Install-SnippetsPackageManager {
            param($Name)
            $script:Calls.Add(@{ Source = 'bootstrap'; Arguments = @('install', $Name) })
            if ($script:BootstrapFailure) { throw 'mock bootstrap failure' }
            $script:Managers[$Name] = $true
            [pscustomobject]@{ ExitCode = 0; Output = 'manager installed' }
        }
        $script:Calls.Clear()
        $script:Installed.Clear()
    }
    Copy-Item -LiteralPath (Join-Path $Repository 'programs.yml') -Destination $yamlPath -Force
    $result = @(Install-SnippetsPrograms -WhatIf)
    Assert-ProgramTest (@($result | Where-Object Status -eq 'Would install').Count -eq 4) 'Fresh-machine preview failed'
    Assert-ProgramTest ((& $module { $script:Calls.Count }) -eq 0) 'Preview invoked bootstrap or queried a missing manager'
    $result = @(Install-SnippetsPrograms -Name NVM)
    Assert-ProgramTest ($result.Count -eq 4 -and @($result | Where-Object Status -eq 'Installed').Count -eq 4) 'Required dependencies were not installed with selected NVM'
    Assert-ProgramTest (($result.Section -join ',') -eq 'Required,Required,Required,Optional') 'Required/Optional order changed'
    $calls = & $module { $script:Calls.ToArray() }
    Assert-ProgramTest (($calls[0..2].Source -join ',') -eq 'bootstrap,bootstrap,bootstrap') 'Optional packages ran before required managers'
    & $module { $script:Managers.Clear(); $script:Installed.Clear(); $script:Calls.Clear(); $script:BootstrapFailure = $true }
    $result = @(Install-SnippetsPrograms)
    Assert-ProgramTest ($result[-1].Status -eq 'Blocked') 'Required failure did not block Optional'
    Assert-ProgramTest (@($result | Where-Object Status -eq 'Failed').Count -eq 3) 'Remaining Required entries were not attempted'

    @'
Optional:
  - id: Ignored.App
    active: false
Requeired:
  - id: scoop
    source: bootstrap
    active: false
'@ | Set-Content -LiteralPath $yamlPath
    & $module { $script:Calls.Clear() }
    $result = @(Install-SnippetsPrograms)
    Assert-ProgramTest ($result.Count -eq 2 -and @($result | Where-Object Status -eq 'Disabled').Count -eq 2) 'Inactive entries were not skipped'
    Assert-ProgramTest ($result[0].Section -eq 'Required') 'Requeired spelling or section ordering failed'
    Assert-ProgramTest ((& $module { $script:Calls.Count }) -eq 0) 'Inactive entries invoked a manager'
    foreach ($invalid in @(
        "Required:`n  - id: scoop`n    source: bootstrap`n    active: 'false'",
        "Optional:`n  - id: Example.App`n    active: false`n    enabled: true",
        "Required: []`nprograms: []",
        "Required:`n  - id: arbitrary-installer`n    source: bootstrap"
    )) {
        Set-Content -LiteralPath $yamlPath -Value $invalid
        $caught = $false
        try { Install-SnippetsPrograms | Out-Null } catch { $caught = $true }
        Assert-ProgramTest $caught 'Invalid active/section/bootstrap definition was accepted'
    }

    # The actual snippet must register the command without querying/installing programs.
    & $module { $script:Calls.Clear() }
    . (Join-Path $Repository 'programs.ps1') | Out-Null
    Assert-ProgramTest ((Get-Alias apps).Definition -eq 'Install-SnippetsPrograms') 'apps alias missing'
    Assert-ProgramTest ((& $module { $script:Calls.Count }) -eq 0) 'Profile startup executed the program list'
    Write-Output "PASS: YAML validation, detection, install, rerun, selection, preview, failures, providers, and startup on PowerShell $($PSVersionTable.PSVersion)"
} finally {
    $env:SnippetsProgramsYaml = $savedYaml
    Remove-Module SnippetsPrograms -ErrorAction SilentlyContinue
    $resolved = [IO.Path]::GetFullPath($testRoot)
    if ($resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path $resolved -Leaf) -like 'snippets-programs-*') {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
