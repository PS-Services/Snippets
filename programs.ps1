param([switch]$VerboseSwitch = $false)

# Loading the snippet only registers commands; installation is always explicit.
Import-Module (Join-Path $PSScriptRoot 'SnippetsPrograms.psm1') -ErrorAction Stop -Verbose:$false
Set-Alias -Name apps -Value Invoke-SnippetsPrograms -Scope Global -Description 'Snippets: [programs] List or install programs from YAML'
return 'Run apps list for program/update status, or apps to install missing programs.'
