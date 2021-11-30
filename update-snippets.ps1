if ($IsWindows) {
    $env:Snippets = "$env:OneDrive\Documents\PowerShell\Snippets"
}
else {
    $env:Snippets = '/opt/microsoft/powershell/7/Snippets'
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
