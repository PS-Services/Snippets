using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Linq
using namespace System.Text.RegularExpressions

param([switch]$VerboseSwitch = $false)

# $Verbose=$true -or $VerboseSwitch
$Verbose = $VerboseSwitch
# Write-Verbose "[$script] [$env:SnippetsInitialized] -not `$env:SnippetsInitialized: $(-not $env:SnippetsInitialized)" -Verbose:$Verbose
$script = $MyInvocation.MyCommand

Write-Verbose $MyInvocation

class ResultItem {
  [string]$Repo;
  [string]$Command;
  [string]$ID;
  [string]$Version;
  [string]$Name;

  ResultItem(
    [string]$r,
    [string]$i,
    [string]$v,
    [string]$n,
    [string]$ins
  ) {
    $this.Repo = $r;
    $this.ID = $i;
    $this.Version = $v;
    $this.Name = $n;
    $this.Command = $ins;
  }
}

if (-not $env:SnippetsInitialized) {
  $fileInfo = New-Object FileInfo (Get-Item $PSScriptRoot).FullName
  $path = $fileInfo.Directory.FullName;
  . $path/Snippets/common.ps1;
  Initialize-Snippets -Verbose:$Verbose
}

if ($env:IsWindows -eq 'true') {
  try {
    function Invoke-Winget {
      [CmdletBinding(PositionalBinding = $True)]
      param(
        [Parameter(Position = 0)][string]$Command = 'search',
        [Parameter(Position = 1)][string]$Name = $null,
        [string]$Store = 'winget',
        [switch]$Install = $false,
        [switch]$Interactive = $false,
        [switch]$AllRepos = $false
      )

      if ($Name -eq '' -and $Command) {
        if (-not($Command -imatch 'list|upgrade|update')) {
          $Name = $Command;
          $Command = 'search';
        }
        
        if($Command -ieq "upgrade"){
          $Name = "--all"
        }
    }

      if ($Install) {
        $Command = 'search'
      }

      $params = @()

      Switch -regex ($Command) {
        ('search|find') {
          $params += "search";
          $params += $Name;
        }

        ('install') {
          $params += "install";
          $params += $Name;
        }

        ('upgrade') {
          $params += "upgrade";
          $params += $Name;
        }

        ('uninstall|remove') {
          $params += "uninstall";
          $params += $Name;
        }

        ('show|details|info') {
          $params += "show";
          $params += $Name;
        }

        ('update|refresh') {
          $params += "update";
        }

        default {
          $params += $Command;
          $params += $Name;
        }
      }

      if ($Store) {
        $params += "-s";
        $params += $Store;
      }

      Write-Verbose "[$script] Parameters: [$params]" -Verbose:$Verbose

      $winGet = Get-Command winget.exe

      if ($winGet) {
        if ($Interactive) {
          $params += "-i"
        }

        # Write-Verbose "[$script] & $winGet $Command $Name -s $Store $i;"
        Write-Verbose "[$script] & $winGet $params" -Verbose:$Verbose
        $wingetResults = & $winGet $params
        & refreshenv

        $results = @('Begin winget', '')

        [Object[]]$wingetResults = $wingetResults.Split("`n");
        [List[ResultItem]]$wingetList = [List[ResultItem]]::new();
  
        $regex = [Regex]::new('^.+\s+([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)\s+([\d\.]+)\s?');
  
        foreach ($line in $wingetResults) {
          if ($regex.IsMatch($line)) {
            $id = $regex.Match($line).Groups[1].Value.Trim();
            $ver = $regex.Match($line).Groups[2].Value.Trim();
            $index = $line.IndexOf($id);
            $nme = $line.Substring(0, $index).Trim();
            switch -regex ($Command) {
              'search' { $inst = "install $id --version $ver --source $Store $($Interactive ? '-i' : '')".Trim() }
              'list' { $inst = "uninstall $id" }
            }
            
            $wingetList.Add([ResultItem]::new(
                "winget", $id, $ver, $nme, $inst
              ));
          }
        }
  
        $results += $wingetResults
        $results += @('End winget', '')

        if ($Command -imatch 'search|list' ) {
          $firstItem = @([Enumerable]::OfType[ResultItem]($wingetList))[0];

          if ($Install -and $firstItem) {
            $arguments = $firstItem.Command.Split(' ')
            & $firstItem.Repo $arguments
          }

          if ($AllRepos.IsPresent -and -not $AllRepos) {
            $wingetList | Format-Table -AutoSize  
          }
          elseif (-not $AllRepos.IsPresent) {
            $wingetList | Format-Table -AutoSize  
          }
          else {
            $wingetList
          }
        }
        else {
          $results
        }      
      }
    }

    function Invoke-Scoop {
      [CmdletBinding(PositionalBinding = $True)]
      param(        
        [Parameter(Position = 0)][string]$Command = 'search',        
        [Parameter(Position = 1)][string]$Name = $null,
        [string]$SubCommand = $null,
        [switch]$Install = $false,
        [switch]$AllRepos = $false
      )

      if ($Name -eq '' -and -not($Command -imatch 'list|upgrade')) {
        $Name = $Command;
        $Command = 'search';
      }

      if ($Install) {
        $Command = 'search'
      }

      [Object[]]$params = @()

      Switch -regex ($Command) {
        ('search|find') {
          $params += "search";
          if ($SubCommand) { $params += $SubCommand.Trim() }
          $params += $Name;
        }

        ('install') {
          $params += "install";
          if ($SubCommand) { $params += $SubCommand.Trim() }
          $params += $Name;
        }

        ('upgrade|update') {
          $params += "update";
          if ($SubCommand) { $params += $SubCommand.Trim() }
          $params += $Name;
        }

        ('uninstall|remove') {
          $params += "uninstall";
          if ($SubCommand) { $params += $SubCommand.Trim() }
          $params += $Name;
        }

        ('show|details|info') {
          $params += "info";
          if ($SubCommand) { $params += $SubCommand.Trim() }
          $params += $Name;
        }

        default {
          $params += $Command;
          if ($SubCommand) { $params += $SubCommand.Trim(); }
          if ($Name) { $params += $Name; }
        }
      }

      [Object[]] $params = @($params)

      Write-Verbose "[$script] Parameters: [$params]" -Verbose:$Verbose

      $scoop = Get-Command scoop

      if ($scoop) {
        Write-Verbose "[$script] Invoke-Expression `"& `"$($scoop.Source)`" $params`"" -Verbose:$Verbose
        $scoopResults = Invoke-Expression "& `"$($scoop.Source)`" $params"
        & refreshenv      
      
        $results = @('Begin scoop', '')

        [List[object]]$scoopList = [List[object]]::new();
  
        foreach ($line in $scoopResults) {
          $ver = $line.version;
          $nme = $line.name;
          switch -regex ($Command) {
            'search' { 
              if ($ver) {
                $inst = "install $($nme)@$($ver) $($line.Bucket ? "--bucket $($line.bucket)" : '')" 
              }
              else {
                $inst = "install $nme $($line.Bucket ? "--bucket $($line.bucket)" : '')" 
              }
            }
            'list' { $inst = "uninstall $nme" }
          }
          $scoopList.Add([ResultItem]::new(
              "scoop", $nme, $ver, $nme, $inst
            ));
        }
        
        $results += $scoopResults
        $results += @('End scoop', '')

        if ($Command -imatch 'search|list' ) {
          $firstItem = @([Enumerable]::OfType[ResultItem]($scoopList))[0];

          if ($Install -and $firstItem) {
            $arguments = $firstItem.Command.Split(' ')
            & $firstItem.Repo $arguments
          }
          
          if ($AllRepos.IsPresent -and -not $AllRepos) {
            $scoopList | Format-Table -AutoSize  
          }
          elseif (-not $AllRepos.IsPresent) {
            $scoopList | Format-Table -AutoSize  
          }
          else {
            $scoopList
          }        }
        else {
          $results
        }      
      }
    }

    function Invoke-Choco {
      [CmdletBinding(PositionalBinding = $True)]
      param(
        [Parameter(Position = 0)][string]$Command = 'list',
        [Parameter(Position = 1)][string]$Name = $null,
        [string]$SubCommand = $null,
        [switch]$Install = $false,
        [switch]$AllRepos = $false
      )

      if ($Name -eq '' -and -not($Command -imatch 'list|upgrade')) {
        $Name = $Command;
        $Command = 'search';
      }

      if ($Install) {
        $Command = 'search'
      }

      $params = @()

      Switch -regex ($Command) {
        ('search|find') {
          $params += "search";
          if ($SubCommand) { $params += $SubCommand.Trim() }
          $params += $Name;
        }

        ('install') {
          $params += "install";
          if ($SubCommand) { $params += $SubCommand.Trim() }
          $params += $Name;
        }

        ('upgrade|update') {
          $params += "upgrade";
          if ($SubCommand) { $params += $SubCommand.Trim() }
          $params += $Name;
        }

        ('uninstall|remove') {
          $params += "uninstall";
          if ($SubCommand) { $params += $SubCommand.Trim() }
          $params += $Name;
        }

        ('show|details|info') {
          $params += "info";
          if ($SubCommand) { $params += $SubCommand.Trim() }
          $params += $Name;
        }

        default {
          $params += $Command;
          if ($SubCommand) { $params += $SubCommand.Trim(); }
          if ($Name) { $params += $Name; }
        }
      }

      Write-Verbose "[$script] Parameters: [$params]" -Verbose:$Verbose

      $choco = Get-Command choco

      if ($choco) {
        Write-Verbose "[$script] & $choco $params" -Verbose:$Verbose
        $chocoResults = & $choco $params
        & refreshenv

        $results = @('Begin chocolatey', '')

        [Object[]]$chocoResults = $chocoResults.Split("`n");
        [List[object]]$chocoList = [List[object]]::new();
  
        foreach ($line in $chocoResults) {
          if ($line.IndexOf('[Approved]') -gt -1) {
            $line = $line.Substring(0, $line.IndexOf('[Approved]')).Trim();
            $lastIndex = $line.LastIndexOf(' ');
            $nme = $line.Substring(0, $lastIndex).Trim();
            $ver = $line.Substring($lastIndex).Trim();
            switch -regex ($Command) {
              'search' { $inst = "install $nme --version $ver -y" }
              'list' { $inst = "uninstall $nme" }
            }
            $chocoList.Add([ResultItem]::new(
                "choco", $nme, $ver, $nme, $inst
              ));
          }
        }
  
        $results += $chocoResults
        $results += @('End chocolatey', '')

        if ($Command -imatch 'search|list' ) {
          $firstItem = @([Enumerable]::OfType[ResultItem]($chocoList))[0];

          if ($Install -and $firstItem) {
            $arguments = $firstItem.Command.Split(' ')
            & $firstItem.Repo $arguments
          }

          if ($AllRepos.IsPresent -and -not $AllRepos) {
            $chocoList | Format-Table -AutoSize  
          }
          elseif (-not $AllRepos.IsPresent) {
            $chocoList | Format-Table -AutoSize  
          }
          else {
            $chocoList
          }
        }
        else {
          $results
        }
      }
    }

    function Invoke-All {
      [CmdletBinding(PositionalBinding = $true)]
      param(
        [Parameter(Position = 0)][string]$Command = 'search',
        [Parameter(Position = 1)][string]$Name = $null,
        [string]$SubCommand = $null,
        [string]$Store = 'winget',
        [switch]$Install = $false,
        [switch]$Interactive = $false
      )

      if ($Name -eq '' -and -not($Command -imatch 'list|upgrade')) {
        $Name = $Command;
        $Command = 'search';
      }

      $results = @()
      $wingetResults = Invoke-Winget $Command $Name -Store $Store -Interactive:$Interactive -AllRepos
      $scoopResults = Invoke-Scoop $Command $Name -Subcommand $Subcommand -AllRepos
      $chocoResults += Invoke-Choco $Command $Name -Subcommand $Subcommand -AllRepos

      $results = $wingetResults
      $results += $scoopResults
      $results += $chocoResults

      if ($Command -imatch 'search|list' ) {
        $results | Format-Table -Property Repo, Command -GroupBy Repo -AutoSize
      }
      else {
        $results
      }

      $firstItem = @([Enumerable]::OfType[ResultItem]($results))[0];

      if ($Install -and $firstItem) {
        $arguments = $firstItem.Command.Split(' ')
        & $firstItem.Repo $arguments
      }
    }

    set-alias -Verbose:$Verbose -Scope Global -Description "Snippets: [repos] WinGet" -Name wg -Value Invoke-Winget -PassThru
    set-alias -Verbose:$Verbose -Scope Global -Description "Snippets: [repos] Scoop" -Name scp -Value Invoke-Scoop -PassThru
    set-alias -Verbose:$Verbose -Scope Global -Description "Snippets: [repos] Chocolatey" -Name ch -Value Invoke-Choco -PassThru
    set-alias -Verbose:$Verbose -Scope Global -Description "Snippets: [repos] All Repos" -Name repos -Value Invoke-All -PassThru

    return "Repos aliases configured."
  }
  catch {
    Write-Host $Error
  }
  finally {
    Write-Verbose '[repos.ps1] Leaving...' -Verbose:$Verbose
    $Verbose = $VerboseSwitch
  }
}
else {
  $Verbose = $VerboseSwitch
  return "Wrong Operating System."
}
