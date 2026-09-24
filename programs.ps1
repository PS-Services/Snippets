param([switch]$VerboseSwitch = $false)

# Loading the snippet only registers commands; installation is always explicit.
Import-Module (Join-Path $PSScriptRoot 'SnippetsPrograms.psm1') -ErrorAction Stop -Verbose:$false
Set-Alias -Name apps -Value Install-SnippetsPrograms -Scope Global -Description 'Snippets: [programs] Install missing programs from YAML'
return 'Run apps -CheckOnly to check programs.yml, or apps to install missing programs.'
