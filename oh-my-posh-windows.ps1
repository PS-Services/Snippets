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

function Setup-OMP {
    param([switch]$Verbose = $false)

    if ($env:IsWindows -ieq 'true') {
        try {
            $ohMyPosh = Get-Command oh-my-posh -ErrorAction Stop
            if ($ohMyPosh) {
                Write-Verbose "[$script] `$ohMyPosh: $($ohMyPosh.Source)" -Verbose:$Verbose

                $env:ohMyPosh=$ohMyPosh.Source

                Write-Verbose -Verbose:$Verbose -Message "(oh-my-posh init pwsh --config `"$PSScriptRoot\ninja.omp.json`" | Invoke-Expression)"

                $initScript = & $ohMyPosh init pwsh --config "$PSScriptRoot\ninja.omp.json"
                if ($LASTEXITCODE -ne 0) { throw "Oh My Posh initialization failed with exit code $LASTEXITCODE." }
                $log = ($initScript -join "`n") | Invoke-Expression
                if(-not $log -or $log.Length -eq 0) { $log = "Exit Code: $LASTEXITCODE" }
                return "OH-MY-POSH startup: [$log]"
            }
        }
        catch {
            throw
        }
        finally {
            Write-Verbose "[$script] Leaving..." -Verbose:$Verbose
            $Verbose = $VerboseSwitch
        }
    } else {
        $Verbose = $VerboseSwitch
        return "Wrong Operating System."
    }
}

function Execute-OMP {
    $scriptBlock = { & (Get-Item $env:ohMyPosh) $args }
    $result = Invoke-Command -Verbose:$Verbose -ScriptBlock $scriptBlock -ArgumentList $args

    Write-Verbose -Verbose:$VerboseSwitch -Message "[Execute-OMP] `$result: [$result]"

    return $result
}

if ($env:IsWindows -ieq 'true') {
    if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
        $winget = Get-Command winget -ErrorAction SilentlyContinue
        if (-not $winget) {
            return 'Oh My Posh is missing and WinGet is unavailable. Install WinGet or run windows-setup.ps1.'
        }
        & $winget install --id JanDeDobbeleer.OhMyPosh --exact --source winget --scope user --accept-source-agreements --accept-package-agreements | Out-Host
        if ($LASTEXITCODE -ne 0) {
            throw "Oh My Posh installation failed with exit code $LASTEXITCODE."
        }
        foreach ($scope in @('Machine', 'User')) {
            foreach ($entry in ([Environment]::GetEnvironmentVariable('Path', $scope) -split ';')) {
                if ($entry -and $entry -notin ($env:Path -split ';')) { $env:Path += ";$entry" }
            }
        }
        if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
            throw 'Oh My Posh is still unavailable after WinGet installation. Restart your terminal to refresh PATH.'
        }
    }
    $setupResult = Setup-OMP -Verbose:$Verbose
    Write-Verbose -Verbose:$Verbose -Message "[$script] Setup-OMP: [$setupResult]"
    Write-Verbose -Verbose:$Verbose -Message "[$script] `$env:ohMyPosh `$args: [$env:ohMyPosh $args]"

    $alias = set-alias -Verbose:$Verbose -Scope Global -Description "Snippets: [ps] OH-MY-POSH" -Name posh -Value Execute-OMP -PassThru

    return "Registered alias for OH-MY-POSH"
} else {
    return "Wrong Operating System."
}
