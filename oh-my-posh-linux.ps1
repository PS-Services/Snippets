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

Write-Verbose "[$script] `$env:IsUnix: [${env:IsUnix}]" -Verbose:$Verbose

function Setup-OMP {
    param([switch]$Verbose = $false)

    if ($env:IsUnix -ieq 'true') {
        try {
            $poshbin = "/usr/local/bin/oh-my-posh"
            $ohMyPosh = Get-Command $poshbin -ErrorAction SilentlyContinue
            $poshThemes = "$env:HOME/.poshthemes"

            if (-not $ohMyPosh) {
                $log = @(sudo wget https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-amd64 -O /usr/local/bin/oh-my-posh)
                $log += sudo chmod +x /usr/local/bin/oh-my-posh
                Write-Verbose "[$script] OH-MY-POSH Install Log:`n---`n$($log.Join("`n"))`n---" -Verbose:$Verbose
                $ohMyPosh = Get-Command $poshbin -ErrorAction SilentlyContinue

                if($ohMyPosh) {
                    Write-Verbose "[$script] Installed OH-MY-POSH to [$ohMyPosh]." -Verbose:$Verbose
                }
            } 

            if (-not $ohMyPosh) {
                Write-Verbose "[$script] Cannot find Oh-My-Posh and cannot install manually." -Verbose:$Verbose
                return "Could not locate or install OH-MY-POSH"
            }
            else {
                if (-not (Test-Path $poshThemes)) {
                    $log = @(mkdir $poshThemes)
                    $log += wget https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/themes.zip -O ~/.poshthemes/themes.zip
                    $log += unzip $poshThemes/themes.zip -d ~/.poshthemes
                    $log += chmod u+rw $poshThemes/*.json
                    $log += Remove-Item $poshThemes/themes.zip
                    Write-Verbose "[$script] OH-MY-POSH Themes Install Log:`n---`n$($log.Join("`n"))`n---" -Verbose:$Verbose

                    if (Test-Path $poshThemes) {
                        Write-Verbose "[$script] Installed OH-MY-POSH themes to [$poshThemes]." -Verbose:$Verbose
                    } else {
                        Write-Verbose "[$script] Cannot find OH-MY-POSH themes and cannot install manually." -Verbose:$Verbose
                    }
                } 

                if (Test-Path $poshThemes) {
                    $env:ohMyPosh=$ohMyPosh.Source
                    Write-Verbose "[$script] `$env:ohMyPosh: [$env:ohMyPosh]" -Verbose:$Verbose
                    Write-Verbose "[$script] `$poshThemes: [$poshThemes]" -Verbose:$Verbose

                    $log = (oh-my-posh --init --shell pwsh --config "$poshThemes/ys.omp.json" | Invoke-Expression)
                    if(-not $log -or $log.Length -eq 0) { $log = "Exit Code: $LASTEXITCODE" }
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
    } else {
        $Verbose = $VerboseSwitch
        return "Wrong Operating System."
    }
}

function Execute-OMP {
    Write-Verbose -Verbose:$Verbose -Message "[Execute-OMP] Setup-OMP: [$(Setup-OMP -Verbose:$Verbose)]"
    Write-Verbose -Verbose:$Verbose -Message "[Execute-OMP] `$env:ohMyPosh `$args: [$env:ohMyPosh $args]"

    $scriptBlock = { & (Get-Item $env:ohMyPosh) $args }
    $result = Invoke-Command -Verbose:$Verbose -ScriptBlock $scriptBlock -ArgumentList $args

    Write-Verbose -Verbose -Message "[Execute-OMP] `$result: [$result]"

    return $result
}

if ($env:IsUnix -ieq 'true') {
    $alias = set-alias -Verbose:$Verbose -Scope Global -Description "Snippets: [ps] OH-MY-POSH" -Name posh -Value Execute-OMP -PassThru

    return "Registered alias for OH-MY-POSH"
} else {
    return "Wrong Operating System."
}