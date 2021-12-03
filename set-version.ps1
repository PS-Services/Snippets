using namespace System

param([switch]$Verbose = $false)
Push-Location
if((Get-Location).Path.EndsWith("PowerShell")) { Set-Location Snippets }

$gitversion = Get-Command dotnet-gitversion -Verbose:$Verbose -ErrorAction SilentlyContinue

if(-not $gitversion) {
    & dotnet tool install gitversion.tool -g
}

$gitversion = Get-Command dotnet-gitversion -Verbose:$Verbose -ErrorAction SilentlyContinue

if(-not $gitversion) {
    throw "Cannot find or install dotnet-gitversion."
}

$version = & $gitversion /showvariable FullSemVer

$version | Out-File -FilePath '.version' -Encoding utf8NoBOM -force

Write-Verbose "Current Semver is $version" -Verbose:$Verbose
Pop-Location