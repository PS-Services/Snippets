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

  return "Execute ``Clean-Folder -r -f`` to remove ``bin`` and ``obj`` folders recursively."
}
catch {
  Write-Host $Error    
}
finally {
  Write-Verbose '[clean-folder.ps1] Leaving...' -Verbose:$Verbose
  $Verbose = $VerboseSwitch
}
