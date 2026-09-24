param([string]$Repository = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
function Assert-ListTest($Condition, $Message) { if (-not $Condition) { throw $Message } }
$fixture = Join-Path ([IO.Path]::GetTempPath()) ('programs-list-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture | Out-Null
try {
    $module = Import-Module (Join-Path $Repository 'SnippetsPrograms.psm1') -Force -PassThru
    & $module {
        $script:UpdateCalls = New-Object 'System.Collections.Generic.List[object]'
        $script:Query = $null
        function script:Invoke-SnippetsPackageCommand {
            param($Source, $Arguments)
            if ($Arguments[0] -notin @('list', 'outdated', 'status')) { throw 'Update check attempted a mutation' }
            $script:UpdateCalls.Add(@{ Source = $Source; Arguments = $Arguments })
            return $script:Query
        }
    }
    $cases = @(
        @{ Source='winget'; Id='Git.Git'; Code=0; Text="Name       Id       Version Available Source`nGit        Git.Git  2.0     3.0       winget"; State='Update available'; Version='3.0' },
        @{ Source='winget'; Id='Git.Git'; Code=-1978335212; Text=''; State='No update reported'; Version='' },
        @{ Source='winget'; Id='Git.Git'; Code=0; Text='unparseable table'; State='Unknown'; Version='' },
        @{ Source='winget'; Id='Git.Git'; Code=1; Text='network failed'; State='Unknown'; Version='' },
        @{ Source='choco'; Id='7zip'; Code=2; Text='7zip|23.0|24.0|false'; State='Update available'; Version='24.0' },
        @{ Source='choco'; Id='7zip'; Code=0; Text=''; State='No update reported'; Version='' },
        @{ Source='choco'; Id='7zip'; Code=0; Text='garbage'; State='Unknown'; Version='' },
        @{ Source='scoop'; Id='main/nvm'; Code=0; Text='Scoop is up to date.'; Items=@([pscustomobject]@{Name='nvm'; 'Installed Version'='1.0'; 'Latest Version'='2.0'; Info='' }); State='Update available'; Version='2.0' },
        @{ Source='scoop'; Id='main/nvm'; Code=0; Text='Everything is ok!'; State='No update reported'; Version='' },
        @{ Source='scoop'; Id='main/nvm'; Code=0; Text='Scoop bucket(s) out of date.'; State='Unknown'; Version='' },
        @{ Source='scoop'; Id='scoop'; Code=0; Text='Scoop out of date.'; State='Update available'; Version='' }
    )
    foreach ($case in $cases) {
        & $module { param($case) $script:Query = [pscustomobject]@{ ExitCode=$case.Code; Output=$case.Text; Items=$case.Items } } $case
        $row = Get-SnippetsRepositoryUpdates -Source $case.Source -Name $case.Id
        Assert-ListTest ($row.UpdateState -eq $case.State -and $row.AvailableVersion -eq $case.Version) "Update parsing failed: $($case.Source) $($case.Text)"
    }

    # Use the actual repos dispatcher (extracted to avoid unrelated module
    # startup) and the actual updates backend, with only process calls mocked.
    Import-Module Microsoft.PowerShell.Utility
    $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $Repository 'SnippetsManager.psm1'), [ref]$null, [ref]$null)
    $dispatcher = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-All' }, $true)
    $dispatcherText = $dispatcher.Extent.Text.Replace('$PSScriptRoot', "'" + $Repository.Replace("'", "''") + "'")
    . ([scriptblock]::Create($dispatcherText))
    Set-Alias repos Invoke-All -Scope Global
    & $module { $script:Query = [pscustomobject]@{ ExitCode=2; Output='7zip|23.0|24.0|false'; Items=@() } }
    $row = repos updates -Source choco -Name 7zip -Raw
    Assert-ListTest ($row.UpdateState -eq 'Update available') 'repos updates failed to dispatch to read-only backend'

    & $module {
        function script:Test-SnippetsProgramInstalled {
            param($Program)
            if ($Program.Id -eq 'Broken.App') { throw 'detection failed' }
            return $Program.Id -ne 'Missing.App'
        }
        $script:UpdateCalls.Clear()
    }
    $yamlPath = Join-Path $fixture 'programs.yml'
    @'
Required:
  - id: 7zip
    source: choco
Optional:
  - id: Missing.App
  - id: Inactive.App
    active: false
  - id: Broken.App
'@ | Set-Content -LiteralPath $yamlPath
    . (Join-Path $Repository 'programs.ps1') | Out-Null
    $rows = @(apps list -Path $yamlPath -Raw)
    Assert-ListTest ($rows.Count -eq 4) 'List omitted YAML entries'
    Assert-ListTest ($rows[0].State -eq 'Installed' -and $rows[0].AvailableVersion -eq '24.0') 'Installed entry/update data missing'
    Assert-ListTest ($rows[1].State -eq 'Missing' -and $rows[1].UpdateState -eq 'Not checked') 'Missing state incorrect'
    Assert-ListTest ($rows[2].State -eq 'Disabled' -and -not $rows[2].Active) 'Inactive state incorrect'
    Assert-ListTest ($rows[3].State -eq 'Unknown' -and $rows[3].Message -match 'detection failed') 'Detection error hidden'
    Assert-ListTest ((& $module { $script:UpdateCalls.Count }) -eq 1) 'Missing/disabled entries checked for updates'
    $rows = @(apps list -Path $yamlPath -Name Missing.App -Raw)
    Assert-ListTest ($rows.Count -eq 1) 'List name filter pulled in unrelated dependencies'
    $display = apps list -Path $yamlPath | Out-String -Width 200
    Assert-ListTest ($display -match 'UpdateState' -and $display -match 'Inactive.App') 'Table view missing status columns'
    Remove-Item Alias:repos
    $rows = @(apps list -Path $yamlPath -Raw)
    Assert-ListTest ($rows[0].State -eq 'Installed' -and $rows[0].UpdateState -eq 'Unknown' -and $rows[0].Message) 'Unavailable repos was reported as current'
    Write-Output "PASS: apps list, real repos dispatch, all update providers, filtering, disabled/missing states, and failures on $($PSVersionTable.PSVersion)"
} finally {
    Remove-Module SnippetsPrograms -ErrorAction SilentlyContinue
    $resolved = [IO.Path]::GetFullPath($fixture)
    if ($resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path $resolved -Leaf) -like 'programs-list-*') { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
