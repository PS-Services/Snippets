using namespace System

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
    $env:Snippets = "$env:OneDrive\Documents\PowerShell\Snippets"
}
else {
    $env:Snippets = "$env:HOME/.config/powershell/Snippets"
}

Write-Verbose "[$script] Set `$env:Snippets to [$env:Snippets]" -Verbose:$Verbose

function Update-Profile {
    param([switch]$Verbose = $false)

    try{
        if (Test-Path $env:Snippets) {
            Push-Location
            Set-Location $env:Snippets
            Get-Item .version -ErrorAction SilentlyContinue -Verbose:$Verbose `
                | Remove-Item -Verbose:$Verbose -ErrorAction Stop

            . ./set-version.ps1 -Verbose:$Verbose

            $startLine='# SNIPPETS BEGIN'
            $endLine='# SNIPPETS END'

            if($env:IsWindows -ieq "true") { $readmeFile = "${env:Snippets}/Windows-ReadmeTest.ps9" }
            else { $readmeFile = "${env:Snippets}/Linux-ReadmeTest.ps9" }

            Write-Verbose -Verbose:$Verbose -Message "[$script] Source File: [$readmeFile] Exists: $(Test-Path $readmeFile)"

            $readme = Get-Content $readmeFile

            $myProfile=get-content $PROFILE
            $array=New-Object System.Collections.ArrayList
            $array.AddRange($myProfile)

            $matchStart=$array.IndexOf($startLine) + 1
            $matchEnd=$array.IndexOf($endLine) - 1

            if($matchStart -lt $matchEnd  -and $matchStart -gt 0) {
                $range = ($matchEnd..$matchStart)

                foreach($index in $range){
                    $array.RemoveAt($index)
                }

                $array.InsertRange($matchStart, $readme)
            } else {
                # Append to End
                $array.Add($startLine)
                $array.AddRange($readme)
                $array.Add($endLine)
            }

            $now=[System.DateTime]::Now.ToShortDateString()
            $array.Add("# Snippets History: $now - ${env:SnippetsVersion}")

            $array | Out-File $PROFILE -Encoding UTF8 -Verbose:$Verbose

            return "Updated $PROFILE to version ${env:SnippetsVersion}"
        }
        else {
            throw "Cannot locate `$env:Snippets: [$env:Snippets]"
        }
    }
    finally {
        Pop-Location
    }
}

$alias = set-alias -Verbose:$Verbose -Scope Global -Description "Snippets: [snippets] Update Profile from GitHub." -Name profileup -Value Update-Profile
Write-Verbose -Verbose:$Verbose -Message "[$script] Set-Alias $alias"

function Update-Snippets {
    param([switch]$Verbose = $false)

    try{
        if (Test-Path $env:Snippets) {
            Push-Location
            Set-Location $env:Snippets
            & git pull

            $exitCode = $LASTEXITCODE

            if($exitCode -eq 0) {
                Get-Item .version -ErrorAction SilentlyContinue -Verbose:$Verbose `
                    | Remove-Item -Verbose:$Verbose -ErrorAction Stop

                . ./set-version.ps1 -Verbose:$Verbose

                Update-Profile
            }
        }
        else {
            throw "Cannot find snippets folder at $env:Snippets"
        }
    }
    finally {
        Pop-Location
    }
}

$alias = set-alias -Verbose:$Verbose -Scope Global -Description "Snippets: [snippets] Update Snippets from GitHub." -Name snipup -Value Update-Snippets
Write-Verbose -Verbose:$Verbose -Message "Set-Alias $alias"

$Verbose = $VerboseSwitch

return "Call ``snipup`` or ``Update-Snippets`` to update from GitHub."
