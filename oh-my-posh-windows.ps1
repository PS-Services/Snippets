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

function Setup-OMP {
    param([switch]$Verbose = $false)

    if ($env:IsWindows -ieq 'true') {
        try {
            if ($PSVersionTable.PSEdition -ieq 'core') {
                $powershell = 'pwsh'
            }
            else {
                $powershell = 'powershell'
            }

            $ohMyPosh = Get-Command oh-my-posh

            if (-not $ohMyPosh) {
                . scoop install 'https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/oh-my-posh.json'

                $ohMyPosh = Get-Command oh-my-posh
            }

            if (-not $ohMyPosh) {
                Write-Host 'Cannot find Oh-My-Posh and cannot install with scoop.'
            }
            else {
                Write-Verbose "[$script] `$ohMyPosh: $($ohMyPosh.Source)" -Verbose:$Verbose

                $ompFolder = [System.IO.Path]::GetDirectoryName($ohMyPosh.Source)

                if ($ompFolder.EndsWith('\shims')) {
                    $ompFolder += '\..\apps\oh-my-posh3\current\themes\'
                } elseif ($ompFolder.EndsWith("scoop\apps\oh-my-posh\current\bin")) {
                    $ompFolder += '\..\themes\'
                } elseif ($ompFolder.EndsWith("AppData\Local\Programs\oh-my-posh\bin")) {
                    $ompFolder += '\..\themes\'
                }

                Write-Verbose "[$script] `$ompFolder: $($ompFolder)" -Verbose:$Verbose

                if (Test-Path $ompFolder) {
                    $env:ohMyPosh=$ohMyPosh.Source
                    Write-Verbose "[$script] `$env:ohMyPosh: [$env:ohMyPosh]" -Verbose:$Verbose
                    Write-Verbose "[$script] `$ompFolder: [$ompFolder]" -Verbose:$Verbose

                    $log = (oh-my-posh --init --shell $powershell --config $ompFolder\ys.omp.json | Invoke-Expression)
                    if(-not $log -or $log.Length -eq 0) { $log = "Exit Code: $LASTEXITCODE" }
                    return "OH-MY-POSH startup: [$log]"
                }
                else {
                    return "Could not locate $ompFolder\..\themes"
                }
            }
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

if ($env:IsWindows -ieq 'true') {
    $alias = set-alias -Verbose:$Verbose -Scope Global -Description "Snippets: [ps] OH-MY-POSH" -Name posh -Value Execute-OMP -PassThru

    return "Registered alias for OH-MY-POSH"
} else {
    return "Wrong Operating System."
}