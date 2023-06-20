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

# C:\Users\kingd\OneDrive\Documents\PowerShell\Snippets\PackageManagers.ps1
$packageManagers = Get-ChildItem PackageManagers.ps1 -Path $env:Snippets

if(-not $packageManagers){
  throw [ErrorRecord]::new("Cannot locate ``PackageManagers`` in ``$env:Snippets``");
}

. $packageManagers

Write-Verbose "Executing [$script]" -Verbose:$Verbose

Write-Verbose $MyInvocation

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

function Invoke-NPM
{
  [CmdletBinding(PositionalBinding = $True)]
  param(
    [Parameter(Position = 0)][string]$Command = 'search',
    [Parameter(Position = 1)][string]$Name = $null,
    [string]$SubCommand = $null,
    [switch]$Install = $false,
    [switch]$AllRepos = $false,
    [switch]$Raw = $false,
    [switch]$Describe = $false,
    [Switch]$Exact = $false
  )

  $npmManager = [NpmManager]::new();

  if ($npmManager.IsPresent)
  {
    $npmManager.Invoke($Command, $Name, $SubCommand, $null, $Install, $AllRepos, $Raw, $Describe, $VerboseSwitch, $Exact);
  }
  else
  {
    Write-Information "$($this.Name) is not a command.";
  }
}

Set-Alias -Verbose -Scope Global -Description 'Snippets: [repos] NPM' -Name np -Value Invoke-NPM -PassThru

if ($env:IsWindows -eq 'false')
{
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
        $results | Sort-Object -Property Repo, ID | Format-Table -Property Repo, Command, Line -GroupBy Repo -AutoSize
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
        [switch]$Describe = $false,
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

      $results = [List[Object]]::new();
      if ($wingetResults -is [ResultItem[]] -or $wingetResults -is [Object[]])
      {
        $results.AddRange($wingetResults)
      }
      else
      {
        $results.Add($wingetResults)
      }
      
      if ($scoopResults -is [ResultItem[]] -or $scoopResults -is [Object[]])
      {
        $results.AddRange($scoopResults)
      }
      else
      {
        $results.Add($scoopResults)
      }

      if ($chocoResults -is [ResultItem[]] -or $chocoResults -is [Object[]])
      {
        $results.AddRange($chocoResults)
      }
      else
      {
        $results.Add($chocoResults)
      }

      if ($Command -imatch 'search|list' -and -not $Raw)
      {
        if($VerboseSwitch){
          $results | Sort-Object -Property Repo, ID | Format-Table -Property Repo, Command, Line -GroupBy Repo -AutoSize
        } else {
          $results | Sort-Object -Property ID | Format-Table -Property Repo, Command -AutoSize
        }
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
