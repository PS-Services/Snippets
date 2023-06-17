using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Linq
using namespace System.Management.Automation
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
  [string]$Description;
  [PackageManager]$PackageManager;

  ResultItem(
    [string]$r,
    [string]$i,
    [string]$v,
    [string]$n,
    [string]$ins,
    [string]$d = '',
    [PackageManager]$pm
  )
  {
    $this.Repo = $r;
    $this.ID = $i;
    $this.Version = $v;
    $this.Name = $n;
    $this.Command = $ins;
    $this.Description = $d;
    $this.PackageManager = $pm;
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
  [Object[]]$List = 'list';
  [bool]$UseSudo = $false;

  PackageManager(
    [string]$N,
    [string]$Exe,
    [string]$S,
    [string]$I,
    [string]$Upg,
    [string]$Upd,
    [Object[]]$L,
    [string]$Un = 'uninstall',
    [string]$D,
    [bool]$useSudo
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
    $this.UseSudo = $useSudo;

    $this.Command = Get-Command $this.Executable -ErrorAction SilentlyContinue;
    if ($this.Command)
    {
      $this.IsPresent = $true;
      $this.IsScript = $this.Command.Source.EndsWith('.ps1');
    }
  }

  [ResultItem]ParseResultItem(
    [string]$Line, 
    [string]$Command)
  {
    return [ResultItem]::new($this.Name, $line, '', $line, $Command, $this);
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
    [switch]$Raw = $false,
    [switch]$Describe = $false)
  {
    $resultItems = [List[ResultItem]]::new();

    if ($Command -imatch 'search|list' )
    {
      foreach ($line in $executeResults)
      {
        [ResultItem]$item = $null;
  
        if ($line -is [string])
        {
          $item = $this.ParseResultItem($line, $Command);
        }
        elseif ($line -is [RemoteException] -or $line -is [ErrorRecord])
        {
          $item = $null;
        }
        else
        {
          $item = $this.ConvertItem($line, $Command);
        }
  
        if ($item)
        {
          if ($Describe.IsPresent -and $Describe)
          {
            $Description = $this.Invoke(
              'info', 
              $item.ID, 
              '', 
              '', 
              $false, 
              $AllRepos, 
              $Raw, 
              $false, 
              $false);

            if ($Description -is [Object[]])
            {
              $Description = $Description | Join-String -Separator ([System.Environment]::NewLine)
            }

            if ($Description -is [string])
            {
              $item.Description = $Description;
            }
          }
          $resultItems.Add($item);
        }
      }
  
      $type = [ResultItem];
      $firstItem = GetFirstItem -OfType $type -Enum $resultItems

      if ($Install -and $firstItem)
      {
        $arguments = $firstItem.Command.Split(' ')
        
        if ($this.UseSudo)
        {
          & sudo $this.Install $arguments
        }
        else
        {
          & $this.Install $arguments
        }
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
      return $executeResults;
    }
  }

  [Object]Execute(
    [string]$Command, 
    [Object[]]$params,
    [switch]$Install = $false,
    [switch]$AllRepos = $false,
    [switch]$Raw = $false,
    [switch]$Describe = $false,
    [bool]$Verbose = $false)
  {
    $toExecute = $this.Command.Source;

    if ($this.UseSudo)
    {
      $params = @($toExecute) + $params;
      $toExecute = 'sudo';
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
      $executeResults = & $toExecute $params 2>&1
    }

    if ($env:IsWindows -ieq 'true')
    {
      & refreshenv
    }

    return $this.ParseResults(
      $executeResults, $Command, $Install, $AllRepos, $Raw, $Describe);
  }

  [Object[]]AddParameters([Object[]]$params)
  {
    return $params;
  }

  [Object]Invoke(
    [string]$Command = 'search',
    [string]$Name = $null,
    [string]$SubCommand = $null,
    [string]$Store = 'winget',
    [switch]$Install = $false,
    [switch]$AllRepos = $false,
    [switch]$Raw = $false,
    [switch]$Describe = $false,
    [bool]$Verbose = $false,
    [bool]$Exact = $false)
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
        ('^search|find')
      {
        $params += $this.Search;
        if ($SubCommand.Trim().Length -gt 0)
        {
          $params += $SubCommand.Trim() 
        }
        $params += $itemName;
      }

        ('^install')
      {
        $params += $this.Install;
        if ($SubCommand.Trim().Length -gt 0)
        {
          $params += $SubCommand.Trim() 
        }
        $params += $itemName;
      }

        ('^upgrade')
      {
        $params += this.Upgrade;
        if ($SubCommand.Trim().Length -gt 0)
        {
          $params += $SubCommand.Trim() 
        }
        $params += $itemName;
      }

        ('^update')
      {
        $params += this.Update;
        if ($SubCommand.Trim().Length -gt 0)
        {
          $params += $SubCommand.Trim() 
        }
        $params += $itemName;
      }

        ('^uninstall|remove')
      {
        $params += $this.Uninstall;
        if ($SubCommand.Trim().Length -gt 0)
        {
          $params += $SubCommand.Trim() 
        }
        $params += $itemName;
      }

      ('^show|details|info')
      {
        $params += $this.Display;
        if ($SubCommand.Trim().Length -gt 0)
        {
          $params += $SubCommand.Trim() 
        }
        $params += $itemName;
      }
      
      ('^list')
      {
        $params += $this.List;
        if ($SubCommand.Trim().Length -gt 0)
        {
          $params += $SubCommand.Trim() 
        }
        if ($itemName)
        {
          $params += $itemName; 
        }
      }

      default
      {
        $params += $itemCommand;
        if ($SubCommand.Trim().Length -gt 0)
        {
          $params += $SubCommand.Trim(); 
        }
        if ($itemName)
        {
          $params += $itemName; 
        }
      }
    }

    $params = $this.AddParameters($params);

    if ($Exact)
    {
      $Raw = $true;
    }

    $results = $this.Execute($itemCommand, $params, $Install, $AllRepos, $Raw, $Describe, $Verbose)

    if (-not $Exact)
    {
      return $results
    }

    if (-not $AllRepos)
    {
      if ($Install)
      {
        $params = $this.AddParameters(@($this.Install, $itemName));
        switch ($this.UseSudo)
        {
          ($true)
          {
            $results = & sudo $this.Command.Source $params 2>&1 
          }
          default
          {
            $results = & $this.Command.Source $params 2>&1 
          }
        }

        return $results
      }
      else
      {
        return ($results | Where-Object ID -EQ $itemName | Format-Table -GroupBy Repo -Property Repo, Command);
      }
    }
    else
    {
      return $results | Where-Object ID -EQ $itemName;
    }
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
      'upgrade', 'update', @('list','--installed'), 'remove', 'info', $true
    )
    {
    }

    [Object[]]AddParameters([Object[]]$params)
    {
      if($params[0] -ieq 'list'){
        return $params;
      }
      
      return $params + '-y';
    }

    [ResultItem]ParseResultItem([string]$Line, [string]$Command)
    {
      # golang-github-sahilm-fuzzy-dev/stable,oldstable,testing 0.1.0-1.1 all
      $regex = [Regex]::new('^([A-Za-z0-9_\-\.+]+)\/[A-Za-z0-9_\-\,]+\s+([A-Za-z0-9\.\-+]+)\s?');

      if ($regex.IsMatch($line))
      {
        $id = $regex.Match($line).Groups[1].Value.Trim();
        $ver = $regex.Match($line).Groups[2].Value.Trim();
        $desc = $null;
        $index = $line.IndexOf($id);
        $nme = $line.Substring(0, $index).Trim();
        $inst = '';
        switch -regex ($Command)
        {
          'search'
          {
            $inst = "install $id=$ver" 
          }
          'list'
          {
            $inst = "uninstall $id" 
          }
        }
      
        return [ResultItem]::new(
          "sudo $($this.Executable)", $id, $ver, $nme, $inst, $desc, $this
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
      'upgrade', 'update', 'list', 'uninstall', 'info', $false
    )
    {
    }

    [ResultItem]ParseResultItem([string]$Line, [string]$Command)
    {
      # golang-github-sahilm-fuzzy-dev/stable,oldstable,testing 0.1.0-1.1 all
      $regex = [Regex]::new('^([A-Za-z0-9_\-]+@?(\d*))');

      if ($regex.IsMatch($line))
      {
        $id = $regex.Match($line).Groups[1].Value.Trim();

        $ver = '';
        if ($regex.Match($line).Groups.Count -gt 2)
        {
          $ver = $regex.Match($line).Groups[2].Value.Trim();
        }

        $desc = $null;
        $index = $line.IndexOf($id);
        $nme = $line.Substring(0, $index).Trim();
        $inst = '';
        switch -regex ($Command)
        {
          'search'
          {
            if ($ver.Length -eq 0)
            {
              $inst = "install $id";
            }
            else
            {
              $inst = "install $id@$ver";
            }
          }
          'list'
          {
            $inst = "uninstall $id";
          }
        }
      
        return [ResultItem]::new(
          $this.Executable, $id, $ver, $id, $inst, $desc, $this
        );
      }

      return $null;
    }
  }

  class SnapManager : PackageManager
  {

    SnapManager() : base(
      'snap', 'snap', 'find', 'install',
      'upgrade', 'refresh', 'list', 'remove', 'info', $true
    )
    {
    }

    [ResultItem]ParseResultItem([string]$Line, [string]$Command)
    {
      # golang-github-sahilm-fuzzy-dev/stable,oldstable,testing 0.1.0-1.1 all
      $regex = [Regex]::new('^(?!Name)([\w\d\-]+)\s+([\w\d\.\-+]+)\s+[\d\s]*\s*[^\s]*\s*[^\s]+\s+(.*)');

      if ($regex.IsMatch($line))
      {
        $id = $regex.Match($line).Groups[1].Value.Trim();

        $ver = '';
        if ($regex.Match($line).Groups.Count -gt 2)
        {
          $ver = $regex.Match($line).Groups[2].Value.Trim();
        }

        $desc = $null;
        if ($regex.Match($line).Groups.Count -gt 3)
        {
          $desc = $regex.Match($line).Groups[3].Value.Trim();
        }
        $inst = '';
        switch -regex ($Command)
        {
          'search'
          {
            if ($ver.Length -eq 0)
            {
              $inst = "install $id";
            }
            else
            {
              $inst = "$($this.Install) $id";
            }
          }
          'list'
          {
            $inst = "$($this.Uninstall) $id";
          }
        }
      
        return [ResultItem]::new(
          "sudo $($this.Executable)", $id, $ver, $id, $inst, $desc, $this
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
        [switch]$Install = $false,
        [switch]$Interactive = $false,
        [switch]$AllRepos = $false,
        [switch]$Raw = $false,
        [switch]$Describe = $false,
        [Switch]$Exact = $false
      )

      $aptManager = [AptManager]::new();
      if ($aptManager.IsPresent)
      {
        $aptManager.Invoke($Command, $Name, '', $Store, $Install, $AllRepos, $Raw, $Describe, $VerboseSwitch, $Exact);
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
        [switch]$AllRepos = $false,
        [switch]$VerboseSwitch = $false,
        [switch]$Raw = $false,
        [switch]$Describe = $false,
        [Switch]$Exact = $false
      )

      $brewManager = [HomebrewManager]::new();

      if ($brewManager.IsPresent)
      {
        $brewManager.Invoke($Command, $Name, $SubCommand, $Store, $Install, $AllRepos, $Raw, $Describe, $VerboseSwitch, $Exact);
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
        [switch]$Raw = $false,
        [switch]$Describe = $false,
        [Switch]$Exact = $false
      )

      $snapManager = [SnapManager]::new();

      if ($snapManager.IsPresent)
      {
        $snapManager.Invoke($Command, $Name, $SubCommand, $null, $Install, $AllRepos, $Raw, $Describe, $VerboseSwitch, $Exact);
      }
      else
      {
        Write-Information "$($this.Name) is not a command.";
      }
    }

    function Invoke-AllLinux
    {
      [CmdletBinding(PositionalBinding = $true)]
      param(
        [Parameter(Position = 0)][string]$Command = 'search',
        [Parameter(Position = 1)][string]$Name = $null,
        [string]$SubCommand = $null,
        [string]$Store = 'winget',
        [switch]$Install = $false,
        [switch]$Interactive = $false,
        [switch]$Raw = $false,
        [switch]$Describe = $false,
        [Switch]$Exact = $false
      )

      if ($Name -eq '' -and -not($Command -imatch 'list|upgrade'))
      {
        $Name = $Command;
        $Command = 'search';
      }

      if ($Install)
      {
        $Raw = $Install;
      }

      $results = @()
      $aptResults = Invoke-Apt $Command $Name -AllRepos -Raw:$Raw -Describe:$Describe -Exact:$Exact -Install:$Install
      $brewResults = Invoke-Homebrew $Command $Name -Subcommand $Subcommand -AllRepos -Raw:$Raw -Describe:$Describe -Exact:$Exact -Install:$Install
      $snapResults = Invoke-Snap $Command $Name -Subcommand $Subcommand -AllRepos -Raw:$Raw -Describe:$Describe -Exact:$Exact -Install:$Install

      $results = [List[Object]]::new();
      if ($aptResults -is [ResultItem[]] -or $aptResults -is [Object[]])
      {
        $results.AddRange($aptResults)
      }
      else
      {
        $results.Add($aptResults)
      }
      
      if ($brewResults -is [ResultItem[]] -or $brewResults -is [Object[]])
      {
        $results.AddRange($brewResults)
      }
      else
      {
        $results.Add($brewResults)
      }

      if ($snapResults -is [ResultItem[]] -or $snapResults -is [Object[]])
      {
        $results.AddRange($snapResults)
      }
      else
      {
        $results.Add($snapResults)
      }

      if ($Command -imatch 'search|list' -and -not $Raw)
      {
        $results | Sort-Object -Property Repo, ID | Format-Table -Property Repo, Command -GroupBy Repo -AutoSize
      }
      else
      {
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

          if ($firstItem.PackageManager)
          {
            if ($firstItem.PackageManager.UseSudo)
            {
              & sudo $firstItem.PackageManager.Command.Source $arguments;
            }
            else
            {
              & $firstItem.PackageManager.Command.Source $arguments;
            }
          }
          else
          {
            & $firstItem.Repo $arguments
          }
        }
        else
        {
          $results
        }
      }
    }

    Set-Alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [repos] apt' -Name ap -Value Invoke-Apt -PassThru
    Set-Alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [repos] homebreq' -Name br -Value Invoke-Homebrew -PassThru
    Set-Alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [repos] snap' -Name sn -Value Invoke-Snap -PassThru
    Set-Alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [repos] All Repos' -Name repos -Value Invoke-AllLinux -PassThru

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
  class WinGetManager : PackageManager
  {
    [string]$Store = 'winget';
    [switch]$InteractiveParameter = $false;
  
    WinGetManager([string]$S, [switch]$I) : base(
      'winget', 'winget', 'search', 'install',
      'upgrade', 'update', 'list', 'uninstall', 'show', $false
    )
    {
      $this.Store = $s;
      $this.InteractiveParameter = $i;
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
          $this.Executable, $id, $ver, $nme, $inst, $null, $this
        );
      }
  
      return $null;
    }
  }
  
  class ScoopManager : PackageManager
  {
    [string]$Store = 'main';
  
    ScoopManager([string]$S) : base(
      'scoop', 'scoop', 'search', 'install',
      'upgrade', 'update', 'list', 'uninstall', 'show', $false
    )
    {
      $this.Store = $s;
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
        $this.Executable, $nme, $ver, $nme, $inst, $null, $this
      );
    }
  }
  
  class ChocoManager : PackageManager
  {
  
    ChocoManager() : base(
      'choco', 'choco', 'search', 'install',
      'upgrade', 'update', 'list', 'uninstall', 'show', $true
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
          "sudo $($this.Executable)", $nme, $ver, $nme, $inst, $null, $this
        );
      }
    
      return $null;
    }
  }
  
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
        [switch]$Raw = $false,
        [switch]$Describe = $false,
        [Switch]$Exact = $false
      )

      $wingetManager = [WinGetManager]::new($Store, $Interactive);
      if ($wingetManager.IsPresent)
      {
        $wingetManager.Invoke($Command, $Name, '', $Store, $Install, $AllRepos, $Raw, $Describe, $VerboseSwitch, $Exact);
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
        [switch]$AllRepos = $false,
        [switch]$Raw = $false,
        [switch]$Describe = $false,
        [Switch]$Exact = $false
      )

      $scoopManager = [ScoopManager]::new($Store);

      if ($scoopManager.IsPresent)
      {
        $scoopManager.Invoke($Command, $Name, $SubCommand, $Store, $Install, $AllRepos, $Raw, $Describe, $VerboseSwitch, $Exact);
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
        [switch]$Raw = $false,
        [switch]$Describe = $false,
        [Switch]$Exact = $false
      )

      $chocoManager = [ChocoManager]::new();

      if ($chocoManager.IsPresent)
      {
        $chocoManager.Invoke($Command, $Name, $SubCommand, $null, $Install, $AllRepos, $Raw, $Describe, $VerboseSwitch, $Exact);
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
        [switch]$Raw = $false,
        [Switch]$Exact = $false
      )

      if ($Name -eq '' -and -not($Command -imatch 'list|upgrade'))
      {
        $Name = $Command;
        $Command = 'search';
      }

      $results = @()
      $wingetResults = Invoke-Winget $Command $Name -Store $Store -Interactive:$Interactive -AllRepos -Raw:$Raw -Describe:$Describe -Exact:$Exact -Install:$Install
      $scoopResults = Invoke-Scoop $Command $Name -Subcommand $Subcommand -AllRepos -Raw:$Raw -Describe:$Describe -Exact:$Exact -Install:$Install
      $chocoResults += Invoke-Choco $Command $Name -Subcommand $Subcommand -AllRepos -Raw:$Raw -Describe:$Describe -Exact:$Exact -Install:$Install

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
