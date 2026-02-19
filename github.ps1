param([switch]$VerboseSwitch = $false)

#$Verbose=$true -or $VerboseSwitch
$Verbose=$VerboseSwitch
# Write-Verbose "[$script] [$env:SnippetsInitialized] -not `$env:SnippetsInitialized: $(-not $env:SnippetsInitialized)" -Verbose:$Verbose
$script = $MyInvocation.MyCommand

if (-not $env:SnippetsInitialized) {
	$fileInfo = New-Object System.IO.FileInfo (Get-Item $PSScriptRoot).FullName
	$path = $fileInfo.Directory.FullName;
	. $path/Snippets/_common.ps1;
	Initialize-Snippets -Verbose:$Verbose
}

try {
	if (-not $env:GITHUB) {
		# Search common locations instead of the entire drive
		$searchPaths = @()
		if($env:IsWindows -ieq 'true') {
			$searchPaths += $env:USERPROFILE
			if ($env:OneDrive) { $searchPaths += $env:OneDrive }
		} else {
			$searchPaths += $env:HOME
		}

		foreach ($hintPath in $searchPaths) {
			Write-Verbose "[$script] searching for 'github' in [$hintPath]" -Verbose:$Verbose
			$found = Get-ChildItem -Filter github -Path $hintPath -Depth 1 -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
			if ($found) {
				$env:GITHUB = $found.FullName
				break
			}
		}

		if (-not $env:GITHUB) {
			Write-Verbose "[$script] Could not find 'github' folder. Set `$env:GITHUB manually." -Verbose:$Verbose
		}
	}

	$description="Snippets: [dev] Go to GitHub folder [$env:GITHUB]"

	Write-Verbose "[$script] `$env:GITHUB set to [$env:GITHUB]" -Verbose:$Verbose

	function Set-LocationGitHub {
		param(
			[string]$Repository = '',
			[switch]$V = $false
		)

		Write-Verbose "[$script] `$env:GITHUB:  [$($env:GITHUB)]" -Verbose:$V
		Write-Verbose "[$script] `$Repository:  [$Repository]" -Verbose:$V
		Set-Location (Join-Path $env:GITHUB -Child $Repository) -Verbose:$V
	}

	$alias = set-alias -Verbose:$Verbose -Scope Global -Description $description -Name hub -Value Set-LocationGitHub

	return "Use ``hub`` to go to the GitHub folder."
}
catch {
	Write-Host $Error
}
finally {
	Write-Verbose '[github.ps1] Leaving...' -Verbose:$Verbose
	$Verbose = $VerboseSwitch
}
