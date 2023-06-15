param([switch]$VerboseSwitch = $false)

# $Verbose=$true -or $VerboseSwitch
$Verbose = $VerboseSwitch
# Write-Verbose "[$script] [$env:SnippetsInitialized] -not `$env:SnippetsInitialized: $(-not $env:SnippetsInitialized)" -Verbose:$Verbose
$script = $MyInvocation.MyCommand

if (-not $env:SnippetsInitialized) { 
    $fileInfo = New-Object System.IO.FileInfo (Get-Item $PSScriptRoot).FullName
    $path = $fileInfo.Directory.FullName;
    . $path/Snippets/common.ps1; 
    Initialize-Snippets -Verbose:$Verbose 
}

if ($env:IsWindows -ieq 'true') {
    try {
        $vswhere = Get-Command vswhere -ErrorAction SilentlyContinue

        if (-not($vswhere)) {
            $winget = get-command winget -ErrorAction SilentlyContinue

            if (-not($winget)) {
                throw "winget is not installed";
            }        

            & $winget install Microsoft.VisualStudio.Locator

            $vswhere = Get-Command vswhere -ErrorAction SilentlyContinue

            if (-not($vswhere)) {
                throw "Could not install vswhere";
            }        
        }

        function Start-DevMode {
            try {
                $location = & $vswhere -format value -property "installationPath" -nologo

                Push-Location
                Set-Location "$location\Common7\Tools"
                . .\Launch-VsDevShell.ps1 -Arch arm64 -HostArch amd64 -VsWherePath (Get-Command vswhere).source
            }
            finally {
                Pop-Location
            }
        }

        set-alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [dev] Start VS2022 Developer Mode' -Name devmode -Value Start-DevMode

        return "Type ``devmode`` to enter VS2022 Developer Mode."
    }
    catch {
        Write-Host $Error
    }
    finally {
        Write-Verbose "[$script] Leaving..." -Verbose:$Verbose
        $Verbose = $VerboseSwitch
    }
}
else {
    $Verbose = $VerboseSwitch
    return "Visual Studio 2022 not available on this system."
}
