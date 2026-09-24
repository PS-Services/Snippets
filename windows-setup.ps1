#requires -Version 5.1
<#
.SYNOPSIS
Installs Snippets for the current user's Windows PowerShell 5.1 sessions.
.EXAMPLE
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows-setup.ps1
.EXAMPLE
.\windows-setup.ps1 -Destination C:\Tools\Snippets -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$Destination,
    [string]$ProfilePath,
    [ValidateNotNullOrEmpty()]
    [string]$RepositoryUrl = 'https://github.com/PS-Services/Snippets.git'
)

# Older profiles dot-source every root-level .ps1 file during startup.
if ($MyInvocation.InvocationName -eq '.') { return }

$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') {
    throw 'This installer requires Windows. Use linux-setup.sh on Linux.'
}

$documents = [Environment]::GetFolderPath('MyDocuments')
if (-not $Destination) {
    if (Test-Path -LiteralPath (Join-Path $PSScriptRoot '.git')) {
        $Destination = $PSScriptRoot
    } else {
        $Destination = Join-Path $documents 'PowerShell\Snippets'
    }
}
if (-not $ProfilePath) {
    # Target Windows PowerShell even when this installer is launched with pwsh.
    $ProfilePath = Join-Path $documents 'WindowsPowerShell\profile.ps1'
}
$Destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination)
$ProfilePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ProfilePath)

$startMarker = '# SNIPPETS BEGIN'
$endMarker = '# SNIPPETS END'
$profileLines = @()
if (Test-Path -LiteralPath $ProfilePath) {
    $profileLines = @(Get-Content -LiteralPath $ProfilePath)
}
$starts = @()
$ends = @()
for ($index = 0; $index -lt $profileLines.Count; $index++) {
    if ($profileLines[$index] -eq $startMarker) { $starts += $index }
    if ($profileLines[$index] -eq $endMarker) { $ends += $index }
}
if ($starts.Count -ne $ends.Count -or $starts.Count -gt 1 -or
    ($starts.Count -eq 1 -and $starts[0] -ge $ends[0])) {
    throw "Invalid or duplicate Snippets markers in '$ProfilePath'. No changes made."
}

$cloneNeeded = -not (Test-Path -LiteralPath $Destination)
if (-not $cloneNeeded -and -not (Test-Path -LiteralPath $Destination -PathType Container)) {
    throw "Destination is not a directory: $Destination"
}
if ($cloneNeeded -and -not (Get-Command git -CommandType Application -ErrorAction SilentlyContinue)) {
    throw 'Git is required to clone Snippets. Install Git for Windows, then rerun setup.'
}
if (-not $PSCmdlet.ShouldProcess("$Destination; $ProfilePath", 'Set up Snippets and back up any changed profile')) {
    return
}

if ($cloneNeeded) {
    $parentDirectory = Split-Path -Path $Destination -Parent
    if (-not (Test-Path -LiteralPath $parentDirectory)) {
        New-Item -ItemType Directory -Path $parentDirectory -Force | Out-Null
    }
    & git clone -- $RepositoryUrl $Destination
    if ($LASTEXITCODE -ne 0) {
        throw "git clone failed with exit code $LASTEXITCODE. Profile was not changed."
    }
}

$templatePath = Join-Path $Destination 'Windows-ReadmeTest.ps9'
if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
    $templatePath = Join-Path $Destination 'Windows-ReadmeTest.ps1'
}
if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
    throw "Missing Windows-ReadmeTest.ps9 or Windows-ReadmeTest.ps1 in '$Destination'. Profile was not changed."
}
$template = @(Get-Content -LiteralPath $templatePath)
$escapedDestination = $Destination.Replace("'", "''")
$block = @($startMarker, "`$env:Snippets = '$escapedDestination'") + $template + @($endMarker)
$newLines = New-Object 'System.Collections.Generic.List[string]'
if ($starts.Count -eq 1) {
    for ($index = 0; $index -lt $starts[0]; $index++) { $newLines.Add($profileLines[$index]) }
    $newLines.AddRange([string[]]$block)
    for ($index = $ends[0] + 1; $index -lt $profileLines.Count; $index++) { $newLines.Add($profileLines[$index]) }
} else {
    $newLines.AddRange([string[]]$profileLines)
    $newLines.AddRange([string[]]$block)
}

if (($profileLines -join "`n") -ceq ($newLines -join "`n")) {
    Write-Output "Snippets is already configured in '$ProfilePath'."
    return
}
$profileDirectory = Split-Path -Path $ProfilePath -Parent
if (-not (Test-Path -LiteralPath $profileDirectory)) {
    New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null
}
if (Test-Path -LiteralPath $ProfilePath) {
    $backupPath = "$ProfilePath.$([guid]::NewGuid().ToString('N')).bak"
    Copy-Item -LiteralPath $ProfilePath -Destination $backupPath
    Write-Output "Profile backup: $backupPath"
}
$newLines | Set-Content -LiteralPath $ProfilePath -Encoding UTF8
Write-Output "Snippets installed at '$Destination'. Profile: '$ProfilePath'. Open a new Windows PowerShell session to load it."
