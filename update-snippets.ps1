using namespace System

param([switch]$VerboseSwitch = $false)

# $Verbose=$true -or $VerboseSwitch
$Verbose=$VerboseSwitch
# Write-Verbose "[$script] [$env:SnippetsInitialized] -not `$env:SnippetsInitialized: $(-not $env:SnippetsInitialized)" -Verbose:$Verbose
$script = $MyInvocation.MyCommand

if (-not $env:SnippetsInitialized) { 
    $fileInfo = New-Object System.IO.FileInfo (Get-Item $PSScriptRoot).FullName
    $path = $fileInfo.Directory.FullName;
    . $path/Snippets/common.ps1; 
    Initialize-Snippets -Verbose:$Verbose 
}

if ($env:IsWindows -ieq 'true') {
    $env:Snippets = "$env:OneDrive\Documents\PowerShell\Snippets"
}
else {
    $env:Snippets = "$env:HOME/.config/powershell/Snippets"
}

Write-Verbose "[$script] Set `$env:Snippets to [$env:Snippets]" -Verbose:$Verbose

function Update-Snippets {
    if (Test-Path $env:Snippets) {
        Push-Location
        Set-Location $env:Snippets
        & git pull
        Pop-Location
    }
    else {
        throw "Cannot find snippets folder at $env:Snippets"
    }
}

set-alias -Description "Snippets: Update Snippets from GitHub." -Verbose:$Verbose -Name snipup -Value Update-Snippets

$Verbose = $VerboseSwitch

return "Call ``snipup`` or ``Update-Snippets`` to update from GitHub."
