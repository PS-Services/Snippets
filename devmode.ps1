param([switch]$Verbose = $false)
if ($env:IsWindows) {
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

            Import-Module 'C:\Program Files\Microsoft Visual Studio\2022\Preview\Common7\Tools\Microsoft.VisualStudio.DevShell.dll'; 
            Enter-VsDevShell $env:vsDevModeCode -SkipAutomaticLocation -DevCmdArguments '-arch=x64 -host_arch=x64'
        }

        Set-Alias -Name devmode -Value Start-DevMode
    }
    catch {
        Write-Host $Error    
    }
    finally {
        Write-Verbose 'Leaving devmode.ps1' -Verbose:$Verbose
    }
}