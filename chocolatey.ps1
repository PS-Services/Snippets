param([switch]$Verbose = $false)
if ($IsWindows) {
    try {
        $env:ChocolateyInstall = "$env:USERPROFILE\.choco"

        $ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
        if (Test-Path($ChocolateyProfile)) {
            Import-Module "$ChocolateyProfile"
        }
    }
    catch {
        Write-Host $Error    
    }
    finally {
        Write-Verbose 'Leaving chocolatey.ps1' -Verbose:$Verbose
    }
}