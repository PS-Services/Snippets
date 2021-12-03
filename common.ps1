param([switch]$Verbose = $false)

function Initialize-Snippets {
    param([switch]$Verbose = $false)

    $fileInfo = New-Object System.IO.FileInfo (Get-Item $PSScriptRoot).FullName
    $path = $fileInfo.Directory.FullName;

    if($path.EndsWith("PowerShell")){
        $path = join-path $path -ChildPath Snippets
    }

    Push-Location
    set-location $path

    $env:SnippetsVersion = get-content .version

    $env:IsDektop = "$($PSVersionTable.PSEdition -ieq 'desktop')"

    switch ($env:IsDektop) {
        ("true") { $env:IsWindows="True"; $env:IsUnix="False"; }
        default { $env:IsWindows="$IsWindows"; $env:IsUnix="$IsLinux";}
    }

    $env:SnippetsInitialized = $true;

    "Snippets Version: $env:SnippetsVersion"
    Write-Verbose "`$env:IsDektop: $env:IsDektop" -Verbose:$Verbose
    Write-Verbose "`$env:IsWindows: $env:IsWindows" -Verbose:$Verbose
    Write-Verbose "`$env:IsUnix: $env:IsUnix" -Verbose:$Verbose

    Pop-Location
}
