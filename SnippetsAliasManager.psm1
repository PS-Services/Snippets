using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Management.Automation

$script:AliasSnippetPrefix = 'Snippets: [aliases]'
$script:AliasWrapperMarker = '# SnippetsAliasManager generated wrapper'
$script:AliasManagerState = @{
    ConfigPath = $null
    Entries    = [List[object]]::new()
    Applied    = @{}
}

function Get-SnippetsPropertyValue {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name,
        $Default = $null
    )

    if ($null -eq $InputObject) {
        return $Default
    }

    if ($InputObject -is [IDictionary]) {
        foreach ($key in $InputObject.Keys) {
            if ("$key" -ceq $Name) {
                return $InputObject[$key]
            }
        }
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($property) {
        return $property.Value
    }

    return $Default
}

function Install-YamlModuleIfMissing {
    param([switch]$VerboseSwitch = $false)

    try {
        $yamlModule = Get-Module -ListAvailable -Name 'powershell-yaml' -ErrorAction SilentlyContinue
        if (-not $yamlModule) {
            Write-Verbose "[SnippetsAliasManager] Installing powershell-yaml from PSGallery..." -Verbose:$VerboseSwitch
            Install-Module -Name 'powershell-yaml' -Scope CurrentUser -Force -AllowClobber -AcceptLicense -ErrorAction Stop
        }

        Import-Module 'powershell-yaml' -ErrorAction Stop -Verbose:$false
        return $true
    }
    catch {
        Write-Warning "[SnippetsAliasManager] powershell-yaml unavailable: $_"
        return $false
    }
}

function Get-SnippetsAliasesYamlPath {
    if ($env:SnippetsAliasesYaml) {
        return $env:SnippetsAliasesYaml
    }

    if ($env:Snippets) {
        return (Join-Path $env:Snippets -ChildPath 'aliases.yml')
    }

    return (Join-Path $PSScriptRoot -ChildPath 'aliases.yml')
}

function New-SnippetsAliasRecord {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][ValidateSet('alias', 'wrapper')][string]$Type,
        [string]$Target = '',
        $Command = $null,
        [string[]]$Parameters = @(),
        [string]$Description = '',
        [string]$Category = '',
        [string]$Scope = 'Global',
        [bool]$Enabled = $true
    )

    $record = [pscustomobject]@{
        Name        = $Name
        Type        = $Type
        Target      = $Target
        Command     = $Command
        Parameters  = @($Parameters)
        Description = $Description
        Category    = $Category
        Scope       = if ([string]::IsNullOrWhiteSpace($Scope)) { 'Global' } else { $Scope }
        Enabled     = $Enabled
        LoadStatus  = 'Pending'
        LoadMessage = ''
    }

    $record.PSObject.TypeNames.Insert(0, 'SnippetsAliasEntry')
    return $record
}

function New-SnippetsAliasEntry {
    [CmdletBinding(DefaultParameterSetName = 'ByValue')]
    param(
        [Parameter(Mandatory = $true, Position = 0)][string]$Name,
        [Parameter(ParameterSetName = 'ByValue', Mandatory = $true, Position = 1)][string]$Value,
        [Parameter(ParameterSetName = 'ByCommand', Mandatory = $true)][object]$Command,
        [ValidateSet('alias', 'wrapper')][string]$Type = 'alias',
        [string[]]$Parameters = @(),
        [string]$Description = '',
        [string]$Category = '',
        [string]$Scope = 'Global',
        [switch]$Disabled = $false
    )

    if ($Type -eq 'wrapper') {
        $wrapperCommand = if ($PSCmdlet.ParameterSetName -eq 'ByCommand') { $Command } else { $Value }
        return (New-SnippetsAliasRecord -Name $Name -Type $Type -Command $wrapperCommand -Parameters $Parameters -Description $Description -Category $Category -Scope $Scope -Enabled (-not $Disabled))
    }

    return (New-SnippetsAliasRecord -Name $Name -Type $Type -Target $Value -Description $Description -Category $Category -Scope $Scope -Enabled (-not $Disabled))
}

function ConvertTo-SnippetsParameterNames {
    param($Parameters)

    $names = [List[string]]::new()
    foreach ($item in @($Parameters)) {
        $name = if ($item -is [string]) {
            $item
        }
        else {
            [string](Get-SnippetsPropertyValue -InputObject $item -Name 'name' -Default '')
        }

        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }

        if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
            throw "Alias parameter [$name] is not a valid PowerShell parameter name."
        }

        if ($names -notcontains $name) {
            $names.Add($name)
        }
    }

    return @($names)
}

function Set-SnippetsAliasEntryStatus {
    param(
        [Parameter(Mandatory = $true)]$Entry,
        [Parameter(Mandatory = $true)][string]$Status,
        [string]$Message = ''
    )

    $Entry.LoadStatus = $Status
    $Entry.LoadMessage = $Message
}

function ConvertTo-SnippetsAliasRecord {
    param(
        [Parameter(Mandatory = $true)]$Entry,
        [int]$Index = 0
    )

    $name = [string](Get-SnippetsPropertyValue -InputObject $Entry -Name 'name' -Default '')
    if ([string]::IsNullOrWhiteSpace($name)) {
        throw "Alias entry [$Index] is missing 'name'."
    }

    $type = ([string](Get-SnippetsPropertyValue -InputObject $Entry -Name 'type' -Default 'alias')).Trim().ToLowerInvariant()
    if ($type -notin @('alias', 'wrapper')) {
        throw "Alias [$name] has unsupported type [$type]."
    }

    $target = [string](Get-SnippetsPropertyValue -InputObject $Entry -Name 'target' -Default '')
    $command = Get-SnippetsPropertyValue -InputObject $Entry -Name 'command' -Default $null
    $parameters = ConvertTo-SnippetsParameterNames -Parameters (Get-SnippetsPropertyValue -InputObject $Entry -Name 'parameters' -Default @())
    $description = [string](Get-SnippetsPropertyValue -InputObject $Entry -Name 'description' -Default '')
    $category = [string](Get-SnippetsPropertyValue -InputObject $Entry -Name 'category' -Default '')
    $scope = [string](Get-SnippetsPropertyValue -InputObject $Entry -Name 'scope' -Default 'Global')
    $enabled = Get-SnippetsPropertyValue -InputObject $Entry -Name 'enabled' -Default $true

    if ($type -eq 'alias' -and [string]::IsNullOrWhiteSpace($target)) {
        throw "Alias [$name] must define 'target'."
    }

    if ($type -eq 'wrapper') {
        if ($null -eq $command) {
            $command = $target
        }

        $hasCommand = $false
        if ($command -is [string]) {
            $hasCommand = -not [string]::IsNullOrWhiteSpace($command)
        }
        elseif ($command -is [IEnumerable]) {
            $commandItems = @($command)
            $hasCommand = $commandItems.Count -gt 0
        }

        if (-not $hasCommand) {
            throw "Wrapper alias [$name] must define 'command'."
        }
    }

    return (New-SnippetsAliasRecord `
            -Name $name `
            -Type $type `
            -Target $target `
            -Command $command `
            -Parameters $parameters `
            -Description $description `
            -Category $category `
            -Scope $scope `
            -Enabled ([bool]$enabled))
}

function ConvertTo-SnippetsPowerShellLiteral {
    param($Value)

    if ($null -eq $Value) {
        return '$null'
    }

    if ($Value -is [bool]) {
        return ($(if ($Value) { '$true' } else { '$false' }))
    }

    if ($Value -is [byte] -or
        $Value -is [int16] -or
        $Value -is [int32] -or
        $Value -is [int64] -or
        $Value -is [decimal] -or
        $Value -is [double] -or
        $Value -is [single]) {
        return ([System.Convert]::ToString($Value, [System.Globalization.CultureInfo]::InvariantCulture))
    }

    $text = [string]$Value
    return "'$($text.Replace("'", "''"))'"
}

function ConvertTo-SnippetsYamlScalar {
    param($Value)

    if ($null -eq $Value) {
        return "''"
    }

    if ($Value -is [bool]) {
        return ($(if ($Value) { 'true' } else { 'false' }))
    }

    $text = [string]$Value
    return "'$($text.Replace("'", "''"))'"
}

function ConvertTo-SnippetsCommandText {
    param($Command)

    if ($null -eq $Command) {
        return ''
    }

    if ($Command -is [string]) {
        return $Command.Trim()
    }

    if ($Command -is [IEnumerable]) {
        $parts = [List[string]]::new()
        foreach ($item in $Command) {
            $parts.Add((ConvertTo-SnippetsPowerShellLiteral -Value $item))
        }

        return ($parts -join ' ')
    }

    return ([string]$Command).Trim()
}

function ConvertTo-SnippetsAliasView {
    param([Parameter(Mandatory = $true)]$Entry)

    $definition = if ($Entry.Type -eq 'wrapper') {
        ConvertTo-SnippetsCommandText -Command $Entry.Command
    }
    else {
        $Entry.Target
    }

    return [pscustomobject]@{
        Name        = $Entry.Name
        Type        = $Entry.Type
        Definition  = $definition
        Parameters  = @($Entry.Parameters)
        Description = $Entry.Description
        Category    = $Entry.Category
        Scope       = $Entry.Scope
        Enabled     = $Entry.Enabled
        Status      = $Entry.LoadStatus
        Message     = $Entry.LoadMessage
        SourcePath  = $script:AliasManagerState.ConfigPath
    }
}

function Remove-SnippetsManagedCommand {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (Test-Path -Path "Alias:$Name") {
        try {
            Remove-Item -Path "Alias:$Name" -Force -ErrorAction Stop
        }
        catch {
            Write-Verbose "[SnippetsAliasManager] Failed to remove alias [$Name]: $_" -Verbose:$false
        }
    }

    if (Test-Path -Path "Function:$Name") {
        try {
            Remove-Item -Path "Function:$Name" -Force -ErrorAction Stop
        }
        catch {
            Write-Verbose "[SnippetsAliasManager] Failed to remove function [$Name]: $_" -Verbose:$false
        }
    }

    $null = $script:AliasManagerState.Applied.Remove($Name)
}

function Clear-SnippetsManagedCommands {
    foreach ($name in @($script:AliasManagerState.Applied.Keys)) {
        Remove-SnippetsManagedCommand -Name $name
    }

    $script:AliasManagerState.Applied = @{}
}

function Test-SnippetsManagedCommand {
    param([Parameter(Mandatory = $true)][string]$Name)

    $alias = Get-Alias -Name $Name -ErrorAction SilentlyContinue
    if ($alias -and $alias.Description -and $alias.Description.StartsWith($script:AliasSnippetPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    $functionInfo = Get-Command -Name $Name -CommandType Function -ErrorAction SilentlyContinue
    if ($functionInfo -and $functionInfo.ScriptBlock -and $functionInfo.ScriptBlock.ToString().Contains($script:AliasWrapperMarker)) {
        return $true
    }

    return $false
}

function Get-SnippetsAliasConfiguration {
    param([switch]$VerboseSwitch = $false)

    $path = Get-SnippetsAliasesYamlPath
    $entries = [List[object]]::new()
    $exists = Test-Path -Path $path

    if (-not $exists) {
        return [pscustomobject]@{
            Path          = $path
            Exists        = $false
            YamlAvailable = $true
            Aliases       = $entries
        }
    }

    if (-not (Install-YamlModuleIfMissing -VerboseSwitch:$VerboseSwitch)) {
        return [pscustomobject]@{
            Path          = $path
            Exists        = $true
            YamlAvailable = $false
            Aliases       = $entries
        }
    }

    $yaml = Get-Content -Path $path -Raw -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($yaml)) {
        return [pscustomobject]@{
            Path          = $path
            Exists        = $true
            YamlAvailable = $true
            Aliases       = $entries
        }
    }

    $config = ConvertFrom-Yaml -Yaml $yaml -ErrorAction Stop
    $aliasEntries = Get-SnippetsPropertyValue -InputObject $config -Name 'aliases' -Default @()

    $index = 0
    foreach ($entry in @($aliasEntries)) {
        $index++
        try {
            $entries.Add((ConvertTo-SnippetsAliasRecord -Entry $entry -Index $index))
        }
        catch {
            Write-Warning "[SnippetsAliasManager] Invalid alias entry [$index]: $_"
        }
    }

    return [pscustomobject]@{
        Path          = $path
        Exists        = $true
        YamlAvailable = $true
        Aliases       = $entries
    }
}

function Write-SnippetsAliasConfiguration {
    param(
        [Parameter(Mandatory = $true)][object[]]$Entries,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $directory = Split-Path -Path $Path -Parent
    if ($directory -and -not (Test-Path -Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $lines = [List[string]]::new()
    $lines.Add('# Snippets Alias Manager Configuration')
    $lines.Add('# Override this path by setting $env:SnippetsAliasesYaml before loading Snippets.')

    if ($Entries.Count -eq 0) {
        $lines.Add('aliases: []')
    }
    else {
        $lines.Add('aliases:')
        foreach ($entry in $Entries) {
            $lines.Add(("  - name: {0}" -f (ConvertTo-SnippetsYamlScalar -Value $entry.Name)))
            $lines.Add(("    type: {0}" -f (ConvertTo-SnippetsYamlScalar -Value $entry.Type)))

            if ($entry.Type -eq 'wrapper') {
                if ($entry.Command -is [IEnumerable] -and -not ($entry.Command -is [string])) {
                    $lines.Add('    command:')
                    foreach ($part in @($entry.Command)) {
                        $lines.Add(("      - {0}" -f (ConvertTo-SnippetsYamlScalar -Value $part)))
                    }
                }
                else {
                    $lines.Add(("    command: {0}" -f (ConvertTo-SnippetsYamlScalar -Value (ConvertTo-SnippetsCommandText -Command $entry.Command))))
                }

                if (@($entry.Parameters).Count -gt 0) {
                    $lines.Add('    parameters:')
                    foreach ($parameterName in @($entry.Parameters)) {
                        $lines.Add(("      - {0}" -f (ConvertTo-SnippetsYamlScalar -Value $parameterName)))
                    }
                }
            }
            else {
                $lines.Add(("    target: {0}" -f (ConvertTo-SnippetsYamlScalar -Value $entry.Target)))
            }

            $lines.Add(("    description: {0}" -f (ConvertTo-SnippetsYamlScalar -Value $entry.Description)))
            $lines.Add(("    category: {0}" -f (ConvertTo-SnippetsYamlScalar -Value $entry.Category)))
            $lines.Add(("    scope: {0}" -f (ConvertTo-SnippetsYamlScalar -Value $entry.Scope)))
            $lines.Add(("    enabled: {0}" -f (ConvertTo-SnippetsYamlScalar -Value $entry.Enabled)))
        }
    }

    Set-Content -Path $Path -Value $lines -Encoding UTF8
}

function Export-SnippetsAliases {
    [CmdletBinding()]
    param(
        [string]$Path = $(if ($script:AliasManagerState.ConfigPath) { $script:AliasManagerState.ConfigPath } else { Get-SnippetsAliasesYamlPath }),
        [switch]$VerboseSwitch = $false
    )

    Write-SnippetsAliasConfiguration -Entries @($script:AliasManagerState.Entries) -Path $Path
    $script:AliasManagerState.ConfigPath = $Path
    Write-Verbose "[SnippetsAliasManager] Saved aliases to [$Path]" -Verbose:$VerboseSwitch
    return "Saved aliases to [$Path]."
}

function Register-SnippetsAliasEntry {
    param(
        [Parameter(Mandatory = $true)]$Entry,
        [switch]$VerboseSwitch = $false
    )

    if (-not $Entry.Enabled) {
        Set-SnippetsAliasEntryStatus -Entry $Entry -Status 'Disabled' -Message 'Entry disabled.'
        return $false
    }

    $existing = Get-Command -Name $Entry.Name -ErrorAction SilentlyContinue
    if ($existing) {
        if (Test-SnippetsManagedCommand -Name $Entry.Name) {
            Remove-SnippetsManagedCommand -Name $Entry.Name
        }
        else {
            $message = "Skipped conflict with existing $($existing.CommandType) [$($Entry.Name)]."
            Write-Warning "[SnippetsAliasManager] $message"
            Set-SnippetsAliasEntryStatus -Entry $Entry -Status 'Skipped' -Message $message
            return $false
        }
    }

    if ($Entry.Type -eq 'alias') {
        $resolvedTarget = Get-Command -Name $Entry.Target -ErrorAction SilentlyContinue
        if (-not $resolvedTarget) {
            $message = "Skipped because target [$($Entry.Target)] is not available."
            Write-Warning "[SnippetsAliasManager] $message"
            Set-SnippetsAliasEntryStatus -Entry $Entry -Status 'Skipped' -Message $message
            return $false
        }

        $aliasDescription = if ([string]::IsNullOrWhiteSpace($Entry.Description)) {
            "$($script:AliasSnippetPrefix) -> $($Entry.Target)"
        }
        else {
            "$($script:AliasSnippetPrefix) $($Entry.Description)"
        }

        Set-Alias -Name $Entry.Name -Value $Entry.Target -Scope Global -Description $aliasDescription -Force
        $script:AliasManagerState.Applied[$Entry.Name] = [pscustomobject]@{
            Name = $Entry.Name
            Type = 'alias'
        }

        Set-SnippetsAliasEntryStatus -Entry $Entry -Status 'Applied' -Message "Alias points to [$($Entry.Target)]."
        Write-Verbose "[SnippetsAliasManager] Registered alias [$($Entry.Name)] -> [$($Entry.Target)]" -Verbose:$VerboseSwitch
        return $true
    }

    $commandLine = ConvertTo-SnippetsCommandText -Command $Entry.Command
    if ([string]::IsNullOrWhiteSpace($commandLine)) {
        $message = 'Skipped because command text is empty.'
        Write-Warning "[SnippetsAliasManager] $message"
        Set-SnippetsAliasEntryStatus -Entry $Entry -Status 'Skipped' -Message $message
        return $false
    }

    $functionLines = [List[string]]::new()
    $functionLines.Add('param(')

    $parameterNames = @($Entry.Parameters)
    for ($i = 0; $i -lt $parameterNames.Count; $i++) {
        $parameterName = $parameterNames[$i]
        $functionLines.Add('    [Parameter(Mandatory = $true)]')
        $functionLines.Add(("    [object]`$$parameterName,"))
    }

    $functionLines.Add('    [Parameter(ValueFromRemainingArguments = $true)]')
    $functionLines.Add('    [object[]]$Arguments')
    $functionLines.Add(')')
    $functionLines.Add($script:AliasWrapperMarker)
    $functionLines.Add('$ParameterValues = @{}')
    foreach ($parameterName in $parameterNames) {
        $functionLines.Add(("`$ParameterValues['{0}'] = `${0}" -f $parameterName))
    }
    $functionLines.Add(("Invoke-SnippetsAliasWrapper -Name {0} -ParameterValues `$ParameterValues -Arguments `$Arguments" -f (ConvertTo-SnippetsPowerShellLiteral -Value $Entry.Name)))

    $functionSource = $functionLines -join [Environment]::NewLine

    Set-Item -Path "Function:global:$($Entry.Name)" -Value $functionSource -Force
    $script:AliasManagerState.Applied[$Entry.Name] = [pscustomobject]@{
        Name = $Entry.Name
        Type = 'wrapper'
    }

    Set-SnippetsAliasEntryStatus -Entry $Entry -Status 'Applied' -Message "Wrapper executes [$commandLine]."
    Write-Verbose "[SnippetsAliasManager] Registered wrapper [$($Entry.Name)]" -Verbose:$VerboseSwitch
    return $true
}

function Invoke-SnippetsAliasWrapper {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [hashtable]$ParameterValues = @{},
        [object[]]$Arguments = @()
    )

    $entry = $script:AliasManagerState.Entries | Where-Object Name -EQ $Name | Select-Object -First 1
    if (-not $entry) {
        throw "Managed alias [$Name] is not defined."
    }

    $commandLine = ConvertTo-SnippetsCommandText -Command $entry.Command
    if ([string]::IsNullOrWhiteSpace($commandLine)) {
        throw "Managed alias [$Name] has no executable command text."
    }

    foreach ($parameterName in @($entry.Parameters)) {
        $replacement = '$null'
        if ($ParameterValues.ContainsKey($parameterName)) {
            $replacement = ConvertTo-SnippetsPowerShellLiteral -Value $ParameterValues[$parameterName]
        }

        $bracePattern = '\$\{' + [regex]::Escape($parameterName) + '\}'
        $commandLine = [regex]::Replace($commandLine, $bracePattern, { param($match) $replacement })

        $tokenPattern = '(?<![A-Za-z0-9_])\$' + [regex]::Escape($parameterName) + '\b'
        $commandLine = [regex]::Replace($commandLine, $tokenPattern, { param($match) $replacement })
    }

    $argumentText = @($Arguments | ForEach-Object { ConvertTo-SnippetsPowerShellLiteral -Value $_ }) -join ' '
    $invocation = if ([string]::IsNullOrWhiteSpace($argumentText)) {
        $commandLine
    }
    else {
        "$commandLine $argumentText"
    }

    Invoke-Expression -Command $invocation
}

function Import-SnippetsAliases {
    [CmdletBinding()]
    param([switch]$VerboseSwitch = $false)

    $config = Get-SnippetsAliasConfiguration -VerboseSwitch:$VerboseSwitch

    Clear-SnippetsManagedCommands

    $script:AliasManagerState.ConfigPath = $config.Path
    $script:AliasManagerState.Entries = [List[object]]::new()

    foreach ($entry in @($config.Aliases)) {
        $script:AliasManagerState.Entries.Add($entry)
    }

    if (-not $config.Exists) {
        return "No aliases.yml found at [$($config.Path)]."
    }

    if (-not $config.YamlAvailable) {
        return "Alias auto-loader disabled: powershell-yaml unavailable."
    }

    $applied = 0
    $skipped = 0
    $seen = [HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($entry in $script:AliasManagerState.Entries) {
        if (-not $seen.Add($entry.Name)) {
            $message = "Skipped duplicate alias name [$($entry.Name)]."
            Write-Warning "[SnippetsAliasManager] $message"
            Set-SnippetsAliasEntryStatus -Entry $entry -Status 'Skipped' -Message $message
            $skipped++
            continue
        }

        if (Register-SnippetsAliasEntry -Entry $entry -VerboseSwitch:$VerboseSwitch) {
            $applied++
        }
        else {
            $skipped++
        }
    }

    return "Alias auto-load complete: $applied applied, $skipped skipped."
}

function Update-SnippetsAliases {
    [CmdletBinding()]
    param([switch]$VerboseSwitch = $false)

    return (Import-SnippetsAliases -VerboseSwitch:$VerboseSwitch)
}

function Get-SnippetsAlias {
    [CmdletBinding()]
    param(
        [string]$Name = '',
        [switch]$Raw = $false
    )

    $entries = @($script:AliasManagerState.Entries)
    if (-not [string]::IsNullOrWhiteSpace($Name)) {
        $entries = $entries | Where-Object Name -Like $Name
    }

    if ($Raw) {
        return $entries | Sort-Object Name
    }

    return $entries | Sort-Object Name | ForEach-Object { ConvertTo-SnippetsAliasView -Entry $_ }
}

function Add-SnippetsAlias {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByFields')]
    param(
        [Parameter(ParameterSetName = 'ByFields', Mandatory = $true, Position = 0)][string]$Name,
        [Parameter(ParameterSetName = 'ByFields', Mandatory = $true, Position = 1)][string]$Value,
        [Parameter(ParameterSetName = 'ByInputObject', Mandatory = $true, ValueFromPipeline = $true, Position = 0)][psobject]$InputObject,
        [ValidateSet('alias', 'wrapper')][string]$Type = 'alias',
        [string[]]$Parameters = @(),
        [string]$Description = '',
        [string]$Category = '',
        [string]$Scope = 'Global',
        [switch]$Disabled = $false,
        [switch]$Force = $false,
        [switch]$VerboseSwitch = $false
    )

    process {
        if (-not $script:AliasManagerState.ConfigPath) {
            $null = Import-SnippetsAliases -VerboseSwitch:$VerboseSwitch
        }

        $record = if ($PSCmdlet.ParameterSetName -eq 'ByInputObject') {
            ConvertTo-SnippetsAliasRecord -Entry $InputObject
        }
        elseif ($Type -eq 'wrapper') {
            New-SnippetsAliasRecord -Name $Name -Type $Type -Command $Value -Parameters (ConvertTo-SnippetsParameterNames -Parameters $Parameters) -Description $Description -Category $Category -Scope $Scope -Enabled (-not $Disabled)
        }
        else {
            New-SnippetsAliasRecord -Name $Name -Type $Type -Target $Value -Description $Description -Category $Category -Scope $Scope -Enabled (-not $Disabled)
        }

        $existing = $script:AliasManagerState.Entries | Where-Object Name -EQ $record.Name | Select-Object -First 1
        if ($existing) {
            if (-not $Force) {
                $caption = 'Overwrite Snippets Alias'
                $question = "Alias [$($record.Name)] already exists in [$($script:AliasManagerState.ConfigPath)]. Overwrite it?"
                if (-not $PSCmdlet.ShouldContinue($question, $caption)) {
                    return "Skipped overwrite for alias [$($record.Name)]."
                }
            }

            $null = $script:AliasManagerState.Entries.Remove($existing)
        }

        if (-not $PSCmdlet.ShouldProcess($record.Name, 'Persist Snippets alias mapping')) {
            return
        }

        $script:AliasManagerState.Entries.Add($record)

        Export-SnippetsAliases | Out-Null
        $reloadResult = Update-SnippetsAliases -VerboseSwitch:$VerboseSwitch
        Write-Verbose "[SnippetsAliasManager] $reloadResult" -Verbose:$VerboseSwitch

        return (Get-SnippetsAlias -Name $record.Name)
    }
}

function Remove-SnippetsAlias {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [switch]$VerboseSwitch = $false
    )

    if (-not $script:AliasManagerState.ConfigPath) {
        $null = Import-SnippetsAliases -VerboseSwitch:$VerboseSwitch
    }

    $entry = $script:AliasManagerState.Entries | Where-Object Name -EQ $Name | Select-Object -First 1
    if (-not $entry) {
        throw "Alias [$Name] was not found in [$($script:AliasManagerState.ConfigPath)]."
    }

    $null = $script:AliasManagerState.Entries.Remove($entry)
    Export-SnippetsAliases | Out-Null
    Remove-SnippetsManagedCommand -Name $Name
    $reloadResult = Update-SnippetsAliases -VerboseSwitch:$VerboseSwitch
    Write-Verbose "[SnippetsAliasManager] $reloadResult" -Verbose:$VerboseSwitch

    return "Removed alias [$Name]."
}

function Invoke-AliasManager {
    [CmdletBinding(PositionalBinding = $true)]
    param(
        [Parameter(Position = 0)][string]$Command = 'list',
        [Parameter(Position = 1)][string]$Name = '',
        [Parameter(Position = 2)][string]$Value = '',
        [psobject]$InputObject = $null,
        [ValidateSet('alias', 'wrapper')][string]$Type = 'alias',
        [string[]]$Parameters = @(),
        [string]$Description = '',
        [string]$Category = '',
        [string]$Scope = 'Global',
        [switch]$Disabled = $false,
        [switch]$Force = $false,
        [switch]$VerboseSwitch = $false
    )

    switch -Regex ($Command.ToLowerInvariant()) {
        '^(list|ls)$' {
            return (Get-SnippetsAlias -Name $Name)
        }
        '^(show|get)$' {
            if ([string]::IsNullOrWhiteSpace($Name)) {
                throw 'Usage: als show <name>'
            }

            return (Get-SnippetsAlias -Name $Name)
        }
        '^(add|set)$' {
            if ($null -ne $InputObject) {
                return (Add-SnippetsAlias -InputObject $InputObject -Force:$Force -VerboseSwitch:$VerboseSwitch)
            }

            if ([string]::IsNullOrWhiteSpace($Name) -or [string]::IsNullOrWhiteSpace($Value)) {
                throw 'Usage: als add <name> <value> [-Type alias|wrapper] [-Parameters Name]'
            }

            return (Add-SnippetsAlias -Name $Name -Value $Value -Type $Type -Parameters $Parameters -Description $Description -Category $Category -Scope $Scope -Disabled:$Disabled -Force:$Force -VerboseSwitch:$VerboseSwitch)
        }
        '^(remove|rm|del)$' {
            if ([string]::IsNullOrWhiteSpace($Name)) {
                throw 'Usage: als remove <name>'
            }

            return (Remove-SnippetsAlias -Name $Name -VerboseSwitch:$VerboseSwitch)
        }
        '^(reload|reimport)$' {
            return (Update-SnippetsAliases -VerboseSwitch:$VerboseSwitch)
        }
        '^save$' {
            return (Export-SnippetsAliases -VerboseSwitch:$VerboseSwitch)
        }
        default {
            throw "Unsupported alias manager command [$Command]. Use list, show, add, remove, reload, or save."
        }
    }
}

Export-ModuleMember -Function `
    Add-SnippetsAlias, `
    Export-SnippetsAliases, `
    Get-SnippetsAlias, `
    Import-SnippetsAliases, `
    Invoke-AliasManager, `
    Invoke-SnippetsAliasWrapper, `
    New-SnippetsAliasEntry, `
    Update-SnippetsAliases, `
    Remove-SnippetsAlias
