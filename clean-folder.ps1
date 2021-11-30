param([switch]$Verbose = $false)

try {
  function Clean-Folder {
    param(
      [String[]]$P = @('obj', 'bin'),
      [switch]$R = $false,
      [switch]$F = $false,
      [switch]$V = $false
    )
    if ($V) {
      Write-Host "`$P: $P"
      Write-Host "`$R: $R"
      Write-Host "`$F: $F"
      Write-Host "`$V: $V"
    }

    #gci bin,obj -r

    Get-ChildItem $P -Recurse:$R -Verbose:$V `
    | Remove-Item -Recurse:$R -Force:$F -Verbose:$V

  }
}
catch {
  Write-Host $Error    
}
finally {
  Write-Verbose 'Leaving clean-folder.ps1' -Verbose:$Verbose
}
