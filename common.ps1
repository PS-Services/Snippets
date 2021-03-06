param([switch]$VerboseSwitch = $false)

function Set-SnippetsLocation {
    Set-Location "$env:Snippets"
}

function Initialize-Snippets {
    param([switch]$VerboseSwitch = $false)

    #$Verbose=$true -or $VerboseSwitch
    $Verbose=$VerboseSwitch
    # Write-Verbose "[$script] [$env:SnippetsInitialized] -not `$env:SnippetsInitialized: $(-not $env:SnippetsInitialized)" -Verbose:$Verbose
    $script = $MyInvocation.MyCommand

    $alias = set-alias -Verbose:$Verbose -Scope Global -Description "Snippets: [snippets] Go to Snippets folder [$env:Snippets]" -Name snipps -Value Set-SnippetsLocation

    Push-Location
    try {
        if($env:SnippetsInitialized) { 
            Write-Verbose "[$script] Snippets already initialized." -Verbose:$Verbose
            return $env:SnippetsInitialized 
        }
        else {
            $fileInfo = New-Object System.IO.FileInfo (Get-Item $PSScriptRoot).FullName
            $path = $fileInfo.Directory.FullName;

            if($path.EndsWith("PowerShell", [System.StringComparison]::OrdinalIgnoreCase)){
                $path = join-path $path -ChildPath Snippets
            }

            set-location $path

            Write-Verbose "[$script] Initializing Snippets in $path" -Verbose:$Verbose
            $versionFilePath = Join-Path (Get-Location) -Child ".version" -Verbose:$Verbose

            if(-not (Test-Path $versionFilePath)){
                if(Test-Path $PWD/set-version.ps1 -Verbose:$Verbose) {
                    . $PWD/set-version.ps1 -Verbose:$Verbose 
                    $versionFile = Get-Item $PWD/.version -ErrorAction Stop
                }
            }

            $versionFile = Get-Item $versionFilePath -ErrorAction SilentlyContinue -Verbose:$Verbose
            Write-Verbose "[$script] $versionFilePath == [${versionFile.FullName}]: $($versionFilePath -eq $versionFile.FullName)" -Verbose:$Verbose

            $env:SnippetsVersion = get-content -Path $versionFilePath -Verbose:$Verbose -ErrorAction Stop
            Write-Verbose "[$script] `$env:SnippetsVersion: [$($env:SnippetsVersion)]" -Verbose:$Verbose

            $env:IsDesktop = "$($PSVersionTable.PSEdition -ieq 'desktop')"
            Write-Verbose "[$script] `$env:IsDesktop: [$($env:IsDesktop)]" -Verbose:$Verbose

            switch ($env:IsDesktop) {
                ("true") { $env:IsWindows="True"; $env:IsUnix="False"; }
                default { $env:IsWindows="$IsWindows"; $env:IsUnix="$IsLinux";}
            }

            Write-Verbose "[$script] Snippets Version: $env:SnippetsVersion" -Verbose:$Verbose
            Write-Verbose "[$script] `$env:IsDesktop: $env:IsDesktop" -Verbose:$Verbose
            Write-Verbose "[$script] `$env:IsWindows: $env:IsWindows" -Verbose:$Verbose
            Write-Verbose "[$script] `$env:IsUnix: $env:IsUnix" -Verbose:$Verbose

            $env:SnippetsInitialized="$true"

            if($env:IsUnix -eq "$true") { return "Powershell ready for Unix-like System."}
            elseif($env:IsDesktop -eq "$true") { return "Windows Powershell is ready."}
            else { return "Powershell Core is ready." }
        }
    }
    finally {
        Write-Verbose "[$script] [$env:Snippetscode Initialized] -not `$env:SnippetsInitialized: $(-not $env:SnippetsInitialized)" -Verbose:$Verbose

        Pop-Location -Verbose:$Verbose
        $Verbose = $VerboseSwitch
    }
}
