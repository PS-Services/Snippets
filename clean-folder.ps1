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

function Clean-Folder {
  param(
    [String[]]$P = @('obj', 'bin'),
    [switch]$R = $false,
    [switch]$F = $false,
    [switch]$V = $false
  )
  Write-Verbose -Verbose:$V -Message "`$P: $P"
  Write-Verbose -Verbose:$V -Message "`$R: $R"
  Write-Verbose -Verbose:$V -Message "`$F: $F"
  Write-Verbose -Verbose:$V -Message "`$V: $V"

  #gci bin,obj -r

  $items = Get-ChildItem $P -Recurse:$R -Verbose:$V -ErrorAction SilentlyContinue

  if($items) {
    Write-Verbose -Verbose:$V -Message "Removing ${items.length} items"
    $items | Remove-Item -Recurse:$R -Force:$F -Verbose:$V -ErrorAction Stop
  } else {
    $itemsString=[System.String]::Join(',', $P)
    Write-Verbose -Verbose:$V -Message "No items that match [$itemsString] were found to delete."
  }
}

try {
  $alias = set-alias -Verbose:$Verbose -Scope Global -Description "Snippets: [dev] Clean-Folder" -Name clean -Value Clean-Folder -PassThru

  return "Execute ``Clean-Folder -r -f`` to remove ``bin`` and ``obj`` folders recursively."
}
catch {
  Write-Host $Error    
}
finally {
  Write-Verbose "[$script] Leaving..." -Verbose:$Verbose
  $Verbose = $VerboseSwitch
}
