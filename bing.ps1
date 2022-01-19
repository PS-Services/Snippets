param([switch]$VerboseSwitch = $false)

# $Verbose=$true -or $VerboseSwitch
$Verbose=$VerboseSwitch
# Write-Verbose "[$script] [$env:SnippetsInitialized] -not `$env:SnippetsInitialized: $(-not $env:SnippetsInitialized)" -Verbose:$Verbose
$script = $MyInvocation.MyCommand

if(-not $env:SnippetsInitialized) { 
  $fileInfo = New-Object System.IO.FileInfo (Get-Item $PSScriptRoot).FullName
  $path = $fileInfo.Directory.FullName;
  . $path/Snippets/common.ps1; 
  Initialize-Snippets -Verbose:$Verbose 
}

try {
  $dnScript = Get-Command dotnet-script -ErrorAction SilentlyContinue
  if (-not $dnScript) {
    & dotnet tool install dotnet-script -g
    $dnScript = Get-Command dotnet-script -ErrorAction SilentlyContinue
  }
  if (-not $dnScript) {
    Write-Host "Cannot install dotnet-script"
  }
  else {
    $env:dnscriptPath = $dnScript.Source
    if($env:Dotnet) {
      $env:dnscriptPath = $env:dnscriptPath.Replace("$env:USERPROFILE\.dotnet", $env:Dotnet).Replace("$env:USERPROFILE/.dotnet", $env:Dotnet)
    }
    
    $env:BingLocation = $env:Snippets
    if (-not $env:BingLocation.EndsWith("Snippets")) { $env:BingLocation = Join-Path $env:BingLocation -Child "Snippets" }
    Write-Verbose "[$script] `$env:BingLocation: $env:BingLocation" -Verbose:$Verbose
    $ApiKey = '3c7e251544ba414cbeacad9db55bdf6e'

    $env:BingApiKey = $ApiKey  
    function Search-Bing {
      $query = [System.String]::Join(' ', $args);
      $csxPath = Join-Path $env:BingLocation -Child 'bing.csx' ;
      Write-Verbose "[$script] & $env:dnscriptPath $csxPath `"$query`" --max=3" -Verbose:$Verbose
      & $env:dnscriptPath $csxPath "$query" --max=3 --no-cache
    }

    $alias = set-alias -Verbose:$Verbose -Scope Global -Description "Snippets: [search] Search Bing" -Name bing -Value Search-Bing -PassThru

    return "Search Bing by typing ``bing SEARCH``"
  }
}
catch {
  Write-Host $Error    
}
finally {
  Write-Verbose '[bing.ps1] Leaving...' -Verbose:$Verbose
  $Verbose = $VerboseSwitch
}
