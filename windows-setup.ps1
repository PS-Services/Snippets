#requires -Version 5.1
<#
.SYNOPSIS
Installs Snippets for the current user's Windows PowerShell 5.1 and PowerShell 7 sessions.
.EXAMPLE
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows-setup.ps1
.EXAMPLE
.\windows-setup.ps1 -Destination C:\Tools\Snippets -WhatIf
.EXAMPLE
Invoke-RestMethod https://raw.githubusercontent.com/PS-Services/Snippets/master/windows-setup.ps1 | Invoke-Expression
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$Destination,
    [string]$ProfilePath,
    [switch]$EnableScripts,
    [ValidateNotNullOrEmpty()]
    [string]$RepositoryUrl = 'https://github.com/PS-Services/Snippets.git'
)

# Older profiles dot-source every root-level .ps1 file during startup.
if ($MyInvocation.InvocationName -eq '.') { return }

# Invoke-Expression does not create a script cmdlet context. Use an advanced
# script block so ShouldProcess works for both downloaded text and -File.
& {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([string]$Destination, [string]$ProfilePath, [string]$RepositoryUrl, [switch]$EnableScripts)

$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') {
    throw 'This installer requires Windows. Use linux-setup.sh on Linux.'
}

# Process-scoped Bypass used to launch setup does not apply to future sessions.
$startupPolicy = 'Restricted'
$startupPolicyScope = 'Default'
foreach ($policyScope in @('MachinePolicy', 'UserPolicy', 'CurrentUser', 'LocalMachine')) {
    $policyValue = Get-ExecutionPolicy -Scope $policyScope
    if ($policyValue -ne 'Undefined') {
        $startupPolicy = [string]$policyValue
        $startupPolicyScope = $policyScope
        break
    }
}
if ($startupPolicy -in @('Restricted', 'AllSigned')) {
    if ($startupPolicyScope -in @('MachinePolicy', 'UserPolicy')) {
        throw "The $startupPolicyScope execution policy is $startupPolicy and blocks this unsigned profile. Contact your administrator about allowing or signing it."
    }
    if (-not $EnableScripts) {
        throw "The startup execution policy is $startupPolicy. Run 'Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned' and retry, or run setup with -EnableScripts."
    }
    if ($PSCmdlet.ShouldProcess('CurrentUser execution policy', 'Set RemoteSigned to allow local profiles and scripts')) {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
    }
}

$documents = [Environment]::GetFolderPath('MyDocuments')
if (-not $Destination) {
    if ($PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot '.git'))) {
        $Destination = $PSScriptRoot
    } else {
        $Destination = Join-Path $documents 'PowerShell\Snippets'
    }
}
if (-not $ProfilePath) {
    $profilePaths = @(
        (Join-Path $documents 'WindowsPowerShell\profile.ps1')
        (Join-Path $documents 'PowerShell\profile.ps1')
    )
} else {
    $profilePaths = @($ProfilePath)
}
$Destination = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination)

$startMarker = '# SNIPPETS BEGIN'
$endMarker = '# SNIPPETS END'
$profiles = @(foreach ($targetProfile in $profilePaths) {
$ProfilePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($targetProfile)
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
    [pscustomobject]@{
        Path = $ProfilePath
        Lines = $profileLines
        Starts = $starts
        Ends = $ends
    }
})

$cloneNeeded = -not (Test-Path -LiteralPath $Destination)
if (-not $cloneNeeded -and -not (Test-Path -LiteralPath $Destination -PathType Container)) {
    throw "Destination is not a directory: $Destination"
}
if ($cloneNeeded -and -not (Get-Command git -CommandType Application -ErrorAction SilentlyContinue)) {
    throw 'Git is required to clone Snippets. Install Git for Windows, then rerun setup.'
}
if (-not $PSCmdlet.ShouldProcess("$Destination; $($profiles.Path -join '; ')", 'Set up Snippets and back up any changed profile')) {
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
foreach ($targetProfile in $profiles) {
$ProfilePath = $targetProfile.Path
$profileLines = $targetProfile.Lines
$starts = $targetProfile.Starts
$ends = $targetProfile.Ends
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
    continue
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
Write-Output "Snippets installed at '$Destination'. Profile: '$ProfilePath'. Open a new PowerShell session to load it."
}
} -Destination $Destination -ProfilePath $ProfilePath -RepositoryUrl $RepositoryUrl -EnableScripts:$EnableScripts
