if (-not $env:SnippetsInitialized) { 
    $fileInfo = New-Object System.IO.FileInfo (Get-Item $PSScriptRoot).FullName
    $path = $fileInfo.Directory.FullName;
    . $path/Snippets/common.ps1; 
    Initialize-Snippets -Verbose:$Verbose 
}

if ($env:IsWindows -ieq 'true') {
    $env:Snippets = "$env:OneDrive\Documents\PowerShell\Snippets"
}
else {
    $env:Snippets = "$env:HOME/.config/powershell"
}

function Update-Snippets {
    if (Test-Path $env:Snippets) {
        Push-Location
        Set-Location $env:Snippets
        & git pull
        Pop-Location
    }
    else {
        throw "Cannot find snippets folder at $env:Snippets"
    }
}

Set-Alias -Name snipup -Value Update-Snippets
