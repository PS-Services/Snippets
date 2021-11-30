param([switch]$Verbose=$false)

try {
    oh-my-posh --init --shell pwsh --config C:\Users\kingd\OneDrive\Documents\PowerShell\ys.omp.json `
    | Invoke-Expression
}
catch {
    Write-Host $Error    
}
finally {
    Write-Verbose 'Leaving oh-my-posh.ps1' -Verbose:$Verbose
}
