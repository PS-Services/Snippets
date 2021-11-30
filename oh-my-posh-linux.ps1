param([switch]$Verbose = $false)
if ($IsLinux) {
    try {
        $ohMyPosh = Get-Command /usr/local/bin/oh-my-posh

        if (-not $ohMyPosh) {
            sudo wget https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-amd64 -O /usr/local/bin/oh-my-posh
            sudo chmod +x /usr/local/bin/oh-my-posh

            mkdir ~/.poshthemes
            wget https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/themes.zip -O ~/.poshthemes/themes.zip
            unzip ~/.poshthemes/themes.zip -d ~/.poshthemes
            chmod u+rw ~/.poshthemes/*.json
            Remove-Item ~/.poshthemes/themes.zip

            $ohMyPosh = Get-Command /usr/local/bin/oh-my-posh
        }

        if (-not $ohMyPosh) {
            Write-Host 'Cannot find Oh-My-Posh and cannot install manually.'
        }
        else {
            Write-Verbose "`$ohMyPosh: $($ohMyPosh.Source)" -Verbose:$Verbose

            $themes = '~/.poshthemes'

            Write-Verbose "`$themes: $($themes)" -Verbose:$Verbose

            if (Test-Path $themes) {
                oh-my-posh --init --shell pwsh --config $themes/ys.omp.json `
                | Invoke-Expression
            }
            else {
                Write-Host "Could not locate $themes"
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