param([switch]$VerboseSwitch = $false)

# $Verbose=$true -or $VerboseSwitch
$Verbose = $VerboseSwitch
# Write-Verbose "[$script] [$env:SnippetsInitialized] -not `$env:SnippetsInitialized: $(-not $env:SnippetsInitialized)" -Verbose:$Verbose
$script = $MyInvocation.MyCommand

# C:\Users\kingd\OneDrive\Documents\PowerShell\Snippets\PackageManagers.ps1
$packageManagers = Get-ChildItem SnippetsManager.psm1 -Path $env:Snippets

if (-not $packageManagers)
{
  throw [ErrorRecord]::new("Cannot locate ``SnippetsManager.psm1`` in ``$env:Snippets``");
}

Import-Module $packageManagers.FullName -Verbose

Write-Verbose "Executing [$script]" -Verbose:$Verbose
