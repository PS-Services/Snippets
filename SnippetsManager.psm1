using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Linq
using namespace System.Management.Automation
using namespace System.Reflection
using namespace System.Text.RegularExpressions

<#
    .Description
    The `ResultItem` class is returned by the RepositorySnippets module as list results.
#>
class ResultItem {
    [string]$Repo
    [string]$Command
    [string]$ID
    [string]$Version
    [string]$Name
    [string]$Description
    [PackageManager]$PackageManager
    [string]$Line

    ResultItem(
        [string]$r,
        [string]$i,
        [string]$v,
        [string]$n,
        [string]$ins,
        [string]$d = '',
        [PackageManager]$pm,
        [string]$l
    ) {
        $this.Repo = $r
        $this.ID = $i
        $this.Version = $v
        $this.Name = $n
        $this.Command = $ins
        $this.Description = $d
        $this.PackageManager = $pm
        $this.Line = $l
    }

    [string]ToString() {
        return $this.Line
    }
}

<#
    .Description
    The `PackageManager` class is the base class for Package Managers defined in the RepositorySnippets module.
#>
class PackageManager {
    [string]$Name
    [string]$Executable
    [Object]$Command
    [bool]$IsScript = $false
    [bool]$IsPresent = $false
    [string]$Search = 'search'
    [string]$Install = 'install'
    [string]$Upgrade = 'upgrade'
    [string]$Update = 'update'
    [string]$Uninstall = 'uninstall'
    [string]$Display = 'show'
    [Object[]]$List = 'list'
    [bool]$UseSudo = $false
    [int]$ExitCode = 0

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
    ) {
        $this.Name = $N
        $this.Executable = $Exe
        $this.Search = $S
        $this.Install = $I
        $this.Upgrade = $Upg
        $this.Update = $Upd
        $this.List = $L
        $this.Uninstall = $Un
        $this.Display = $D
        $this.UseSudo = $useSudo

        $this.Command = Get-Command $this.Executable -ErrorAction SilentlyContinue
        if ($this.Command) {
            $this.IsPresent = $true
            $this.IsScript = $this.Command.Source.EndsWith('.ps1')
        }
    }

    <#
        .Description
        The `ParseResultItem` method is overwridden in each `PackageManager` sub-class.

        This method parses individual lines of text and if a `ResultItem` can be created then
        it creates a new `ResultItem` and returns it, otherwise it returns `$null`.
    #>
    [ResultItem]ParseResultItem(
        [string]$Line,
        [string]$Command,
        [Switch]$Global) {
        return [ResultItem]::new($this.Name, $line, '', $line, $Command, $this, $Line)
    }

    <#
        .Description
        The `ConvertItem` method can be overwridden in each `PackageManager` sub-class.

        This method converts objects to JSON and then submits the JSON to the `ParseResultItem` method.
    #>
    [ResultItem]ConvertItem([Object]$item, [Switch]$Global, $Command) {
        [string]$json = ConvertTo-Json $item -Depth 3 -EnumsAsStrings -Compress
        if ($item -is [Microsoft.PowerShell.Commands.MemberDefinition]) {
            $def = ($item.Definition.Replace("System.Management.Automation.PSCustomObject $($item.Name)=@", '').Trim('{}'.ToCharArray()).Split(';'))

            foreach ($line in $def) {
                if ($line.StartsWith('version')) {
                    $parts = $line.Split('=')

                    [ResultItem]$resultItem = [ResultItem]::new($this.Name, $item.Name, $parts[1], $item.Name, '', '', $null, '')

                    $json = ConvertTo-Json $resultItem -Depth 3 -EnumsAsStrings -Compress
                }
            }
        }

        if ($json) {
            return $this.ParseResultItem($json.ToString(), $Command, $Global)
        }

        return $item.toString()
    }

    <#
        .Description
        The `ParseResults` method _should not_ be overwridden in each `PackageManager` sub-class.

        This method parses the results returned by a Package Manager by sending each line of text or object to
        the `ConvertItem` (for objects) or `ParseResultItem` (for text), and aggregates the results to a `List[ResultItem]`
        collection.
    #>
    [Object]ParseResults(
        [Object[]]$executeResults,
        [string]$Command,
        [switch]$Install = $false,
        [switch]$AllRepos = $false,
        [switch]$Raw = $false,
        [switch]$Describe = $false,
        [switch]$Global = $false,
        [bool]$Verbose = $false) {
        $resultItems = [List[ResultItem]]::new()

        if ($Command -imatch 'search|list' ) {
            foreach ($line in $executeResults) {
                [ResultItem]$item = $null

                if ($line -is [string]) {
                    $item = $this.ParseResultItem($line, $Command, $Global)
                }
                elseif ($line -is [RemoteException] -or $line -is [ErrorRecord]) {
                    $item = $null
                }
                else {
                    $item = $this.ConvertItem($line, $Global, $Command)
                }

                if ($item) {
                    if ($Describe.IsPresent -and $Describe) {
                        $Description = $this.Invoke(
                            'info',
                            $item.ID,
                            '',
                            '',
                            $false,
                            $AllRepos,
                            $Raw,
                            $false,
                            $Global,
                            $false,
                            $false,
                            @())

                        if ($Description -is [Object[]]) {
                            $Description = $Description | Join-String -Separator ([System.Environment]::NewLine)
                        }

                        if ($Description -is [string]) {
                            $item.Description = $Description
                        }
                    }
                    $resultItems.Add($item)
                }
            }

            $type = [ResultItem]
            $firstItem = GetFirstItem -OfType $type -Enum $resultItems

            if ($Install -and $firstItem) {
                $arguments = $firstItem.Command.Split(' ')

                if ($this.UseSudo) {
                    & sudo $this.Install $arguments
                }
                else {
                    & $this.Install $arguments
                }
            }

            if (($AllRepos.IsPresent -and -not $AllRepos -and -not $Raw) -or
            (-not $AllRepos.IsPresent -and -not $Raw)) {
                if ($Verbose) {
                    return $resultItems | Sort-Object -Property ID | Format-Table -AutoSize
                }

                return $resultItems | Sort-Object -Property ID | Format-Table -AutoSize -Property Repo, Command
            }
            else {
                return $resultItems
            }
        }
        else {
            return $executeResults
        }
    }

    <#
        .Description
        The `Execute` method _should not_ be overwridden in each `PackageManager` sub-class.

        This method executes the command being invoked on the Package Manager and returns the raw results.
    #>
    [Object]Execute(
        [string]$Command,
        [Object[]]$params,
        [switch]$Install = $false,
        [switch]$AllRepos = $false,
        [switch]$Raw = $false,
        [switch]$Describe = $false,
        [switch]$Global = $false,
        [bool]$Verbose = $false,
        [bool]$Sudo = $false) {
        $toExecute = $this.Command.Source

        if ($Sudo) {
            $params = @($toExecute) + $params
            $toExecute = 'sudo'
        }

        $executeResults = ''
        if ($this.IsScript) {
            Write-Verbose "[$($this.Name)] Invoke-Expression `"& `"$toExecute`" $params`"" -Verbose:$Verbose
            $executeResults = Invoke-Expression "& `"$toExecute`" $params"
        }
        else {
            Write-Verbose "[$($this.Name)] & $toExecute $params" -Verbose:$Verbose
            $executeResults = & $toExecute $params 2>&1

            try {
                $fromJson = $executeResults | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($fromJson) {
                    if ($fromJson.dependencies) {
                        $executeResults = @()
                        foreach ($dep in $fromJson.dependencies) {
                            $members = $dep | Get-Member -MemberType NoteProperty -ErrorAction SilentlyContinue
                            if ($members) {
                                foreach ($member in $members) {
                                    $executeResults += $member
                                }
                            }
                        }
                    }
                    else {
                        $executeResults = $fromJson
                    }
                }
            }
            catch {
            }

            $this.ExitCode = $LASTEXITCODE
        }

        if ($this.ExitCode -ne 0) {
            if ($executeResults -is [string]) {
                return $executeResults
            }

            if ($executeResults -is [ResultItem[]]) {
                return $executeResults.Line
            }

            if ($executeResults -is [ResultItem]) {
                return $executeResults.Line
            }

            if ($executeResults -is [Object[]]) {
                [List[string]]$resultStrings = [List[string]]::new()

                foreach ($item in $executeResults) {
                    $resultStrings.Add("$item")
                }

                $resultString = [string]::Join("`n", $resultStrings);

                if ($resultString -imatch ('no [^\n]*package found')) {
                    return $null
                }

                return $resultString
            }

            throw "``$toExecute $params`` resulted in error (exit code: $LASTEXITCODE)"
        }

        if ($env:IsWindows -ieq 'true') {
            & refreshenv
        }

        return $this.ParseResults(
            $executeResults, $Command, $Install, $AllRepos, $Raw, $Describe, $Global, $Verbose)
    }

    <#
        .Description
        The `ParseResultItem` method may be overwridden in each `PackageManager` sub-class.

        This method adds parameters to the invocation to be executed.
    #>
    [Object[]]AddParameters([string]$Command, [Switch]$Global, [Object[]]$params) {
        return $params
    }

    <#
        .Description
        [Depracated] The `Invoke` method _should not_ be overwridden in each `PackageManager` sub-class.

        This overload of the `Invoke` method should not be used.
    #>
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
        [bool]$Exact = $false) {
        return $this.Invoke($Command, $Name, $SubCommand, `
                $Store, $Install, $AllRepos, $Raw, $Describe, $false, $Verbose, $Exact, `
            @())
    }

    <#
        .Description
        The `Invoke` method _should not_ be overwridden in each `PackageManager` sub-class.

        This overload of the `Invoke` method should be called to invoke an operation on the `PackageManager`.
    #>
    [Object]Invoke(
        [string]$Command = 'search',
        [string]$Name = $null,
        [string]$SubCommand = $null,
        [string]$Store = 'winget',
        [switch]$Install = $false,
        [switch]$AllRepos = $false,
        [switch]$Raw = $false,
        [switch]$Describe = $false,
        [switch]$Global = $false,
        [bool]$Verbose = $false,
        [bool]$Exact = $false,
        [Object[]]$OtherParameters = @()) {
        $itemName = $Name
        $itemCommand = $Command

        if ($Name -eq '' -and -not($Command -imatch 'list|upgrade')) {
            $itemName = $Command
            $itemCommand = 'search'
        }

        if ($Install) {
            $itemCommand = 'search'
        }

        $params = @()

        $Sudo = $this.UseSudo

        Switch -regex ($itemCommand) {
        ('^search|find') {
                $params += $this.Search
                if ($SubCommand.Trim().Length -gt 0) {
                    $params += $SubCommand.Trim()
                }
                $params += $itemName
                $Sudo = $Sudo -and $False
            }

        ('^install') {
                $params += $this.Install
                if ($SubCommand.Trim().Length -gt 0) {
                    $params += $SubCommand.Trim()
                }
                $params += $itemName
                $Sudo = $Sudo -and $True
            }

        ('^upgrade') {
                $params += $this.Upgrade
                if ($SubCommand.Trim().Length -gt 0) {
                    $params += $SubCommand.Trim()
                }
                $params += $itemName
                $Sudo = $Sudo -and $True
            }

        ('^update') {
                $params += $this.Update
                if ($SubCommand.Trim().Length -gt 0) {
                    $params += $SubCommand.Trim()
                }
                $params += $itemName
                $Sudo = $Sudo -and $True
            }

        ('^uninstall|remove') {
                $params += $this.Uninstall
                if ($SubCommand.Trim().Length -gt 0) {
                    $params += $SubCommand.Trim()
                }
                $params += $itemName
                $Sudo = $Sudo -and $True
            }

      ('^show|details|info') {
                $params += $this.Display
                if ($SubCommand.Trim().Length -gt 0) {
                    $params += $SubCommand.Trim()
                }
                $params += $itemName
                $Sudo = $Sudo -and $False
            }

      ('^list') {
                $params += $this.List
                if ($SubCommand.Trim().Length -gt 0) {
                    $params += $SubCommand.Trim()
                }
                if ($itemName) {
                    $params += $itemName
                }
                $Sudo = $Sudo -and $False
            }

            default {
                $params += $itemCommand
                if ($SubCommand.Trim().Length -gt 0) {
                    $params += $SubCommand.Trim()
                }
                if ($itemName) {
                    $params += $itemName
                }
            }
        }

        if (-not $params[0]) {
            throw "``$Command`` not supported for ``$($this.Repo)``"
        }

        if ($OtherParameters) {
            $params += $OtherParameters
        }

        $params = $this.AddParameters($itemCommand, $Global, $params)

        if ($Exact) {
            $Raw = $true
        }

        $results = $this.Execute($itemCommand, $params, $Install, $AllRepos, $Raw, $Describe, $Global, $Verbose, $Sudo)

        if (-not $results) {
            return "`n[$($this.Executable)] No results.`n"
        }

        if (-not $Exact) {
            return $results
        }

        if (-not $AllRepos) {
            if ($Install) {
                $params = $this.AddParameters($Command, $Global, @($this.Install, $itemName))
                switch ($this.UseSudo) {
          ($true) {
                        $results = & sudo $this.Command.Source $params 2>&1
                    }
                    default {
                        $results = & $this.Command.Source $params 2>&1
                    }
                }

                return $results
            }
            else {
                if ($Verbose) {
                    return ($results | Where-Object ID -EQ $itemName | Format-Table -Property Repo, Command, Line )
                }
                else {
                    return ($results | Where-Object ID -EQ $itemName | Format-Table -Property Repo, Command )
                }
            }
        }
        else {
            return $results | Where-Object ID -EQ $itemName
        }
    }
}

class AptManager : PackageManager {
    AptManager() : base(
        'apt', 'apt', 'search', 'install',
        'upgrade', 'update', @('list', '--installed'), 'remove', 'info', $true
    ) {
    }

    [Object[]]AddParameters([string]$Command, [Switch]$Global, [Object[]]$params) {
        if ($Command -imatch 'list|info') {
            return $params
        }

        return $params + '-y'
    }

    [ResultItem]ParseResultItem([string]$Line, [string]$Command, [Switch]$Global) {
        # golang-github-sahilm-fuzzy-dev/stable,oldstable,testing 0.1.0-1.1 all
        $regex = [Regex]::new('^([A-Za-z0-9_\-\.+]+)\/[A-Za-z0-9_\-\,]+\s+([A-Za-z0-9\.\-+]+)\s?')

        if ($regex.IsMatch($line)) {
            $id = $regex.Match($line).Groups[1].Value.Trim()
            $ver = $regex.Match($line).Groups[2].Value.Trim()
            $desc = $null
            $index = $line.IndexOf($id)
            $nme = $line.Substring(0, $index).Trim()
            $inst = ''
            switch -regex ($Command) {
                'search' {
                    $inst = "$($this.Install) $id=$ver"
                }
                'list' {
                    $inst = "$($this.Uninstall) $id"
                }
            }

            return [ResultItem]::new(
                "sudo $($this.Executable)", $id, $ver, $nme, $inst, $desc, $this, $Line
            )
        }

        return $null
    }
}

class HomebrewManager : PackageManager {
    [string]$Store = 'main'

    HomebrewManager() : base(
        'brew', 'brew', 'search', 'install',
        'upgrade', 'update', 'list', 'uninstall', 'info', $false
    ) {
    }

    [ResultItem]ParseResultItem([string]$Line, [string]$Command, [Switch]$Global) {
        # golang-github-sahilm-fuzzy-dev/stable,oldstable,testing 0.1.0-1.1 all
        $regex = [Regex]::new('^([A-Za-z0-9_\-]+@?(\d*))')

        if ($regex.IsMatch($line)) {
            $id = $regex.Match($line).Groups[1].Value.Trim()

            $ver = ''
            if ($regex.Match($line).Groups.Count -gt 2) {
                $ver = $regex.Match($line).Groups[2].Value.Trim()
            }

            $desc = $null
            $inst = ''
            switch -regex ($Command) {
                'search' {
                    if ($ver.Length -eq 0) {
                        $inst = "install $id"
                    }
                    else {
                        $inst = "install $id@$ver"
                    }
                }
                'list' {
                    $inst = "uninstall $id"
                }
            }

            return [ResultItem]::new(
                $this.Executable, $id, $ver, $id, $inst, $desc, $this, $Line
            )
        }

        return $null
    }
}

class SnapManager : PackageManager {

    SnapManager() : base(
        'snap', 'snap', 'find', 'install',
        'upgrade', 'refresh', 'list', 'remove', 'info', $true
    ) {
    }

    [ResultItem]ParseResultItem([string]$Line, [string]$Command, [Switch]$Global) {
        # golang-github-sahilm-fuzzy-dev/stable,oldstable,testing 0.1.0-1.1 all
        $regex = [Regex]::new('^(?!Name)([\w\d\-]+)\s+([\w\d\.\-+]+)\s+[\d\s]*\s*[^\s]*\s*[^\s]+\s+(.*)')

        if ($regex.IsMatch($line)) {
            $id = $regex.Match($line).Groups[1].Value.Trim()

            $ver = ''
            if ($regex.Match($line).Groups.Count -gt 2) {
                $ver = $regex.Match($line).Groups[2].Value.Trim()
            }

            $desc = $null
            if ($regex.Match($line).Groups.Count -gt 3) {
                $desc = $regex.Match($line).Groups[3].Value.Trim()
            }
            $inst = ''
            switch -regex ($Command) {
                'search' {
                    if ($ver.Length -eq 0) {
                        $inst = "install $id"
                    }
                    else {
                        $inst = "$($this.Install) $id"
                    }
                }
                'list' {
                    $inst = "$($this.Uninstall) $id"
                }
            }

            return [ResultItem]::new(
                "sudo $($this.Executable)", $id, $ver, $id, $inst, $desc, $this, $Line
            )
        }

        return $null
    }
}

class WinGetManager : PackageManager {
    [string]$Store = 'winget'
    [switch]$InteractiveParameter = $false

    WinGetManager([string]$S, [switch]$I) : base(
        'winget', 'winget', 'search', 'install',
        'upgrade', 'update', 'list', 'uninstall', 'show', $false
    ) {
        $this.Store = $s
        $this.InteractiveParameter = $i
    }

    [ResultItem]ParseResultItem([string]$Line, [string]$Command, [Switch]$Global) {
        $exp = '^.+\s+([a-zA-Z0-9\._\-]+|[a-zA-Z0-9]{12})\s+(\b|[\w\.\-]+|Unknown)\s+(?=Tag|msstore|winget)\b';
        $regex = [Regex]::new($exp)
        $id = $nme = $ver = $null
        switch -regex ($Command) {
            'list' { 
                $exp = '^([^\{]+)(\{[a-zA-Z0-9\-]+\})\s+([\w\.\-]+|Unknown)'; 
                $regex = [Regex]::new($exp)

                if ($regex.IsMatch($line)) {
                    $nme = $regex.Match($line).Groups[1].Value.Trim()
                    $id = $regex.Match($line).Groups[2].Value.Trim()
                    $ver = $regex.Match($line).Groups[3].Value.Trim()
                }
                else {
                    $exp = '^((?:[^\s]+\s)+)\s+([^\s]+)\s+([\w\.\-]+|Unknown)'; 
                    $regex = [Regex]::new($exp)
    
                    if ($regex.IsMatch($line)) {
                        $nme = $regex.Match($line).Groups[1].Value.Trim()
                        $id = $regex.Match($line).Groups[2].Value.Trim()
                        $ver = $regex.Match($line).Groups[3].Value.Trim()
                    }    
                }

                if($nme -ieq 'Name'){
                    $id = $nme = $ver = $null
                }
            }

            default {
                if ($regex.IsMatch($line)) {
                    $id = $regex.Match($line).Groups[1].Value.Trim()
                    $ver = $regex.Match($line).Groups[2].Value.Trim()
                    $index = $line.IndexOf($id)
                    $nme = $line.Substring(0, $index).Trim()
                }        
            }
        }

        if ($id) {
            $inst = ''
            $interactive = ''
            if ($this.InteractiveParameter.IsPresent -and
                $this.InteractiveParameter.ToBool()) {
                $interactive = '-i'
            }
            switch -regex ($Command) {
                'search' {
                    if ($ver -ne 'Unknown') {
                        $inst = "install $id --version $ver $interactive # $nme"
                    }
                    else {
                        $inst = "install $id -s msstore # $nme"
                    }
                }
                'list' {
                    $inst = "uninstall $id # $nme"
                }
            }

            return [ResultItem]::new(
                $this.Executable, $id, $ver, $nme, $inst, $null, $this, $Line
            )
        }
        return $null
    }
}

class ScoopManager : PackageManager {
    [string]$Store = 'main'

    ScoopManager([string]$S) : base(
        'scoop', 'scoop', 'search', 'install',
        'upgrade', 'update', 'list', 'uninstall', 'info', $false
    ) {
        $this.Store = $s
    }

    [ResultItem]ParseResultItem([string]$Line, [string]$Command, [Switch]$Global) {
        $json = ConvertFrom-Json $Line
        $ver = $json.version
        $nme = $json.name
        $inst = $Command
        switch -regex ($Command) {
            'search' {

                [string]$bucket = ''

                if ($this.Store) {
                    $bucket = "-bucket $($this.Store)"
                }

                switch ($line.Source.Length -gt 0) {
            ($True) {
                        $bucket = "-bucket $($json.Source)"
                    }
                    default {
                    }
                }

                if ($ver) {
                    $inst = "$($this.Install) $($nme)@$($ver) $bucket".Trim()
                }
                else {
                    $inst = "$($this.Install) $nme $bucket".Trim()
                }
            }
            'list' {
                $inst = "$($this.Uninstall) $nme"
            }
        }
        return [ResultItem]::new(
            $this.Executable, $nme, $ver, $nme, $inst, $null, $this, $Line
        )
    }
}

class ChocoManager : PackageManager {

    ChocoManager() : base(
        'choco', 'choco', 'search', 'install',
        'upgrade', 'update', 'list', 'uninstall', 'info', $true
    ) {
    }

    [Object[]]AddParameters([string]$Command, [Switch]$Global, [Object[]]$params) {
        return $params
    }

    [ResultItem]ParseResultItem([string]$Line, [string]$Command, [Switch]$Global) {
        if ($Line.Trim().IndexOf('packages installed.') -gt -1) {
            return $null
        }

        $index = $line.IndexOf('[Approved]')
        if (($Command -imatch 'search' -and $index -gt -1) -or
            -not($Command -imatch 'search')) {
            if ($index -gt -1) {
                $line = $line.Substring(0, $line.IndexOf('[Approved]')).Trim()
            }

            $nme = ''
            $ver = ''

            if ($Command -imatch 'list') {
                $regex = [Regex]::new('^(?!Chocolatey|\d)([\w_\-\.]+)\s([\w_\-\.]+)\z')

                if ($regex.IsMatch($line)) {
                    $nme = $regex.Match($line).Groups[1].Value.Trim()
                    $ver = $regex.Match($line).Groups[2].Value.Trim()
                }
            }
            else {
                $lastIndex = $line.LastIndexOf(' ')
                $nme = $line.Substring(0, $lastIndex).Trim()
                $ver = $line.Substring($lastIndex).Trim()
            }
            $inst = $Command
            switch -regex ($Command) {
                'search' {
                    $inst = "install $nme --version $ver -y"
                }
                'list' {
                    $inst = "uninstall $nme"
                }
            }
            if ($nme.Trim().Length -gt 0) {
                return [ResultItem]::new(
                    "sudo $($this.Executable)", $nme, $ver, $nme, $inst, $null, $this, $Line
                )
            }
        }

        return $null
    }
}

class NpmManager : PackageManager {

    NpmManager() : base(
        'npm', 'npm', 'search', 'install',
        'upgrade', 'update', 'list', 'uninstall', 'view', $false
    ) {
    }

    [Object[]]AddParameters([string]$Command, [Switch]$Global, [Object[]]$params) {
        if ($Command -imatch 'search|find|list') {
            $params += '--json'
        }

        if ($Global) {
            $params += '-g'
        }

        return $params
    }

    [ResultItem]ParseResultItem([string]$Line, [string]$Command, [Switch]$Global) {
        [Object]$json = $null

        try {
            $json = ConvertFrom-Json $Line -ErrorAction SilentlyContinue
        }
        catch {
        }

        if ($json) {
            $nme = $json.name
            $ver = $json.version
            $inst = $Command
            $description = $json.description
            switch -regex ($Command) {
                'search' {
                    $inst = "install $nme@$ver"
                }
                'list' {
                    $inst = "uninstall $nme"
                }
            }

            if ($Global -and $inst) {
                $inst = "$inst -g"
            }

            return [ResultItem]::new(
                $this.Executable, $nme, $ver, $nme, $inst, $description, $this, $Line
            )
        }

        return $null
    }
}

class NugetManager : PackageManager {

    NugetManager() : base(
        'nuget', 'nuget', 'search', 'install',
        'update', 'update', $null, 'uninstall', $null, $false
    ) {
    }

    [Object[]]AddParameters([string]$Command, [Switch]$Global, [Object[]]$params) {
        if ($Command -imatch 'details|info') {
            $params += '-Verbose'
        }

        return $params
    }

    [ResultItem]ParseResultItem([string]$Line, [string]$Command, [Switch]$Global) {
        $expression = '^>\s([@\w\d\-\/\.]+)\s\|\s([^\s]+)\s'
        # ^>\s([@\w\d\-\/\.]+)\s\|\s([^\s]+)\s
        if ($line -imatch $expression) {
            $regex = [Regex]::new($expression)
            $id = $regex.Match($line).Groups[1].Value.Trim()
            $ver = $regex.Match($line).Groups[2].Value.Trim()
            $nme = $id
            $inst = $Command
            switch -regex ($Command) {
                'search' {
                    $inst = "install $id -Version $ver -NonInteractive"
                }
                'list' {
                    $inst = "uninstall $id -NonInteractive"
                }
            }
            return [ResultItem]::new(
                $this.Executable, $nme, $ver, $nme, $inst, $null, $this, $Line
            )
        }

        return $null
    }
}

class DotnetManager : PackageManager {

    DotnetManager() : base(
        'dotnet', 'dotnet', $null, 'add',
        'update', $null, $null, 'remove', $null, $false
    ) {
    }

    [Object[]]AddParameters([string]$Command, [Switch]$Global, [Object[]]$params) {
        $params = @($params[0], 'package') + $params.Skip(1)

        return $params
    }

    [ResultItem]ParseResultItem([string]$Line, [string]$Command, [Switch]$Global) {
        $expression = '^>\s([@\w\d\-\/\.]+)\s\|\s([^\s]+)\s'
        # ^>\s([@\w\d\-\/\.]+)\s\|\s([^\s]+)\s
        if ($line -imatch $expression) {
            $regex = [Regex]::new($expression)
            $id = $regex.Match($line).Groups[1].Value.Trim()
            $ver = $regex.Match($line).Groups[2].Value.Trim()
            $nme = $id
            $inst = $Command
            switch -regex ($Command) {
                'search' {
                    $inst = "install $id -Version $ver -NonInteractive"
                }
                'list' {
                    $inst = "uninstall $id -NonInteractive"
                }
            }
            return [ResultItem]::new(
                $this.Executable, $nme, $ver, $nme, $inst, $null, $this, $Line
            )
        }

        return $null
    }
}

class DotnetToolManager : PackageManager {

    DotnetToolManager() : base(
        'dotnet', 'dotnet', 'search', 'install',
        $null, 'update', 'list', 'uninstall', $null, $false
    ) {
    }

    [Object[]]AddParameters([string]$Command, [Switch]$Global, [Object[]]$params) {
        $params = @('tool') + $params

        if ($Global -and -not ($Command -imatch 'search|find')) {
            $params += '-g'
        }

        return $params
    }

    [ResultItem]ParseResultItem([string]$Line, [string]$Command, [Switch]$Global) {
        $expression = '^(?!Package|\-)([@\w\d\-\/\.]+)[\t\s]+([^\s]+)'

        if ($line -imatch $expression) {
            $regex = [Regex]::new($expression)
            $id = $regex.Match($line).Groups[1].Value.Trim()
            $ver = $regex.Match($line).Groups[2].Value.Trim()
            $nme = $id
            $inst = $Command
            switch -regex ($Command) {
                'search' {
                    $inst = "tool $($this.Install) $id"
                }
                'list' {
                    $inst = "tool $($this.Uninstall) $id"
                }
            }

            if ($Global -and $inst) {
                $inst = "$inst -g"
            }

            return [ResultItem]::new(
                $this.Executable, $nme, $ver, $nme, $inst, $null, $this, $Line
            )
        }

        return $null
    }
}

function GetFirstItem([TypeInfo]$OfType, [IEnumerable]$Enum) {
    foreach ($currentItem in $Enum) {
        if ($currentItem -is $OfType) {
            $item = $currentItem
            break
        }
    }

    return $item
}

function Invoke-Any {
    [CmdletBinding(PositionalBinding = $True)]
    param(
        [Parameter(Position = 0)][string]$Command = 'search',
        [Parameter(Position = 1)][string]$Name = $null,
        [string]$SubCommand = $null,
        [string]$Store = $null,
        [switch]$Install = $false,
        [switch]$Interactive = $false,
        [switch]$AllRepos = $false,
        [switch]$Raw = $false,
        [switch]$Describe = $false,
        [Switch]$Exact = $false,
        [Switch]$VerboseSwitch = $false,
        [Switch]$Global = $false,
        [Object[]]$OtherParameters = $null,
        [string]$managerCode = $null
    )

    if ($managerCode) {
        $alias = $managerCode
    }
    else {
        $alias = $MyInvocation.Line.Split(' ')[0]
    }

    [PackageManager]$manager = $null

    Switch -regex ($alias) {
    ('ap') {
            $manager = [AptManager]::new()
        }
    ('br') {
            $manager = [HomebrewManager]::new()
        }
    ('sn') {
            $manager = [SnapManager]::new()
        }
    ('wg') {
            $manager = [WinGetManager]::new($Store, $Interactive)
        }
    ('scp') {
            $manager = [ScoopManager]::new($Store)
        }
    ('ch') {
            $manager = [ChocoManager]::new()
        }
    ('np') {
            $manager = [NpmManager]::new()
        }
    ('ng') {
            $manager = [NugetManager]::new()
        }
    ('dn') {
            $manager = [DotnetManager]::new()
        }
    ('dt') {
            $manager = [DotnetToolManager]::new()
        }
        default {
            throw "``$alias`` is not a known package manager."
        }
    }

    if ($manager.IsPresent) {
        $results = $manager.Invoke(
            $Command
            , $Name
            , $SubCommand
            , $Store
            , $Install
            , $AllRepos
            , $Raw
            , $Describe
            , $Global
            , $VerboseSwitch
            , $Exact
            , $OtherParameters
        )

        $results
    }
    else {
        Write-Information "$($this.Name) is not a command."
    }
}

Export-ModuleMember -Function Invoke-Any

Set-Alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [repos] NPM' -Name np -Value Invoke-Any -PassThru
Set-Alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [repos] NuGet' -Name ng -Value Invoke-Any -PassThru
Set-Alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [repos] Dotnet' -Name dn -Value Invoke-Any -PassThru
Set-Alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [repos] Dotnet Tool' -Name dt -Value Invoke-Any -PassThru

if ($env:IsWindows -eq 'false') {
    Write-Verbose "Using Linux Repos" -Verbose
    try {
        function Invoke-AllLinux {
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
                [Switch]$Exact = $false,
                [Switch]$Global = $false
            )

            if ($Name -eq '' -and -not($Command -imatch 'list|upgrade')) {
                $Name = $Command
                $Command = 'search'
            }

            if ($Install) {
                $Raw = $Install
            }

            $results = @()
            $aptResults = Invoke-Any $Command $Name -AllRepos -Raw:$Raw -Describe:$Describe -Exact:$Exact -Install:$Install -Global:$Global -managerCode 'ap'
            $brewResults = Invoke-Any $Command $Name -Subcommand $Subcommand -AllRepos -Raw:$Raw -Describe:$Describe -Exact:$Exact -Install:$Install -Global:$Global -managerCode 'br'
            $snapResults = Invoke-Any $Command $Name -Subcommand $Subcommand -AllRepos -Raw:$Raw -Describe:$Describe -Exact:$Exact -Install:$Install -Global:$Global -managerCode 'sn'

            $results = [List[Object]]::new()
            if ($aptResults -is [ResultItem[]] -or $aptResults -is [Object[]]) {
                $results.AddRange($aptResults)
            }
            else {
                $results.Add($aptResults)
            }

            if ($brewResults -is [ResultItem[]] -or $brewResults -is [Object[]]) {
                $results.AddRange($brewResults)
            }
            else {
                $results.Add($brewResults)
            }

            if ($snapResults -is [ResultItem[]] -or $snapResults -is [Object[]]) {
                $results.AddRange($snapResults)
            }
            else {
                $results.Add($snapResults)
            }

            if ($Command -imatch 'search|list' -and -not $Raw) {
                if ($VerboseSwitch) {
                    $results | Sort-Object -Property Repo, ID | Format-Table -Property Repo, Command, Line -GroupBy Repo -AutoSize
                }
                else {
                    $results | Sort-Object -Property ID | Format-Table -Property Repo, Command -AutoSize
                }
            }
            else {
                $results
            }

            if ($results -is [ResultItem]) {
                [List[ResultItem]]$list = [List[ResultItem]]::new()
                $list.Add($results)
                $results = $list
            }

            $type = [ResultItem]
            $firstItem = GetFirstItem -OfType $type -Enum $results

            if ($Install -and $firstItem) {
                $arguments = $firstItem.Command.Split(' ')
                & $firstItem.Repo $arguments
            }
        }

        Export-ModuleMember -Function Invoke-AllLinux

        Set-Alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [repos] apt' -Name ap -Value Invoke-Any -PassThru
        Set-Alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [repos] homebreq' -Name br -Value Invoke-Any -PassThru
        Set-Alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [repos] snap' -Name sn -Value Invoke-Any -PassThru
        Set-Alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [repos] All Repos' -Name repos -Value Invoke-AllLinux -PassThru

        return 'Repos aliases configured.'
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
    Write-Verbose 'Using Windows Repos' -Verbose

    try {
        function Invoke-All {
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
                [Switch]$Exact = $false,
                [Switch]$Global = $false
            )

            if ($Name -eq '' -and -not($Command -imatch 'list|upgrade')) {
                $Name = $Command
                $Command = 'search'
            }

            $results = @()
            $wingetResults = Invoke-Any $Command $Name -Store $Store -Interactive:$Interactive -AllRepos -Raw:$Raw -Describe:$Describe -Exact:$Exact -Install:$Install -Global:$Global -managerCode 'wg'
            $scoopResults = Invoke-Any $Command $Name -Subcommand $Subcommand -AllRepos -Raw:$Raw -Describe:$Describe -Exact:$Exact -Install:$Install -Global:$Global -managerCode 'scp'
            $chocoResults += Invoke-Any $Command $Name -Subcommand $Subcommand -AllRepos -Raw:$Raw -Describe:$Describe -Exact:$Exact -Install:$Install -Global:$Global -managerCode 'ch'

            $results = [List[Object]]::new()
            if ($wingetResults -is [ResultItem[]] -or $wingetResults -is [Object[]]) {
                $results.AddRange($wingetResults)
            }
            else {
                $results.Add($wingetResults)
            }

            if ($scoopResults -is [ResultItem[]] -or $scoopResults -is [Object[]]) {
                $results.AddRange($scoopResults)
            }
            else {
                $results.Add($scoopResults)
            }

            if ($chocoResults -is [ResultItem[]] -or $chocoResults -is [Object[]]) {
                $results.AddRange($chocoResults)
            }
            else {
                $results.Add($chocoResults)
            }

            if ($Command -imatch 'search|list' -and -not $Raw) {
                if ($VerboseSwitch) {
                    $results | Sort-Object -Property Repo, ID | Format-Table -Property Repo, Command, Line -GroupBy Repo -AutoSize
                }
                else {
                    $results | Sort-Object -Property ID | Format-Table -Property Repo, Command -AutoSize
                }
            }
            else {
                $results
            }

            if ($results -is [ResultItem]) {
                [List[ResultItem]]$list = [List[ResultItem]]::new()
                $list.Add($results)
                $results = $list
            }

            $type = [ResultItem]
            $firstItem = GetFirstItem -OfType $type -Enum $results

            if ($Install -and $firstItem) {
                $arguments = $firstItem.Command.Split(' ')
                & $firstItem.Repo $arguments
            }
        }

        Export-ModuleMember -Function Invoke-All

        Set-Alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [repos] WinGet' -Name wg -Value Invoke-Any -PassThru
        Set-Alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [repos] Scoop' -Name scp -Value Invoke-Any -PassThru
        Set-Alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [repos] Chocolatey' -Name ch -Value Invoke-Any -PassThru
        Set-Alias -Verbose:$Verbose -Scope Global -Description 'Snippets: [repos] All Repos' -Name repos -Value Invoke-All -PassThru

        return 'Repos aliases configured.'
    }
    catch {
        Write-Host $Error
    }
    finally {
        Write-Verbose '[repos.ps1] Leaving...' -Verbose:$Verbose
        $Verbose = $VerboseSwitch
    }
}
