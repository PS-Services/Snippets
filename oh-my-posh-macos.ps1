param([switch]$VerboseSwitch = $false)

if ($IsMacOS) {
    # $Verbose=$true -or $VerboseSwitch
    $Verbose = $VerboseSwitch
    # Write-Verbose "[$script] [$env:SnippetsInitialized] -not `$env:SnippetsInitialized: $(-not $env:SnippetsInitialized)" -Verbose:$Verbose
    $script = $MyInvocation.MyCommand

    if (-not $env:SnippetsInitialized) {
        $fileInfo = New-Object System.IO.FileInfo (Get-Item $PSScriptRoot).FullName
        $path = $fileInfo.Directory.FullName;
        . $path/Snippets/_common.ps1;
        Initialize-Snippets -Verbose:$Verbose
    }

    Write-Verbose "[$script] `$env:IsUnix: [${env:IsUnix}]" -Verbose:$Verbose

    function Setup-OMP {
        param([switch]$Verbose = $false)

        if ($env:IsUnix -ieq 'true') {
            try {
                $poshbin = "/opt/homebrew/bin/oh-my-posh"
                $ohMyPosh = Get-Command $poshbin -ErrorAction SilentlyContinue
                $poshThemes = "~/.config/powershell/Snippets"

                if (-not $ohMyPosh) {
                    brew install oh-my-posh
                    $ohMyPosh = Get-Command $poshbin -ErrorAction SilentlyContinue

                    if ($ohMyPosh) {
                        Write-Verbose "[$script] Installed OH-MY-POSH to [$ohMyPosh]." -Verbose:$Verbose
                    }
                }

                if (-not $ohMyPosh) {
                    Write-Verbose "[$script] Cannot find Oh-My-Posh and cannot install manually." -Verbose:$Verbose
                    return "Could not locate or install OH-MY-POSH"
                }
                else {
                    if (Test-Path $poshThemes) {
                        $env:ohMyPosh = $ohMyPosh.Source

                        $log = (oh-my-posh --init --shell pwsh --config "$poshThemes/ninja.omp.json" | Invoke-Expression)
                        if (-not $log -or $log.Length -eq 0) { $log = "Exit Code: $LASTEXITCODE" }
                        return "OH-MY-POSH startup: [$log]"
                    }
                    else {
                        return "Could not locate or install OH-MY-POSH"
                    }
                }

                return "OH-MY-POSH was not started. (Should never get here!)"
            }
            catch {
                Write-Host $Error
            }
            finally {
                Write-Verbose "[$script] Leaving..." -Verbose:$Verbose
                $Verbose = $VerboseSwitch
            }
        }
        else {
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

    if ($env:IsUnix -ieq 'true') {
        $setupResult = Setup-OMP -Verbose:$Verbose
        Write-Verbose -Verbose:$Verbose -Message "[$script] Setup-OMP: [$setupResult]"
        Write-Verbose -Verbose:$Verbose -Message "[$script] `$env:ohMyPosh `$args: [$env:ohMyPosh $args]"

        $alias = set-alias -Verbose:$Verbose -Scope Global -Description "Snippets: [ps] OH-MY-POSH" -Name posh -Value Execute-OMP -PassThru

        return "Registered alias for OH-MY-POSH"
    }
    else {
        return "Wrong Operating System."
    }
}