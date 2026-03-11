param([switch]$VerboseSwitch = $false)

$Verbose = $VerboseSwitch
$script = $MyInvocation.MyCommand

if (-not $env:SnippetsInitialized) {
    $fileInfo = New-Object System.IO.FileInfo (Get-Item $PSScriptRoot).FullName
    $path = $fileInfo.Directory.FullName
    $commonPath = Join-Path $path -ChildPath 'Snippets\_common.ps1'
    if (-not (Test-Path $commonPath)) {
        $commonPath = Join-Path $path -ChildPath '_common.ps1'
    }

    . $commonPath
    Initialize-Snippets -Verbose:$Verbose
}

$moduleRoot = if ($env:Snippets) { $env:Snippets } else { $PSScriptRoot }
$modulePath = Join-Path $moduleRoot -ChildPath 'SnippetsAliasManager.psm1'
if (-not (Test-Path $modulePath)) {
    throw [ErrorRecord]::new("Cannot locate ``SnippetsAliasManager.psm1`` in ``$env:Snippets``")
}

Import-Module $modulePath -Force -Verbose:$false
$result = Import-SnippetsAliases -VerboseSwitch:$Verbose

$alias = Set-Alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [aliases] Manage Snippets aliases' -Name als -Value Invoke-AliasManager -PassThru
Write-Verbose "[$script] Set-Alias $alias" -Verbose:$Verbose

return $result
