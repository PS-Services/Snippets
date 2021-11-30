param([switch]$Verbose = $false)
if ($IsLinux) {
    try {
        $ohMyPosh = Get-Command /usr/local/bin/oh-my-posh
        $poshThemes = "$env:USERPROFILE/.poshthemes"

        if (-not $ohMyPosh) {
            sudo wget https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-amd64 -O /usr/local/bin/oh-my-posh
            sudo chmod +x /usr/local/bin/oh-my-posh
            
            mkdir $poshThemes
            wget https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/themes.zip -O ~/.poshthemes/themes.zip
            unzip $poshThemes/themes.zip -d ~/.poshthemes
            chmod u+rw $poshThemes/*.json
            Remove-Item $poshThemes/themes.zip

            $ohMyPosh = Get-Command /usr/local/bin/oh-my-posh
        }

        if (-not $ohMyPosh) {
            Write-Host 'Cannot find Oh-My-Posh and cannot install manually.'
        }
        else {
            Write-Verbose "`$ohMyPosh: $($ohMyPosh.Source)" -Verbose:$Verbose

            Write-Verbose "`$poshThemes: $($poshThemes)" -Verbose:$Verbose

            if (Test-Path $poshThemes) {
                oh-my-posh --init --shell pwsh --config $poshThemes/ys.omp.json `
                | Invoke-Expression
            }
            else {
                Write-Host "Could not locate $poshThemes"
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