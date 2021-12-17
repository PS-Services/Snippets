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
    try {
        function Start-DevMode {
            $developerPowerShell = [io.path]::GetFullPath($env:AllUsersProfile) + '\Start Menu\Programs\Visual Studio 2022\Visual Studio Tools\Developer PowerShell for VS 2022 Preview.lnk'
            $objShell = New-Object -com 'Wscript.Shell'

            $objshortcut = $objShell.CreateShortcut($developerPowerShell)

            $arguments = $objshortcut.Arguments

            $slug = 'Enter-VsDevShell'
            $env:vsDevModeCode = $arguments.Substring($arguments.indexOf($slug) + $slug.Length + 1).Split('}')[0]

            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($objShell) | Out-Null
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($objshortcut) | Out-Null

            try {
                Push-Location
                Import-Module 'C:\Program Files\Microsoft Visual Studio\2022\Preview\Common7\Tools\Microsoft.VisualStudio.DevShell.dll'; 
                Enter-VsDevShell $env:vsDevModeCode -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64'
            }
            finally {
                Pop-Location
            }
        }

        Set-Alias -Description 'Snippets: Start VS2022 Developer Mode' -Name devmode -Value Start-DevMode

        return "Type ``devmode`` to enter VS2022 Developer Mode."
    }
    catch {
        Write-Host $Error    
    }
    finally {
        Write-Verbose '[devmode.ps1] Leaving...' -Verbose:$Verbose
        $Verbose = $VerboseSwitch
    }
} else {
    $Verbose = $VerboseSwitch
    return "Visual Studio 2022 not available on this system."
}
