param([switch]$Verbose = $false)
if ($IsWindows) {
    try {
        if ($PSVersionTable.PSEdition -ieq 'core') {
            $powershell = 'pwsh'
        }
        else {
            $powershell = 'pwsh' # Temporary, cannot execute with powershell.exe
        }

        $ohMyPosh = Get-Command oh-my-posh

        if (-not $ohMyPosh) {
            . scoop install oh-my-posh3

            $ohMyPosh = Get-Command oh-my-posh
        }

        if (-not $ohMyPosh) {
            Write-Host 'Cannot find Oh-My-Posh and cannot install with scoop.'
        }
        else {
            Write-Verbose "`$ohMyPosh: $($ohMyPosh.Source)" -Verbose:$Verbose

            $ompFolder = [System.IO.Path]::GetDirectoryName($ohMyPosh.Source)

            if ($ompFolder.EndsWith('\shims')) {
                $ompFolder += '\..\apps\oh-my-posh3\current\themes\'
            } elseif ($ompFolder.EndsWith("AppData\Local\Programs\oh-my-posh\bin")) {
                $ompFolder += '\..\themes\'
            }

            Write-Verbose "`$ompFolder: $($ompFolder)" -Verbose:$Verbose

            if (Test-Path $ompFolder) {
                oh-my-posh --init --shell $powershell --config $ompFolder\ys.omp.json `
                | Invoke-Expression
            }
            else {
                Write-Host "Could not locate $ompFolder\..\themes"
            }
        }
    }
    catch {
        Write-Host $Error    
    }
    finally {
        Write-Verbose 'Leaving oh-my-posh.ps1' -Verbose:$Verbose
    }
}