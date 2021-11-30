param([switch]$Verbose = $false)

try {
  $dnScript = Get-Command dotnet-script
  if (-not $dnScript) {
    & dotnet tool install dotnet-script -g
    $dnScript = Get-Command dotnet-script
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
    Write-Verbose "`$env:BingLocation: $env:BingLocation" -Verbose:$Verbose
    $ApiKey = '3c7e251544ba414cbeacad9db55bdf6e'

    $env:BingApiKey = $ApiKey  
    function Search-Bing {
      $query = [System.String]::Join(' ', $args);
      $csxPath = Join-Path $env:BingLocation -Child 'bing.csx' ;
      Write-Verbose "& $env:dnscriptPath $csxPath `"$query`" --max=3" -Verbose:$Verbose
      & $env:dnscriptPath $csxPath "$query" --max=3
    }

    Set-Alias -Name bing -Value Search-Bing -PassThru
  }
}
catch {
  Write-Host $Error    
}
finally {
  Write-Verbose 'Leaving bing.ps1' -Verbose:$Verbose
}
