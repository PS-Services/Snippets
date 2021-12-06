using namespace System

param([switch]$Verbose = $false)
Push-Location
Push-Location
try {
    if ((Get-Location).Path.EndsWith('PowerShell')) {
        Set-Location Snippets
    }

    $gitversion = Get-Command dotnet-gitversion -Verbose:$Verbose -ErrorAction SilentlyContinue

    if (-not $gitversion) {
        & dotnet tool install gitversion.tool -g
    }

    $gitversion = Get-Command dotnet-gitversion -Verbose:$Verbose -ErrorAction SilentlyContinue

    if (-not $gitversion) {
        throw 'Cannot find or install dotnet-gitversion.'
    }

    $version = & $gitversion /showvariable FullSemVer

    $version | Out-File -FilePath '.version' -Encoding utf8 -Force

    Write-Verbose "Current Semver is $version" -Verbose:$Verbose
}
catch {
    write-error $_
}
finally {
    Pop-Location
}