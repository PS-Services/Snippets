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

if ($env:IsWindows -ieq 'true') {
  try {
    function Call-Winget {
      [CmdletBinding(PositionalBinding = $false)]
      param(
        [string]$Command = 'search',
        [string]$Name = $null,
        [string]$Store = 'winget',
        [switch]$Install = $false,
        [switch]$Interactive = $false
      )

      if ($Install) {
        $Command = 'install' 
      }

      $winGet = Get-Command winget.exe

      if ($winGet) {
        $i = if ($Interactive) {
          '-i' 
        }
        else {
          ''
        }
        Write-Verbose "[$script] & $winGet $Command $Name -s $Store $i;"
        & $winGet $Command $Name -s $Store $i;
        & refreshenv
      }
    }

    function Call-Scoop {
      [CmdletBinding(PositionalBinding = $false)]
      param(
        [string]$Command = 'list',
        [string]$SubCommand = $null,
        [string]$Name = $null
      )

      if (-not $Name -and $SubCommand) {
        $Name = $SubCommand;
        $SubCommand = $null;
      }

      $scoop = Get-Command scoop

      if ($scoop) {
        $SubCommand = if ($SubCommand) {
          $SubCommand 
        }
        else {
          ''
        }
        $c = "$Command $SubCommand".Trim()
        Write-Verbose "[$script] . $scoop $c $Name;"
        . $scoop $c $Name;
        & refreshenv
      }
    }

    function Call-Choco {
      [CmdletBinding(PositionalBinding = $false)]
      param(
        [string]$Command = 'list',
        [string]$SubCommand = $null,
        [string]$Name = $null
      )

      if (-not $Name -and $SubCommand) {
        $Name = $SubCommand;
        $SubCommand = $null;
      }

      $choco = Get-Command choco

      if ($choco) {
        $SubCommand = if ($SubCommand) {
          $SubCommand 
        }
        else {
          ''
        }
        $c = "$Command $SubCommand".Trim()
        Write-Verbose "[$script] sudo $choco $c $Name -y -PassThru;"
        sudo $choco $c $Name -y -PassThru;
        & refreshenv
      }
    }

    function Call-All {
      [CmdletBinding(PositionalBinding = $true)]
      param(
        [string]$Command = 'search',
        [string]$SubCommand = $null,
        [string]$Name = $null,
        [string]$Store = 'winget',
        [switch]$Interactive = $false
      )

      if (-not $Name) { 
        if ($SubCommand) {
          $Name = $SubCommand;
          $SubCommand = $null;
        }
        elseif ($Command) {
          $Name = $Command;
          $Command = 'search';
        }
      }

      $results = @()
      $results += Call-Winget -Command $Command -Name $Name -Store $Store -Interactive:$Interactive
      $results += @('End winget', '')
      $results += Call-Scoop -Command $Command -Subcommand $Subcommand -Name $Name
      $results += @('End scoop', '')
      $results += Call-Choco -Command $Command -Subcommand $Subcommand -Name $Name
      $results += @('End chocolatey', '')
  
      return $results
    }

    set-alias -Description "Snippets: WinGet" -Name wg -Value Call-Winget -PassThru
    set-alias -Description "Snippets: Scoop" -Name scp -Value Call-Scoop -PassThru
    set-alias -Description "Snippets: Chocolatey" -Name ch -Value Call-Choco -PassThru
    set-alias -Description "Snippets: All Repos" -Name repos -Value Call-All -PassThru

    return "Repos aliases configured."
  }
  catch {
    Write-Host $Error    
  }
  finally {
    Write-Verbose '[repos.ps1] Leaving...' -Verbose:$Verbose
    $Verbose = $VerboseSwitch
  }
} else {
  $Verbose = $VerboseSwitch
  return "Wrong Operating System."
}
