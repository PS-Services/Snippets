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
                oh-my-posh --init --shell $powershell --config $ompFolder\ys.omp.json `
                | Invoke-Expression
                return "OH-MY-POSH is ready."
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
        Write-Verbose '[oh-my-posh.ps1] Leaving...' -Verbose:$Verbose
        $Verbose = $VerboseSwitch
    }
} else {
    $Verbose = $VerboseSwitch
    return "Wrong Operating System."
}
