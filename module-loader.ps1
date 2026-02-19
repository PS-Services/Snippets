param([switch]$VerboseSwitch = $false)

# $Verbose=$true -or $VerboseSwitch
$Verbose=$VerboseSwitch
$script = $MyInvocation.MyCommand

<#
    .SYNOPSIS
    Loads PowerShell modules defined in a YAML configuration file.

    .DESCRIPTION
    Reads modules.yml (or the path in $env:SnippetsModulesYaml), installs any
    missing modules from PSGallery, and imports them into the current session.
    Requires the powershell-yaml module for YAML parsing (auto-installed if missing).
#>

function Install-YamlModuleIfMissing {
    param([switch]$Verbose = $false)

    $yamlMod = Get-Module -ListAvailable -Name 'powershell-yaml' -ErrorAction SilentlyContinue
    if (-not $yamlMod) {
        Write-Verbose "[$script] Installing powershell-yaml from PSGallery..." -Verbose:$Verbose
        Install-Module -Name 'powershell-yaml' -Scope CurrentUser -Force -AllowClobber -AcceptLicense -ErrorAction Stop
    }
    Import-Module 'powershell-yaml' -ErrorAction Stop -Verbose:$false
}

function Import-SnippetsModules {
    param([switch]$Verbose = $false)

    # Determine YAML config path
    $yamlPath = $env:SnippetsModulesYaml
    if (-not $yamlPath -or -not (Test-Path $yamlPath)) {
        $yamlPath = Join-Path $env:Snippets -ChildPath 'modules.yml'
    }

    if (-not (Test-Path $yamlPath)) {
        Write-Verbose "[$script] No modules.yml found at [$yamlPath]. Skipping module auto-load." -Verbose:$Verbose
        return "No modules.yml found."
    }

    Write-Verbose "[$script] Loading module definitions from [$yamlPath]" -Verbose:$Verbose

    # Ensure powershell-yaml is available
    Install-YamlModuleIfMissing -Verbose:$Verbose

    # Parse YAML
    $yamlContent = Get-Content -Path $yamlPath -Raw -ErrorAction Stop
    $config = ConvertFrom-Yaml $yamlContent -ErrorAction Stop

    if (-not $config -or -not $config.modules) {
        Write-Verbose "[$script] modules.yml is empty or has no 'modules' key." -Verbose:$Verbose
        return "No modules defined."
    }

    $loaded = 0
    $failed = 0

    foreach ($entry in $config.modules) {
        $moduleName = $entry.name
        $moduleVersion = $entry.version
        $moduleSource = if ($entry.source) { $entry.source } else { 'PSGallery' }
        $moduleRequired = if ($null -ne $entry.required) { $entry.required } else { $true }
        $moduleParams = $entry.parameters

        if (-not $moduleName) {
            Write-Verbose "[$script] Skipping entry with no 'name' field." -Verbose:$Verbose
            continue
        }

        # Skip powershell-yaml since we already loaded it above
        if ($moduleName -ieq 'powershell-yaml') {
            $loaded++
            continue
        }

        try {
            Write-Verbose "[$script] Processing module [$moduleName]..." -Verbose:$Verbose

            # Check if already imported
            $existing = Get-Module -Name $moduleName -ErrorAction SilentlyContinue
            if ($existing) {
                if (-not $moduleVersion -or $existing.Version -ge [Version]$moduleVersion) {
                    Write-Verbose "[$script] Module [$moduleName] already imported." -Verbose:$Verbose
                    $loaded++
                    continue
                }
            }

            # Check if installed locally
            $installed = Get-Module -ListAvailable -Name $moduleName -ErrorAction SilentlyContinue

            $needsInstall = $false
            if (-not $installed) {
                $needsInstall = $true
            }
            elseif ($moduleVersion) {
                $bestVersion = ($installed | Sort-Object Version -Descending | Select-Object -First 1).Version
                if ($bestVersion -lt [Version]$moduleVersion) {
                    $needsInstall = $true
                }
            }

            # Install if needed
            if ($needsInstall) {
                if ($moduleSource -ine 'PSGallery' -and (Test-Path $moduleSource)) {
                    Write-Verbose "[$script] Importing [$moduleName] from path [$moduleSource]" -Verbose:$Verbose
                }
                else {
                    Write-Verbose "[$script] Installing [$moduleName] from PSGallery..." -Verbose:$Verbose
                    $installParams = @{
                        Name            = $moduleName
                        Scope           = 'CurrentUser'
                        Force           = $true
                        AllowClobber    = $true
                        AcceptLicense   = $true
                        ErrorAction     = 'Stop'
                    }

                    if ($moduleVersion) {
                        $installParams['MinimumVersion'] = $moduleVersion
                    }

                    Install-Module @installParams
                }
            }

            # Import the module
            $importParams = @{
                Name        = if ($moduleSource -ine 'PSGallery' -and (Test-Path $moduleSource)) { $moduleSource } else { $moduleName }
                ErrorAction = 'Stop'
                Verbose     = $false
            }

            if ($moduleVersion -and $moduleSource -ieq 'PSGallery') {
                $importParams['MinimumVersion'] = $moduleVersion
            }

            if ($moduleParams) {
                $importParams['ArgumentList'] = $moduleParams
            }

            Import-Module @importParams
            Write-Verbose "[$script] Loaded [$moduleName] successfully." -Verbose:$Verbose
            $loaded++
        }
        catch {
            $failed++
            if ($moduleRequired) {
                Write-Error "[$script] Failed to load required module [$moduleName]: $_"
            }
            else {
                Write-Verbose "[$script] Optional module [$moduleName] failed to load: $_" -Verbose:$Verbose
            }
        }
    }

    return "Module auto-load complete: $loaded loaded, $failed failed."
}

try {
    $result = Import-SnippetsModules -Verbose:$Verbose
    Write-Verbose "[$script] $result" -Verbose:$Verbose
    return $result
}
catch {
    Write-Error "[$script] Module auto-loader error: $_"
}
finally {
    Write-Verbose "[$script] Leaving..." -Verbose:$Verbose
    $Verbose = $VerboseSwitch
}
