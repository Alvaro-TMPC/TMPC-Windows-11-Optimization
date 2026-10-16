#Requires -Version 5.1
<#
.SYNOPSIS
    Helpers and in-memory doubles for the isolated TMPC test suite.
.DESCRIPTION
    Provides the extraction utilities, assertion helpers, result tracking and
    the in-memory doubles that replace every system I/O entry point of the
    optimizer (registry, filesystem, Authenticode, uninstaller execution and
    the OS/registry probe used by the preflight).

    This file is dot-sourced twice by the runner: once up front, and once again
    AFTER the production functions are extracted, so that the doubles take
    precedence over the production implementations while the extracted function
    names stay identical.

    Nothing in this file reads or writes the real registry, creates files,
    computes real signatures or starts processes.
.NOTES
    Solo lectura del sistema real. Windows PowerShell 5.1. Sin dependencias
    externas. Parte del baseline TMPC Windows 11 Optimization.
#>

# State is initialized only once: this file is dot-sourced twice by the runner
# (before and after extracting the production functions) and the second pass
# must not reset the in-memory store or the counters.
if ($null -eq (Get-Variable -Name TestLog -Scope Script -ErrorAction SilentlyContinue)) {
    $script:TestLog = New-Object System.Collections.Generic.List[string]
    $script:TestRegistry = @{}
    $script:TestWriteAttempts = New-Object System.Collections.Generic.List[string]
    $script:TestPathItems = @{}
    $script:TestUninstallerCalls = New-Object System.Collections.Generic.List[string]
    $script:TestFailRead = $false
    $script:TestFailWrite = $false
    $script:TestWriteDeniedButApplied = $false
    $script:TestCorruptAfterWrite = $false
    $script:TestSystemInfo = $null
    $script:TestSignature = $null
    $script:TestUninstallerExitCode = 0
    $script:TestResults = New-Object System.Collections.Generic.List[object]
    $script:TestCounters = @{ OK = 0; FAIL = 0 }
}

function Initialize-TMPCTestState {
    $script:TestLog.Clear()
    $script:TestRegistry = @{}
    $script:TestWriteAttempts.Clear()
    $script:TestPathItems = @{}
    $script:TestUninstallerCalls.Clear()
    $script:TestFailRead = $false
    $script:TestFailWrite = $false
    $script:TestWriteDeniedButApplied = $false
    $script:TestCorruptAfterWrite = $false
    $script:TestSystemInfo = $null
    $script:TestSignature = $null
    $script:TestUninstallerExitCode = 0
    $script:Completed = 0
    $script:Compliant = 0
    $script:Skipped = 0
    $script:Warnings = 0
    $script:Errors = 0
    $script:Mode = 'Full'
    $script:CanApplyUser = $true
    $script:OneDriveProtectionReady = $true
    $script:ProtectedOneDriveRoots = @()
}

# ---------------------------------------------------------------------------
# In-memory registry and filesystem manipulation
# ---------------------------------------------------------------------------

function Add-TestRegistryKey {
    param([string]$Path)
    if (-not $script:TestRegistry.ContainsKey($Path)) { $script:TestRegistry[$Path] = @{ Values = @{} } }
}

function Set-TestRegistryValue {
    param([string]$Path, [string]$Name, [Microsoft.Win32.RegistryValueKind]$Kind, $Value)
    Add-TestRegistryKey -Path $Path
    $script:TestRegistry[$Path].Values[$Name] = @{ Kind = $Kind; Value = $Value }
}

function Get-TestRegistryValue {
    param([string]$Path, [string]$Name)
    if (-not $script:TestRegistry.ContainsKey($Path)) { return $null }
    if (-not $script:TestRegistry[$Path].Values.ContainsKey($Name)) { return $null }
    return $script:TestRegistry[$Path].Values[$Name]
}

function Add-TestPathItem {
    param(
        [string]$Path,
        [System.IO.FileAttributes]$Attributes = [System.IO.FileAttributes]::Normal,
        [bool]$IsContainer = $true,
        [string]$FullName
    )
    if (-not $FullName) { $FullName = [IO.Path]::GetFullPath($Path) }
    $script:TestPathItems[$Path] = [pscustomobject]@{ FullName = $FullName; Attributes = $Attributes; PSIsContainer = $IsContainer }
}

function Add-TestPathChain {
    param(
        [string]$Path,
        [System.IO.FileAttributes]$LeafAttributes = [System.IO.FileAttributes]::Normal,
        [bool]$LeafIsContainer = $false
    )
    $current = [IO.Path]::GetFullPath($Path)
    $isLeaf = $true
    while ($current) {
        $attrs = if ($isLeaf) { $LeafAttributes } else { [System.IO.FileAttributes]::Directory }
        $container = if ($isLeaf) { $LeafIsContainer } else { $true }
        Add-TestPathItem -Path $current -Attributes $attrs -IsContainer $container
        $parent = Split-Path -Parent $current
        if (-not $parent -or $parent -eq $current) { break }
        $current = $parent
        $isLeaf = $false
    }
}

# ---------------------------------------------------------------------------
# In-memory doubles (production function names). Keep the signatures stable.
# ---------------------------------------------------------------------------

function Write-Log {
    param([string]$Message, [ValidateSet('INFO','SUCCESS','COMPLIANT','SKIPPED','WARNING','ERROR')][string]$Level = 'INFO')
    $null = $script:TestLog.Add(('[{0}] {1}' -f $Level, $Message))
    switch ($Level) {
        'SUCCESS' { $script:Completed++ }
        'COMPLIANT' { $script:Compliant++ }
        'SKIPPED' { $script:Skipped++ }
        'WARNING' { $script:Warnings++ }
        'ERROR' { $script:Errors++ }
    }
}

function Get-TMPCRegistryEntryState {
    param([string]$Path, [string]$Name)
    if ($script:TestFailRead) { throw ([System.UnauthorizedAccessException]::new('read denied by test double')) }
    if (-not $script:TestRegistry.ContainsKey($Path)) {
        return [pscustomobject]@{ PathExists = $false; ValueExists = $false; Kind = $null; Value = $null }
    }
    if (-not $Name) {
        return [pscustomobject]@{ PathExists = $true; ValueExists = $false; Kind = $null; Value = $null }
    }
    $entry = Get-TestRegistryValue -Path $Path -Name $Name
    if ($null -eq $entry) {
        return [pscustomobject]@{ PathExists = $true; ValueExists = $false; Kind = $null; Value = $null }
    }
    return [pscustomobject]@{ PathExists = $true; ValueExists = $true; Kind = $entry.Kind; Value = $entry.Value }
}

function Get-RegistryEntryState {
    # Doubles the embedded-XML variant so both engines share one store.
    param([string]$Path, [string]$Name)
    return Get-TMPCRegistryEntryState -Path $Path -Name $Name
}

function Remove-RegistryEntryIfPresent {
    # Doubles the embedded-XML variant removal helper with the in-memory store.
    param([string]$Path, [string]$Name)
    $state = Get-RegistryEntryState -Path $Path -Name $Name
    if (-not $state.PathExists) { return 'ALREADY_COMPLIANT' }
    if ($Name -and -not $state.ValueExists) { return 'ALREADY_COMPLIANT' }
    if (-not $script:TestRegistry.ContainsKey($Path)) { return 'ALREADY_COMPLIANT' }
    if ($Name) { $null = $script:TestRegistry[$Path].Values.Remove($Name) }
    else { $null = $script:TestRegistry.Remove($Path) }
    return 'APPLIED'
}

function Write-TMPCRegistryEntry {
    param([string]$Path, [string]$Name, [string]$Type, $Value, [bool]$PathExists)
    $null = $script:TestWriteAttempts.Add(('SET|{0}|{1}|{2}' -f $Path, $Name, $Type))
    if ($script:TestFailWrite -and -not $script:TestWriteDeniedButApplied) {
        throw ([System.UnauthorizedAccessException]::new('write denied by test double'))
    }
    $kind = switch ($Type) {
        'DWord' { [Microsoft.Win32.RegistryValueKind]::DWord }
        'String' { [Microsoft.Win32.RegistryValueKind]::String }
        'ExpandString' { [Microsoft.Win32.RegistryValueKind]::ExpandString }
        'Binary' { [Microsoft.Win32.RegistryValueKind]::Binary }
        default { throw 'Unsupported registry type.' }
    }
    if ($Type -eq 'DWord') { $stored = [int]$Value }
    elseif ($Type -eq 'Binary') { $stored = [byte[]]$Value }
    else { $stored = [string]$Value }
    if ($script:TestCorruptAfterWrite -and -not $script:TestFailWrite) {
        if ($Type -eq 'Binary') { $stored = [byte[]](1,2,3) }
        elseif ($Type -eq 'DWord') { $stored = 999 }
        else { $stored = 'corrupted-by-test' }
    }
    Set-TestRegistryValue -Path $Path -Name $Name -Kind $kind -Value $stored
    if ($script:TestFailWrite) {
        throw ([System.UnauthorizedAccessException]::new('write denied by test double'))
    }
}

function Remove-TMPCRegistryEntry {
    param([string]$Path, [string]$Name)
    $null = $script:TestWriteAttempts.Add(('REMOVE|{0}|{1}' -f $Path, $Name))
    if ($script:TestFailWrite) {
        throw ([System.UnauthorizedAccessException]::new('write denied by test double'))
    }
    if (-not $script:TestRegistry.ContainsKey($Path)) { return }
    if ($Name) { $null = $script:TestRegistry[$Path].Values.Remove($Name) }
    else { $null = $script:TestRegistry.Remove($Path) }
}

function Get-TMPCPathItem {
    param([string]$Path)
    if ($script:TestPathItems.ContainsKey($Path)) { return $script:TestPathItems[$Path] }
    throw (New-Object System.Management.Automation.ItemNotFoundException ("test path map has no item: {0}" -f $Path))
}

function Get-TMPCSignature {
    param([string]$Path)
    return $script:TestSignature
}

function Start-TMPCVerifiedUninstaller {
    param([string]$FilePath, [string]$Arguments)
    $null = $script:TestUninstallerCalls.Add(('{0}|{1}' -f $FilePath, $Arguments))
    return [pscustomobject]@{ ExitCode = $script:TestUninstallerExitCode }
}

function Get-TMPCSystemInfo {
    return $script:TestSystemInfo
}

function Set-TestSystemInfo {
    param([hashtable]$Overrides = @{})
    $defaults = [ordered]@{
        PSEdition       = 'Desktop'
        PSVersionMajor  = 5
        PSVersion       = '5.1.22621.1 (Desktop)'
        Is64BitProcess  = $true
        ProcessArch     = 'AMD64'
        MachineArch     = 'AMD64'
        ProductType     = 1
        Build           = 26300
        Ubr             = 9457
        DisplayVersion  = '26H2'
        EditionId       = 'Professional'
        ProductName     = 'Windows 11 Pro'
        IsAdministrator = $true
        IdentitySid     = 'S-1-5-21-1000-2000-3000-1001'
        DesktopVerified = $true
    }
    foreach ($key in $Overrides.Keys) { $defaults[$key] = $Overrides[$key] }
    $script:TestSystemInfo = [pscustomobject]$defaults
}

# ---------------------------------------------------------------------------
# Assertions and case runner
# ---------------------------------------------------------------------------

function Assert-TestTrue {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-TestEqual {
    param($Expected, $Actual, [string]$Message)
    if ($Expected -ne $Actual) {
        throw ('{0} (expected: {1}; actual: {2})' -f $Message, $Expected, $Actual)
    }
}

function Assert-TestLogContains {
    param([string]$Fragment)
    $found = @($script:TestLog | Where-Object { $_.Contains($Fragment) }).Count -gt 0
    if (-not $found) { throw ('operation log does not contain: {0}' -f $Fragment) }
}

function Assert-TestLogNotContains {
    param([string]$Fragment)
    $found = @($script:TestLog | Where-Object { $_.Contains($Fragment) }).Count -gt 0
    if ($found) { throw ('operation log unexpectedly contains: {0}' -f $Fragment) }
}

function Assert-TestThrows {
    param([scriptblock]$Body, [string]$Fragment, [string]$Message)
    $raised = $false
    $actual = ''
    try { & $Body } catch { $raised = $true; $actual = $_.Exception.Message }
    if (-not $raised) { throw ('expected an exception: {0}' -f $Message) }
    if ($Fragment -and -not $actual.Contains($Fragment)) {
        throw ('exception does not contain "{0}" ({1}); actual: {2}' -f $Fragment, $Message, $actual)
    }
}

function Invoke-TMPCTestCase {
    param([string]$Id, [string]$Name, [scriptblock]$Body)
    $failure = $null
    try {
        Initialize-TMPCTestState
        & $Body
    } catch {
        $failure = $_.Exception.Message
    }
    if ($failure) {
        $script:TestCounters.FAIL++
        Write-Host ('[FAIL] {0} {1}: {2}' -f $Id, $Name, $failure)
        $null = $script:TestResults.Add([pscustomobject]@{ Id = $Id; Name = $Name; Passed = $false; Detail = $failure })
    } else {
        $script:TestCounters.OK++
        Write-Host ('[ OK ] {0} {1}' -f $Id, $Name)
        $null = $script:TestResults.Add([pscustomobject]@{ Id = $Id; Name = $Name; Passed = $true; Detail = '' })
    }
}

# ---------------------------------------------------------------------------
# Function extraction (declarations only; nothing is executed by extraction)
# ---------------------------------------------------------------------------

function Get-TMPCFunctionText {
    param([string]$Text, [string[]]$Names)
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$tokens, [ref]$errors)
    if (@($errors).Count -gt 0) { throw ('source has parse errors: {0}' -f @($errors)[0].Message) }
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($name in $Names) {
        $nodes = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true))
        if ($nodes.Count -ne 1) { throw ('function is not unambiguous: {0} ({1} matches)' -f $name, $nodes.Count) }
        $null = $parts.Add($nodes[0].Extent.Text)
    }
    return ($parts -join [Environment]::NewLine)
}

function New-TMPCFunctionsScriptBlock {
    param([string]$Text, [string[]]$Names)
    # Returns one scriptblock with the requested function declarations. The
    # CALLER must dot-source it at script level so the definitions land in the
    # runner's scope; dot-sourcing inside a helper would define them in the
    # helper's local scope.
    $functionText = Get-TMPCFunctionText -Text $Text -Names $Names
    return [scriptblock]::Create($functionText)
}

function Get-TMPCHereStringBody {
    param([string]$Text, [string]$VariableName)
    $pattern = '(?m)^\s*\$' + [regex]::Escape($VariableName) + '\s*=\s*@''\r?\n(?<body>[\s\S]*?)^''@[ \t]*$'
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) { throw ('here-string not found: {0}' -f $VariableName) }
    return $match.Groups['body'].Value
}

# ---------------------------------------------------------------------------
# Inventory parity helpers (mirror the static validator contract)
# ---------------------------------------------------------------------------

function Get-TMPCInventoryTuples {
    param([string]$Text)
    $path = $null
    foreach ($line in ($Text -split '\r?\n')) {
        if (-not $line) { continue }
        if ($line -match '^\[(.+)\]$') { $path = $matches[1]; continue }
        if ($line -eq '!KEY') { "$path|REMOVEKEY" }
        elseif ($line.StartsWith('!')) { "$path|REMOVEVALUE|$($line.Substring(1))" }
        else { "$path|SET|$line" }
    }
}

function Get-TMPCXmlRegistryTuples {
    param([string]$SysText, [string]$Hive)
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($SysText, [ref]$tokens, [ref]$errors)
    if (@($errors).Count -gt 0) { throw ('embedded script has parse errors: {0}' -f @($errors)[0].Message) }
    $commands = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and
        $n.GetCommandName() -in @('Set-RegistryValue','Remove-RegistryValue','Remove-RegistryKey') }, $true))
    foreach ($command in $commands) {
        $args = @{}
        for ($i = 1; $i -lt $command.CommandElements.Count - 1; $i++) {
            $element = $command.CommandElements[$i]
            if ($element -is [System.Management.Automation.Language.CommandParameterAst]) {
                $args[$element.ParameterName] = $command.CommandElements[$i + 1]
            }
        }
        if (-not $args.ContainsKey('Path')) { continue }
        $pathAst = $args['Path']
        # The generic inventories are literal data. Special operations staged
        # with variables (for example the wallpaper block) are validated by
        # dedicated checks instead of the tuple comparison.
        if ($pathAst -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) { continue }
        $path = $pathAst.Value
        if (-not $path.StartsWith($Hive, [StringComparison]::OrdinalIgnoreCase)) { continue }
        switch ($command.GetCommandName()) {
            'Remove-RegistryKey' { "$path|REMOVEKEY" }
            'Remove-RegistryValue' { "$path|REMOVEVALUE|$($args['Name'].SafeGetValue())" }
            'Set-RegistryValue' {
                $name = $args['Name'].SafeGetValue()
                $type = $args['Type'].SafeGetValue()
                $value = $args['Value'].SafeGetValue()
                if ($type -eq 'Binary') { $value = (@($value | ForEach-Object { '{0:X2}' -f [byte]$_ }) -join ',') }
                "$path|SET|$name|$type|$value"
            }
        }
    }
}

function Get-TMPCEmbeddedInventory {
    param([string]$SysText, [string]$VariableName)
    $body = Get-TMPCHereStringBody -Text $SysText -VariableName $VariableName
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($body, [ref]$tokens, [ref]$errors)
    if (@($errors).Count -gt 0) { throw ('embedded inventory has parse errors: {0}' -f @($errors)[0].Message) }
    return @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $n.StringConstantType -eq 'SingleQuotedHereString' }, $true)[0].Value)
}

# ---------------------------------------------------------------------------
# Standalone inventory extraction (mirror the static validator contract)
# ---------------------------------------------------------------------------

function Get-TMPCStandaloneFunctions {
    param([string]$Text)
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$tokens, [ref]$errors)
    return @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true))
}

function Get-TMPCStandaloneInventoryTuples {
    param([string]$Text, [string]$FunctionName)
    $functions = @(Get-TMPCStandaloneFunctions -Text $Text | Where-Object { $_.Name -eq $FunctionName })
    if ($functions.Count -ne 1) { throw ('function is not unambiguous: {0}' -f $FunctionName) }
    $strings = @($functions[0].FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $n.StringConstantType -eq 'SingleQuotedHereString' }, $true))
    if ($strings.Count -ne 1) { throw ('inventory is not unambiguous: {0}' -f $FunctionName) }
    return @(Get-TMPCInventoryTuples -Text $strings[0].Value)
}
