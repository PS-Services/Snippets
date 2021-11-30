param([switch]$Verbose=$false)

try {
    if($PSVersionTable.PSEdition -ieq "core") {
        $powershell = "pwsh"
    } else {
        $powershell = "pwsh" # Temporary, cannot execute with powershell.exe
    }

    if(-not (get-command oh-my-posh)) {
        . scoop install oh-my-posh3
    }
    oh-my-posh --init --shell $powershell --config $env:scoop\apps\oh-my-posh3\current\themes\ys.omp.json `
    | Invoke-Expression
}
catch {
    Write-Host $Error    
}
finally {
    Write-Verbose 'Leaving oh-my-posh.ps1' -Verbose:$Verbose
}
