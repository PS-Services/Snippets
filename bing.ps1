param([switch]$Verbose = $false)

try {
  $ApiKey = '3c7e251544ba414cbeacad9db55bdf6e'

  $env:BingApiKey = $ApiKey

  function Search-Bing {
    $query = [System.String]::Join(' ', $args);
    Write-Verbose "& dotnet-script c:\Users\kingd\bing.csx `"$query`" --max=3" -Verbose:$Verbose
    & dotnet-script c:\Users\kingd\bing.csx "$query" --max=3
  }

  Set-Alias -Name bing -Value Search-Bing -PassThru
}
catch {
  Write-Host $Error    
}
finally {
  Write-Verbose 'Leaving bing.ps1' -Verbose:$Verbose
}
