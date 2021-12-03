param([switch]$Verbose = $false)
if ($env:IsWindows -or $IsWindows) {
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
        Write-Verbose "& $winGet $Command $Name -s $Store $i;"
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
        Write-Verbose ". $scoop $c $Name;"
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
        Write-Verbose "sudo $choco $c $Name -y -PassThru;"
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

    Set-Alias -Name wg -Value Call-Winget -PassThru
    Set-Alias -Name scp -Value Call-Scoop -PassThru
    Set-Alias -Name ch -Value Call-Choco -PassThru
    Set-Alias -Name repos -Value Call-All -PassThru
  }
  catch {
    Write-Host $Error    
  }
  finally {
    Write-Verbose 'Leaving repos.ps1' -Verbose:$Verbose
  }
}