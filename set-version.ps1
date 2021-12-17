using namespace System

param([switch]$VerboseSwitch = $false)

# $Verbose=$true -or $VerboseSwitch
$Verbose=$VerboseSwitch
# Write-Verbose "[$script] [$env:SnippetsInitialized] -not `$env:SnippetsInitialized: $(-not $env:SnippetsInitialized)" -Verbose:$Verbose
$script = $MyInvocation.MyCommand

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
    $path = Get-Location
    
    $versionFilePath = Join-Path (Get-Location) -Child ".version"

    if(-not (Test-Path $versionFilePath)) {
        Write-Verbose "[$script] Writing $version to $versionFilePath" -Verbose:$Verbose

        echo $version > $versionFilePath
        $result = (& git add $versionFilePath)
        $result
        $result = (& git commit -m "Added version")
        $result
    }

    if(Test-Path $versionFilePath) {
        Write-Verbose "[$script] `$versionFilePath ($versionFilePath) exists: $(Test-Path $versionFilePath)"  -Verbose:$Verbose

        $verifiedVersion = Get-Content -Path $versionFilePath -Verbose:$Verbose

        Write-Verbose "[$script] `$verifiedVersion: $verifiedVersion" -Verbose:$Verbose

        Write-Verbose "[$script] Current Semver is $verifiedVersion" -Verbose:$Verbose
    }

    $env:SnippetsVersion=$verifiedVersion

    return "Current Semver is ${env:SnippetsVersion}"
}
catch {
    "Handled: $_"
}
finally {
    Pop-Location
    $Verbose = $VerboseSwitch
}
