using namespace System

param([switch]$VerboseSwitch = $false)

# $Verbose=$true -or $VerboseSwitch
$Verbose=$VerboseSwitch
# Write-Verbose "[$script] [$env:SnippetsInitialized] -not `$env:SnippetsInitialized: $(-not $env:SnippetsInitialized)" -Verbose:$Verbose
$script = $MyInvocation.MyCommand

if (-not $env:SnippetsInitialized) {
    $fileInfo = New-Object System.IO.FileInfo (Get-Item $PSScriptRoot).FullName
    $path = $fileInfo.Directory.FullName;
    . $path/Snippets/_common.ps1;
    Initialize-Snippets -Verbose:$Verbose
}

if (-not $env:Snippets) {
    if ($env:IsWindows -ieq 'true') {
        if($env:OneDrive){
            $env:Snippets = "$env:OneDrive\Documents\PowerShell\Snippets"
        } else {
            $env:Snippets = "$env:UserProfile\Documents\PowerShell\Snippets"
        }
    }
    else {
        $env:Snippets = "$env:HOME/.config/powershell/Snippets"
    }
}

Write-Verbose "[$script] Set `$env:Snippets to [$env:Snippets]" -Verbose:$Verbose

function Update-Profile {
    param([switch]$Verbose = $false)

    Push-Location -ErrorAction Stop
    try{
        if (Test-Path -LiteralPath $env:Snippets -PathType Container) {
            Set-Location -LiteralPath $env:Snippets -ErrorAction Stop

            . ./set-version.ps1 -Verbose:$Verbose

            $startLine='# SNIPPETS BEGIN'
            $endLine='# SNIPPETS END'

            if($env:IsWindows -ieq "true") {
                $readmeFile = "${env:Snippets}/Windows-ReadmeTest.ps9"
                if (-not (Test-Path -LiteralPath $readmeFile -PathType Leaf)) {
                    $readmeFile = "${env:Snippets}/Windows-ReadmeTest.ps1"
                }
            }
            else { $readmeFile = "${env:Snippets}/Linux-ReadmeTest.ps9" }

            Write-Verbose -Verbose:$Verbose -Message "[$script] Source File: [$readmeFile] Exists: $(Test-Path $readmeFile)"

            $readme = @(Get-Content -LiteralPath $readmeFile -ErrorAction Stop)
            $escapedSnippetsPath = $env:Snippets.Replace("'", "''")
            $readme = @("`$env:Snippets = '$escapedSnippetsPath'") + $readme

            $myProfile = @()
            if (Test-Path -LiteralPath $PROFILE) {
                $myProfile = @(Get-Content -LiteralPath $PROFILE -ErrorAction Stop)
            }
            $array=New-Object System.Collections.ArrayList
            $array.AddRange($myProfile)

            $matchStart=$array.IndexOf($startLine)
            $matchEnd=$array.IndexOf($endLine)

            if ($matchStart -ge 0 -and $matchEnd -gt $matchStart -and
                @($array | Where-Object { $_ -eq $startLine }).Count -eq 1 -and
                @($array | Where-Object { $_ -eq $endLine }).Count -eq 1) {
                $array.RemoveRange($matchStart + 1, $matchEnd - $matchStart - 1)
                $array.InsertRange($matchStart + 1, $readme)
            } elseif ($matchStart -eq -1 -and $matchEnd -eq -1) {
                # Append to End
                [void]$array.Add($startLine)
                $array.AddRange($readme)
                [void]$array.Add($endLine)
            } else {
                throw "Invalid or duplicate Snippets markers in '$PROFILE'. Profile was not changed."
            }

            $now=[System.DateTime]::Now.ToShortDateString()
            [void]$array.Add("# Snippets History: $now - ${env:SnippetsVersion}")

            $profileDirectory = Split-Path -Path $PROFILE -Parent
            if ($profileDirectory -and -not (Test-Path -LiteralPath $profileDirectory)) {
                New-Item -ItemType Directory -Path $profileDirectory -Force -ErrorAction Stop | Out-Null
            }
            $array | Out-File -LiteralPath $PROFILE -Encoding UTF8 -Verbose:$Verbose -ErrorAction Stop

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

    Push-Location -ErrorAction Stop
    try{
        if (Test-Path -LiteralPath $env:Snippets -PathType Container) {
            Set-Location -LiteralPath $env:Snippets -ErrorAction Stop
            & git pull
            if ($LASTEXITCODE -ne 0) {
                throw "git pull failed with: $LASTEXITCODE"
            }

            $exitCode = $LASTEXITCODE

            if($exitCode -eq 0) {
                Update-Profile -Verbose:$Verbose
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
