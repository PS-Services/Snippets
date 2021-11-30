# Sharp Ninja's Powershell Snippets

* bing.ps1 - Search Bing from Powershell.
* chocolatey.ps1 - Setup Chocolatey profile in PowerShell.
* clean-folder.ps1 - Remove all `bin` and `obj` folders in current path.
* devmode.ps1 - Startup VS 2022 Dev Mode Tools.
* github.ps1 - set $env:GITHUB first to the root of your github repositories.  Then use `hub` or `hub <repository>` to go to those folders.
* oh-my-posh.ps1 - Initializes Oh-My-Posh for the current PowerShell Session.

Place calls to these file in your `$PROFILE`

All scripts work in both PowerShell Core and Windows PowerShell 5.1!

## Example `$PROFILE`

```powershell
if($env:VerboseStartup -eq "true") {
    [switch]$Verbose = $true
} else {
    [switch]$Verbose = $false
}

Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope Process

try {
    Import-Module Microsoft.PowerShell.Utility

    Push-Location
    Set-Location "$env:UserProfile\OneDrive\Documents\PowerShell\"
    $snippets = Get-ChildItem .\Snippets\*.ps1

    $snippets.FullName | ForEach-Object -process {
        $snippet = $_

        . $snippet -Verbose:$Verbose
    }
    Pop-Location

    Write-Verbose 'PowerShell Ready.' -Verbose:$Verbose
}
catch {
    Write-Host $Error    
}
finally {
    Write-Verbose "Leaving $Profile"  -Verbose:$Verbose
}
```