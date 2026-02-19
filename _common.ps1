param([switch]$VerboseSwitch = $false)

Write-Verbose "[_common.ps1] Entered common" -Verbose:$VerboseSwitch

switch ($env:IsDesktop)
{
    ('true')
    {
        $env:IsWindows = 'True'; $env:IsUnix = 'False'
    }
    default
    {
        $env:IsWindows = "$IsWindows"; $env:IsUnix = "$($IsLinux -or $IsMacOS)"
    }
}

Write-Verbose "`$env:IsWindows: $($env:IsWindows)" -Verbose:$VerboseSwitch

$utilities = Get-Module Microsoft.PowerShell.Utility -ErrorAction SilentlyContinue

if(-not $utilities){
    Install-Module Microsoft.PowerShell.Utility -AllowClobber -Scope CurrentUser -AcceptLicense -Force
}

Import-Module Microsoft.PowerShell.Utility


function Set-SnippetsLocation {
    Set-Location "$env:Snippets"
}

function Initialize-Snippets {
    param([switch]$VerboseSwitch = $false)

    #$Verbose=$true -or $VerboseSwitch
    $Verbose=$VerboseSwitch
    # Write-Verbose "[$script] [$env:SnippetsInitialized] -not `$env:SnippetsInitialized: $(-not $env:SnippetsInitialized)" -Verbose:$VerboseSwitch
    $script = $MyInvocation.MyCommand

    Write-Verbose $MyInvocation -Verbose:$VerboseSwitch

    $alias = set-alias -Verbose:$VerboseSwitch -Scope Global -Description "Snippets: [snippets] Go to Snippets folder [$env:Snippets]" -Name snipps -Value Set-SnippetsLocation

    Push-Location
    try {
        if($env:SnippetsInitialized) {
            Write-Verbose "[$script] Snippets already initialized."  -Verbose:$VerboseSwitch
            return $env:SnippetsInitialized
        }
        else {
            $fileInfo = New-Object System.IO.FileInfo (Get-Item $PSScriptRoot).FullName
            $path = $fileInfo.Directory.FullName;

            if($path.EndsWith("PowerShell", [System.StringComparison]::OrdinalIgnoreCase)){
                $path = join-path $path -ChildPath Snippets
            }

            set-location $path

            Write-Verbose "[$script] Initializing Snippets in $path"  -Verbose:$VerboseSwitch
            $versionFilePath = Join-Path (Get-Location) -Child ".version"  -Verbose:$VerboseSwitch

            if(-not (Test-Path $versionFilePath)){
                if(Test-Path $PWD/set-version.ps1 -Verbose:$VerboseSwitch) {
                    . $PWD/set-version.ps1 -Verbose:$VerboseSwitch
                    $versionFile = Get-Item $PWD/.version -ErrorAction Stop
                }
            }

            $versionFile = Get-Item $versionFilePath -ErrorAction SilentlyContinue -Verbose:$VerboseSwitch
            Write-Verbose "[$script] $versionFilePath == [${versionFile.FullName}]: $($versionFilePath -eq $versionFile.FullName)" -Verbose:$VerboseSwitch

            $env:SnippetsVersion = get-content -Path $versionFilePath -Verbose:$VerboseSwitch -ErrorAction Stop
            Write-Verbose "[$script] `$env:SnippetsVersion: [$($env:SnippetsVersion)]" -Verbose:$VerboseSwitch

            $env:IsDesktop = "$($PSVersionTable.PSEdition -ieq 'desktop')"
            Write-Verbose "[$script] `$env:IsDesktop: [$($env:IsDesktop)]" -Verbose:$VerboseSwitch

            Write-Verbose "[$script] Snippets Version: $env:SnippetsVersion" -Verbose:$VerboseSwitch
            Write-Verbose "[$script] `$env:IsDesktop: $env:IsDesktop" -Verbose:$VerboseSwitch
            Write-Verbose "[$script] `$env:IsWindows: $env:IsWindows" -Verbose:$VerboseSwitch
            Write-Verbose "[$script] `$env:IsUnix: $env:IsUnix" -Verbose:$VerboseSwitch

            $env:SnippetsInitialized="$true"

            # Auto-load modules from modules.yml
            $moduleLoaderPath = Join-Path $path -ChildPath 'module-loader.ps1'
            if (Test-Path $moduleLoaderPath) {
                Write-Verbose "[$script] Running module auto-loader..." -Verbose:$Verbose
                . $moduleLoaderPath -VerboseSwitch:$Verbose
            }

            if($env:IsUnix -eq "$true") { return "Powershell ready for Unix-like System."}
            elseif($env:IsDesktop -eq "$true") { return "Windows Powershell is ready."}
            else { return "Powershell Core is ready." }
        }
    }
    finally {
        Write-Verbose "[$script] [$env:SnippetsInitialized] -not `$env:SnippetsInitialized: $(-not $env:SnippetsInitialized)" -Verbose:$VerboseSwitch

        Pop-Location -Verbose:$VerboseSwitch
        $Verbose = $VerboseSwitch
    }
}
