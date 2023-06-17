using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Linq
using namespace System.Reflection
using namespace System.Text.RegularExpressions

param([switch]$VerboseSwitch = $false)

# $Verbose=$true -or $VerboseSwitch
$Verbose = $VerboseSwitch
# Write-Verbose "[$script] [$env:SnippetsInitialized] -not `$env:SnippetsInitialized: $(-not $env:SnippetsInitialized)" -Verbose:$Verbose
$script = $MyInvocation.MyCommand

Write-Verbose $MyInvocation

class ResultItem
{
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
  )
  {
    $this.Repo = $r;
    $this.ID = $i;
    $this.Version = $v;
    $this.Name = $n;
    $this.Command = $ins;
  }
}

class PackageManager
{
  [string]$Name;
  [string]$Executable;
  [Object]$Command;
  [bool]$IsScript = $false;
  [bool]$IsPresent = $false;
  [string]$Search = 'search';
  [string]$Install = 'install';
  [string]$Upgrade = 'upgrade';
  [string]$Update = 'update';
  [string]$Uninstall = 'uninstall';
  [string]$Display = 'show';
  [string]$List = 'list';

  PackageManager(
    [string]$N,
    [string]$Exe,
    [string]$S,
    [string]$I,
    [string]$Upg,
    [string]$Upd,
    [string]$L,
    [string]$Un = 'uninstall',
    [string]$D
  )
  {
    $this.Name = $N;
    $this.Executable = $Exe;
    $this.Search = $S;
    $this.Install = $I;
    $this.Upgrade = $Upg;
    $this.Update = $Upd;
    $this.List = $L;
    $this.Uninstall = $Un;
    $this.Display = $D;

    $this.Command = Get-Command $this.Executable -ErrorAction SilentlyContinue;
    if ($this.Command)
    {
      $this.IsPresent = $true;
      $this.IsScript = $this.Command.Source.EndsWith('.ps1');
    }
  }

  [ResultItem]ParseResultItem([string]$Line, [string]$Command)
  {
    return [ResultItem]::new($this.Name, $line, '', $line, $Command);
  }

  [ResultItem]ConvertItem([Object]$item, $Command)
  {
    $json = ConvertTo-Json $item;

    return $this.ParseResultItem($json.ToString(), $Command);
  }

  [Object]ParseResults(
    [Object[]]$executeResults, 
    [string]$Command,
    [switch]$Install = $false,
    [switch]$AllRepos = $false,
    [switch]$Raw = $false)
  {
    
    $resultItems = [List[ResultItem]]::new();

    foreach ($line in $executeResults)
    {
      [ResultItem]$item = $null;

      if ($line -is [string])
      {
        $item = $this.ParseResultItem($line, $Command);
      }
      else
      {
        $item = $this.ConvertItem($line, $Command);
      }

      if ($item)
      {
        $resultItems.Add($item);
      }
    }

    if ($Command -imatch 'search|list' )
    {
      $type = [ResultItem];
      $firstItem = GetFirstItem -OfType $type -Enum $resultItems

      if ($Install -and $firstItem)
      {
        $arguments = $firstItem.Command.Split(' ')
        & $firstItem.Repo $arguments
      }

      if ($AllRepos.IsPresent -and -not $AllRepos -and -not $Raw)
      {
        return $resultItems | Sort-Object -Property ID | Format-Table -AutoSize  
      }
      elseif (-not $AllRepos.IsPresent -and -not $Raw)
      {
        return $resultItems | Sort-Object -Property ID | Format-Table -AutoSize  
      }
      else
      {
        return $resultItems
      }
    }
    else
    {
      return $resultItems;
    }
  }

  [Object]Execute(
    [string]$Command, 
    [Object[]]$params,
    [switch]$Install = $false,
    [switch]$AllRepos = $false,
    [switch]$Raw = $false,
    [switch]$Verbose = $false,
    [switch]$Sudo = $false)
  {
    $toExecute = $this.Command.Source;

    if($Sudo.IsPresent -and $Sudo.ToBool()){
      $params = @($toExecute) + $params;
      $toExecute = "sudo";
    }

    $executeResults = '';
    if ($this.IsScript)
    {
      Write-Verbose "[$($this.Name)] Invoke-Expression `"& `"$toExecute`" $params`"" -Verbose:$Verbose
      $executeResults = Invoke-Expression "& `"$toExecute`" $params"
    }
    else
    {
      Write-Verbose "[$($this.Name)] & $toExecute $params" -Verbose:$Verbose
      $executeResults = & $toExecute $params
    }
    & refreshenv

    return $this.ParseResults(
      $executeResults, $Command, $Install, $AllRepos, $Raw);
  }

  [Object]Invoke(
    [string]$Command = 'search',
    [string]$Name = $null,
    [string]$SubCommand = $null,
    [string]$Store = 'winget',
    [switch]$Install = $false,
    [switch]$AllRepos = $false,
    [switch]$Raw = $false,
    [switch]$Verbose = $false,
    [switch]$Sudo = $false)
  {

    $itemName = $Name;
    $itemCommand = $Command;
      
    if ($Name -eq '' -and -not($Command -imatch 'list|upgrade'))
    {
      $itemName = $Command;
      $itemCommand = 'search';
    }

    if ($Install)
    {
      $itemCommand = 'search'
    }

    $params = @()

    Switch -regex ($itemCommand)
    {
        ('search|find')
      {
        $params += $this.Search;
        if ($SubCommand)
        {
          $params += $SubCommand.Trim() 
        }
        $params += $itemName;
      }

        ('install')
      {
        $params += $this.Install;
        if ($SubCommand)
        {
          $params += $SubCommand.Trim() 
        }
        $params += $itemName;
      }

        ('upgrade')
      {
        $params += this.Upgrade;
        if ($SubCommand)
        {
          $params += $SubCommand.Trim() 
        }
        $params += $itemName;
      }

        ('update')
      {
        $params += this.Update;
        if ($SubCommand)
        {
          $params += $SubCommand.Trim() 
        }
        $params += $itemName;
      }

        ('uninstall|remove')
      {
        $params += this.Uninstall;
        if ($SubCommand)
        {
          $params += $SubCommand.Trim() 
        }
        $params += $itemName;
      }

        ('show|details|info')
      {
        $params += $this.Display;
        if ($SubCommand)
        {
          $params += $SubCommand.Trim() 
        }
        $params += $itemName;
      }

      default
      {
        $params += $itemCommand;
        if ($SubCommand)
        {
          $params += $SubCommand.Trim(); 
        }
        if ($Name)
        {
          $params += $itemName; 
        }
      }
    }

    return $this.Execute($itemCommand, $params, $Install, $AllRepos, $Raw, $Verbose, $Sudo)
  }
}

function GetFirstItem([TypeInfo]$OfType, [IEnumerable]$Enum)
{
  foreach ($currentItem in $Enum)
  {
    if ($currentItem -is $OfType)
    {
      $item = $currentItem;
      break;
    }
  }

  return $item;
}

if (-not $env:SnippetsInitialized)
{
  $fileInfo = New-Object FileInfo (Get-Item $PSScriptRoot).FullName
  $path = $fileInfo.Directory.FullName;
  . $path/Snippets/common.ps1;
  Initialize-Snippets -Verbose:$Verbose
}

if ($env:IsWindows -eq 'false')
{  
  class AptManager : PackageManager
  {
    AptManager() : base(
      'apt', 'apt', 'search', 'install',
      'upgrade', 'update', 'list', 'remove', 'info'
    )
    {
    }

    [ResultItem]ParseResultItem([string]$Line, [string]$Command)
    {
      $regex = [Regex]::new('^.+\s+([A-Za-z0-9_-]+\.[A-Za-z0-9_-]+)\s+([\d\.]+)\s?');

      if ($regex.IsMatch($line))
      {
        $id = $regex.Match($line).Groups[1].Value.Trim();
        $ver = $regex.Match($line).Groups[2].Value.Trim();
        $index = $line.IndexOf($id);
        $nme = $line.Substring(0, $index).Trim();
        $inst = '';
        $interactive = '';
        if ($this.InteractiveParameter.IsPresent -and 
          $this.InteractiveParameter.ToBool())
        {
          $interactive = '-i';
        }
        switch -regex ($Command)
        {
          'search'
          {
            $inst = "install $id --version $ver --source $($this.Store) $interactive" 
          }
          'list'
          {
            $inst = "uninstall $id" 
          }
        }
      
        return [ResultItem]::new(
          $this.Executable, $id, $ver, $nme, $inst
        );
      }

      return $null;
    }
  }

  class HomebrewManager : PackageManager
  {
    [string]$Store = 'main';

    HomebrewManager() : base(
      'brew', 'brew', 'search', 'install',
      'upgrade', 'update', 'list', 'uninstall', 'show'
    )
    {
    }

    [ResultItem]ParseResultItem([string]$Line, [string]$Command)
    {
      $json = ConvertFrom-Json $Line;
      $ver = $json.version;
      $nme = $json.name;
      $inst = $Command;
      switch -regex ($Command)
      {
        'search'
        { 

          [string]$bucket = '';

          if ($this.Store)
          {
            $bucket = "--bucket $($this.Store)";
          }

          switch ($line.Source.Length -gt 0)
          {
            ($True)
            {
              $bucket = "--bucket $($json.Source)"; 
            }
            default
            { 
            }
          }

          if ($ver)
          {
            $inst = "$($this.Install) $($nme)@$($ver) $bucket".Trim();
          }
          else
          {
            $inst = "$($this.Install) $nme $bucket".Trim();
          }
        }
        'list'
        {
          $inst = "$($this.Uninstall) $nme" 
        }
      }
      return [ResultItem]::new(
        $this.Executable, $nme, $ver, $nme, $inst
      );
    }
  }

  class SnapManager : PackageManager
  {

    SnapManager() : base(
      'snap', 'snap', 'search', 'install',
      'upgrade', 'update', 'list', 'uninstall', 'show'
    )
    {
    }

    [ResultItem]ParseResultItem([string]$Line, [string]$Command)
    {
      if ($line.IndexOf('[Approved]') -gt -1)
      {
        $line = $line.Substring(0, $line.IndexOf('[Approved]')).Trim();
        $lastIndex = $line.LastIndexOf(' ');
        $nme = $line.Substring(0, $lastIndex).Trim();
        $ver = $line.Substring($lastIndex).Trim();
        $inst = $Command;
        switch -regex ($Command)
        {
          'search'
          {
            $inst = "install $nme --version $ver -y" 
          }
          'list'
          {
            $inst = "uninstall $nme" 
          }
        }
        return [ResultItem]::new(
          $this.Executable, $nme, $ver, $nme, $inst
        );
      }
  
      return $null;
    }
  }

  try
  {
    function Invoke-Apt
    {
      [CmdletBinding(PositionalBinding = $True)]
      param(
        [Parameter(Position = 0)][string]$Command = 'search',
        [Parameter(Position = 1)][string]$Name = $null,
        [string]$Store = 'winget',
        [switch]$Install = $false,
        [switch]$Interactive = $false,
        [switch]$AllRepos = $false,
        [switch]$Raw = $false
      )

      $aptManager = [AptManager]::new();
      if ($aptManager.IsPresent)
      {
        $aptManager.Invoke($Command, $Name, '', $Store, $Install, $AllRepos, $Raw, $VerboseSwitch, $true);
      }
      else
      {
        Write-Information "$($this.Name) is not a command.";
      }
    }

    function Invoke-Homebrew
    {
      [CmdletBinding(PositionalBinding = $True)]
      param(        
        [Parameter(Position = 0)][string]$Command = 'search',        
        [Parameter(Position = 1)][string]$Name = $null,
        [string]$SubCommand = $null,
        [string]$Store = 'main',
        [switch]$Install = $false,
        [switch]$AllRepos = $false
      )

      $brewManager = [HomebrewManager]::new($Store);

      if ($brewManager.IsPresent)
      {
        $brewManager.Invoke($Command, $Name, $SubCommand, $Store, $Install, $AllRepos, $Raw, $VerboseSwitch, $true);
      }
      else
      {
        Write-Information "$($this.Name) is not a command.";
      }
    }

    function Invoke-Snap
    {
      [CmdletBinding(PositionalBinding = $True)]
      param(
        [Parameter(Position = 0)][string]$Command = 'list',
        [Parameter(Position = 1)][string]$Name = $null,
        [string]$SubCommand = $null,
        [switch]$Install = $false,
        [switch]$AllRepos = $false,
        [switch]$Raw = $false
      )

      $snapManager = [SnapManager]::new();

      if ($snapManager.IsPresent)
      {
        $snapManager.Invoke($Command, $Name, $SubCommand, $null, $Install, $AllRepos, $Raw, $VerboseSwitch, $true);
      }
      else
      {
        Write-Information "$($this.Name) is not a command.";
      }
    }

    function Invoke-All
    {
      [CmdletBinding(PositionalBinding = $true)]
      param(
        [Parameter(Position = 0)][string]$Command = 'search',
        [Parameter(Position = 1)][string]$Name = $null,
        [string]$SubCommand = $null,
        [string]$Store = 'winget',
        [switch]$Install = $false,
        [switch]$Interactive = $false,
        [switch]$Raw = $false
      )

      if ($Name -eq '' -and -not($Command -imatch 'list|upgrade'))
      {
        $Name = $Command;
        $Command = 'search';
      }

      $results = @()
      $aptResults = Invoke-Apt $Command $Name -AllRepos
      $brewResults = Invoke-Homebrew $Command $Name -Subcommand $Subcommand -AllRepos
      $snapResults += Invoke-Snap $Command $Name -Subcommand $Subcommand -AllRepos

      $results = $aptResults
      $results += $brewResults
      $results += $snapResults

      if ($Command -imatch 'search|list' -and -not $Raw)
      {
        $results | Sort-Object -Property Repo, ID | Format-Table -Property Repo, Command -GroupBy Repo -AutoSize
      }
      else
      {
        $results
      }

      if ($results -is [ResultItem])
      {
        [List[ResultItem]]$list = [List[ResultItem]]::new();
        $list.Add($results);
        $results = $list
      }

      $type = [ResultItem];
      $firstItem = GetFirstItem -OfType $type -Enum $results

      if ($Install -and $firstItem)
      {
        $arguments = $firstItem.Command.Split(' ')
        & $firstItem.Repo $arguments
      }
    }

    Set-Alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [repos] apt' -Name ap -Value Invoke-Apt -PassThru
    Set-Alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [repos] homebreq' -Name br -Value Invoke-Homebrew -PassThru
    Set-Alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [repos] snap' -Name sn -Value Invoke-Snap -PassThru
    Set-Alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [repos] All Repos' -Name repos -Value Invoke-All -PassThru

    return 'Repos aliases configured.'
  }
  catch
  {
    Write-Host $Error
  }
  finally
  {
    Write-Verbose '[repos.ps1] Leaving...' -Verbose:$Verbose
    $Verbose = $VerboseSwitch
  }
}
else
{
  try
  {
    function Invoke-Winget
    {
      [CmdletBinding(PositionalBinding = $True)]
      param(
        [Parameter(Position = 0)][string]$Command = 'search',
        [Parameter(Position = 1)][string]$Name = $null,
        [string]$Store = 'winget',
        [switch]$Install = $false,
        [switch]$Interactive = $false,
        [switch]$AllRepos = $false,
        [switch]$Raw = $false
      )

      $wingetManager = [WinGetManager]::new($Store, $Interactive);
      if ($wingetManager.IsPresent)
      {
        $wingetManager.Invoke($Command, $Name, '', $Store, $Install, $AllRepos, $Raw, $VerboseSwitch, $false);
      }
      else
      {
        Write-Information "$($this.Name) is not a command.";
      }
    }

    function Invoke-Scoop
    {
      [CmdletBinding(PositionalBinding = $True)]
      param(        
        [Parameter(Position = 0)][string]$Command = 'search',        
        [Parameter(Position = 1)][string]$Name = $null,
        [string]$SubCommand = $null,
        [string]$Store = 'main',
        [switch]$Install = $false,
        [switch]$AllRepos = $false
      )

      $scoopManager = [ScoopManager]::new($Store);

      if ($scoopManager.IsPresent)
      {
        $scoopManager.Invoke($Command, $Name, $SubCommand, $Store, $Install, $AllRepos, $Raw, $VerboseSwitch, $false);
      }
      else
      {
        Write-Information "$($this.Name) is not a command.";
      }
    }

    function Invoke-Choco
    {
      [CmdletBinding(PositionalBinding = $True)]
      param(
        [Parameter(Position = 0)][string]$Command = 'list',
        [Parameter(Position = 1)][string]$Name = $null,
        [string]$SubCommand = $null,
        [switch]$Install = $false,
        [switch]$AllRepos = $false,
        [switch]$Raw = $false
      )

      $chocoManager = [ChocoManager]::new();

      if ($chocoManager.IsPresent)
      {
        $chocoManager.Invoke($Command, $Name, $SubCommand, $null, $Install, $AllRepos, $Raw, $VerboseSwitch, $true);
      }
      else
      {
        Write-Information "$($this.Name) is not a command.";
      }
    }

    function Invoke-All
    {
      [CmdletBinding(PositionalBinding = $true)]
      param(
        [Parameter(Position = 0)][string]$Command = 'search',
        [Parameter(Position = 1)][string]$Name = $null,
        [string]$SubCommand = $null,
        [string]$Store = 'winget',
        [switch]$Install = $false,
        [switch]$Interactive = $false,
        [switch]$Raw = $false
      )

      if ($Name -eq '' -and -not($Command -imatch 'list|upgrade'))
      {
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

      if ($Command -imatch 'search|list' -and -not $Raw)
      {
        $results | Sort-Object -Property Repo, ID | Format-Table -Property Repo, Command -GroupBy Repo -AutoSize
      }
      else
      {
        $results
      }

      if ($results -is [ResultItem])
      {
        [List[ResultItem]]$list = [List[ResultItem]]::new();
        $list.Add($results);
        $results = $list
      }

      $type = [ResultItem];
      $firstItem = GetFirstItem -OfType $type -Enum $results

      if ($Install -and $firstItem)
      {
        $arguments = $firstItem.Command.Split(' ')
        & $firstItem.Repo $arguments
      }
    }

    Set-Alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [repos] WinGet' -Name wg -Value Invoke-Winget -PassThru
    Set-Alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [repos] Scoop' -Name scp -Value Invoke-Scoop -PassThru
    Set-Alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [repos] Chocolatey' -Name ch -Value Invoke-Choco -PassThru
    Set-Alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [repos] All Repos' -Name repos -Value Invoke-All -PassThru

    return 'Repos aliases configured.'
  }
  catch
  {
    Write-Host $Error
  }
  finally
  {
    Write-Verbose '[repos.ps1] Leaving...' -Verbose:$Verbose
    $Verbose = $VerboseSwitch
  }
}
