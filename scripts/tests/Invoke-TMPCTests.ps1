#Requires -Version 5.1
<#
.SYNOPSIS
    Isolated automated tests for the TMPC optimizer (standalone + embedded XML).
.DESCRIPTION
    Drives the production functions against in-memory doubles so no real HKLM /
    HKCU key, file, signature or process is touched:

      - registry engine: DWord/String/Binary/ExpandString comparison, absence,
        wrong type, denied read/write, honest post-failure classification,
        verified removals and preserved binary masks;
      - layered compatibility preflight: accepted tested reference, untested
        Windows 11 builds, rejected Server/Windows 10/non-AMD64/PowerShell 7,
        Full elevation and HKCU deferral;
      - exit code mapping and the explicit restart gate;
      - OneNote: no arbitrary uninstall string and no process termination;
      - OneDrive: strict verified uninstaller, invalid signature, path not
        admitted, reparse points and protected sync roots never deleted;
      - XML/standalone inventory parity for the common blocks;
      - the static validator must pass on the repository (unless skipped).

    The production scripts write to disk: this runner only reads them. The whole
    suite is executed with Windows PowerShell 5.1.
.PARAMETER RepoRoot
    Repository root to test. Defaults to the parent of the scripts folder.
.PARAMETER SkipValidatorCase
    Skips the embedded static-validator run (used for mutation testing).
.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\tests\Invoke-TMPCTests.ps1
.NOTES
    No host registry, filesystem or process is modified. Sin dependencias
    externas. Parte del baseline TMPC Windows 11 Optimization.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot,
    [switch]$SkipValidatorCase
)

$ErrorActionPreference = 'Stop'

$script:TestsRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path -LiteralPath (Join-Path $script:TestsRoot '..\..')).ProviderPath
} else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).ProviderPath
}

. (Join-Path $script:TestsRoot 'TMPC.Tests.Helpers.ps1')

Write-Host ''
Write-Host 'TMPC isolated test suite (in-memory doubles; no host registry, filesystem or process is touched)'
Write-Host ('Repository root: {0}' -f $RepoRoot)
Write-Host ''

$standaloneText = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'Apply-TMPCOptimizations.ps1'))
$xmlText = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'autounattend.xml'))

$doc = New-Object System.Xml.XmlDocument
$doc.XmlResolver = $null
$doc.Load((Join-Path $RepoRoot 'autounattend.xml'))
$sysNode = @($doc.SelectNodes("//*[local-name()='File' and @path]") | Where-Object { $_.GetAttribute('path').EndsWith('SystemCustomizations.ps1', [System.StringComparison]::Ordinal) })
if ($sysNode.Count -ne 1) { throw 'SystemCustomizations.ps1: expected exactly one File node' }
$sysText = $sysNode[0].InnerText.Trim()
$bloatText = Get-TMPCHereStringBody -Text $sysText -VariableName 'bloatRemovalContent'
$oneDriveText = Get-TMPCHereStringBody -Text $sysText -VariableName 'oneDriveRemovalContent'

$registryFunctions = @(
    'Write-Log','Invoke-Operation','Get-TMPCRegistryEntryState','Write-TMPCRegistryEntry',
    'Remove-TMPCRegistryEntry','Test-TMPCRegistryStateEqual','Invoke-RegistryProfile',
    'Invoke-UserBinaryPreferences','Get-TMPCSystemInfo','Get-TMPCPreflightResult',
    'Get-TMPCExitCode','Test-TMPCRestartRequested'
)
$standaloneOneDriveFunctions = @(
    'Write-Log','Get-TMPCPathItem','Assert-NoReparsePath','Remove-OneDriveRemnant',
    'Get-TMPCSignature','Start-TMPCVerifiedUninstaller','Invoke-OneDriveUninstaller'
)
$xmlOneDriveFunctions = @(
    'Write-Log','Get-RegistryEntryState','Get-RegistryErrorReason','Remove-RegistryEntryIfPresent',
    'Get-TMPCPathItem','Assert-NoReparsePath','Remove-OneDriveRemnant','Get-TMPCSignature',
    'Start-TMPCVerifiedUninstaller','Invoke-OneDriveUninstaller'
)

# ---------------------------------------------------------------------------
# Phase 1: standalone registry engine
# ---------------------------------------------------------------------------

Write-Host '--- Phase 1: standalone registry engine (idempotent states) ---'

$productionFunctions = New-TMPCFunctionsScriptBlock -Text $standaloneText -Names $registryFunctions
. $productionFunctions
. (Join-Path $script:TestsRoot 'TMPC.Tests.Helpers.ps1')

Invoke-TMPCTestCase 'D01' 'DWord already correct: zero writes' {
    Set-TestRegistryValue -Path 'HKCU:\TMPC-Test' -Name 'Alpha' -Kind DWord -Value 0
    $inventory = @'
[HKCU:\TMPC-Test]
Alpha|DWord|0
'@
    Invoke-RegistryProfile -Text $inventory -Hive 'HKCU:'
    Assert-TestEqual 0 $script:TestWriteAttempts.Count 'no write attempt expected'
    Assert-TestLogContains 'ALREADY_COMPLIANT'
    Assert-TestEqual 0 $script:Errors 'no errors expected'
    Assert-TestEqual 1 $script:Compliant 'one compliant operation expected'
}

Invoke-TMPCTestCase 'D02' 'String and Binary already correct: zero writes' {
    Set-TestRegistryValue -Path 'HKCU:\TMPC-Test' -Name 'Mode' -Kind String -Value 'Deny'
    Set-TestRegistryValue -Path 'HKCU:\TMPC-Test' -Name 'Blob' -Kind Binary -Value ([byte[]](0x15,0x00,0x00,0x00))
    $inventory = @'
[HKCU:\TMPC-Test]
Mode|String|Deny
Blob|Binary|15,00,00,00
'@
    Invoke-RegistryProfile -Text $inventory -Hive 'HKCU:'
    Assert-TestEqual 0 $script:TestWriteAttempts.Count 'no write attempt expected'
    Assert-TestEqual 2 $script:Compliant 'two compliant operations expected'
    Assert-TestEqual 0 $script:Errors 'no errors expected'
}

Invoke-TMPCTestCase 'D03' 'Absent value: applied and verified' {
    Add-TestRegistryKey -Path 'HKCU:\TMPC-Test'
    $inventory = @'
[HKCU:\TMPC-Test]
Alpha|DWord|7
'@
    Invoke-RegistryProfile -Text $inventory -Hive 'HKCU:'
    Assert-TestEqual 1 $script:TestWriteAttempts.Count 'one write attempt expected'
    $entry = Get-TestRegistryValue -Path 'HKCU:\TMPC-Test' -Name 'Alpha'
    Assert-TestEqual ([Microsoft.Win32.RegistryValueKind]::DWord) $entry.Kind 'kind must be DWord'
    Assert-TestEqual 7 $entry.Value 'value must be verified as 7'
    Assert-TestLogContains 'APPLIED'
    Assert-TestEqual 1 $script:Completed 'applied operation expected'
    Assert-TestEqual 0 $script:Errors 'no errors expected'
}

Invoke-TMPCTestCase 'D04' 'Wrong type: corrected and verified' {
    Set-TestRegistryValue -Path 'HKCU:\TMPC-Test' -Name 'Alpha' -Kind String -Value '7'
    $inventory = @'
[HKCU:\TMPC-Test]
Alpha|DWord|7
'@
    Invoke-RegistryProfile -Text $inventory -Hive 'HKCU:'
    Assert-TestEqual 1 $script:TestWriteAttempts.Count 'one corrective write expected'
    $entry = Get-TestRegistryValue -Path 'HKCU:\TMPC-Test' -Name 'Alpha'
    Assert-TestEqual ([Microsoft.Win32.RegistryValueKind]::DWord) $entry.Kind 'kind must be corrected to DWord'
    Assert-TestEqual 7 $entry.Value 'value must be verified as 7'
}

Invoke-TMPCTestCase 'D05' 'Different value: minimal write' {
    Set-TestRegistryValue -Path 'HKCU:\TMPC-Test' -Name 'Alpha' -Kind DWord -Value 1
    $inventory = @'
[HKCU:\TMPC-Test]
Alpha|DWord|0
'@
    Invoke-RegistryProfile -Text $inventory -Hive 'HKCU:'
    Assert-TestEqual 1 $script:TestWriteAttempts.Count 'exactly one write expected'
    $entry = Get-TestRegistryValue -Path 'HKCU:\TMPC-Test' -Name 'Alpha'
    Assert-TestEqual 0 $entry.Value 'value must be corrected to 0'
}

Invoke-TMPCTestCase 'D06' 'Denied read: no blind write and a real error' {
    Set-TestRegistryValue -Path 'HKCU:\TMPC-Test' -Name 'Alpha' -Kind DWord -Value 0
    $script:TestFailRead = $true
    $inventory = @'
[HKCU:\TMPC-Test]
Alpha|DWord|0
'@
    Invoke-RegistryProfile -Text $inventory -Hive 'HKCU:'
    Assert-TestEqual 0 $script:TestWriteAttempts.Count 'no write may follow a denied read'
    Assert-TestEqual 1 $script:Errors 'a denied read must be a real error'
    Assert-TestLogContains 'READ_DENIED'
    Assert-TestLogNotContains ': APPLIED.'
}

Invoke-TMPCTestCase 'D07' 'Denied write: real error, nothing written' {
    Add-TestRegistryKey -Path 'HKCU:\TMPC-Test'
    $script:TestFailWrite = $true
    $inventory = @'
[HKCU:\TMPC-Test]
Alpha|DWord|0
'@
    Invoke-RegistryProfile -Text $inventory -Hive 'HKCU:'
    Assert-TestEqual 1 $script:TestWriteAttempts.Count 'write was attempted'
    Assert-TestEqual 1 $script:Errors 'a denied write must stay an error'
    Assert-TestLogContains 'WRITE_DENIED'
    $entry = Get-TestRegistryValue -Path 'HKCU:\TMPC-Test' -Name 'Alpha'
    Assert-TestTrue ($null -eq $entry) 'no value may be stored after a denied write'
}

Invoke-TMPCTestCase 'D08' 'Denied write with apparently correct state: honest ERROR' {
    Add-TestRegistryKey -Path 'HKCU:\TMPC-Test'
    $script:TestFailWrite = $true
    $script:TestWriteDeniedButApplied = $true
    $inventory = @'
[HKCU:\TMPC-Test]
Alpha|DWord|0
'@
    Invoke-RegistryProfile -Text $inventory -Hive 'HKCU:'
    Assert-TestEqual 1 $script:Errors 'the refused write must stay an error'
    Assert-TestLogContains 'WRITE_DENIED'
    Assert-TestLogContains 'post-failure verification found the expected state'
    $entry = Get-TestRegistryValue -Path 'HKCU:\TMPC-Test' -Name 'Alpha'
    Assert-TestEqual 0 $entry.Value 'the observed state is recorded honestly'
}

Invoke-TMPCTestCase 'D09' 'Value removals: absent is compliant, present is verified' {
    Add-TestRegistryKey -Path 'HKCU:\TMPC-Test'
    $absent = @'
[HKCU:\TMPC-Test]
!Gone
'@
    Invoke-RegistryProfile -Text $absent -Hive 'HKCU:'
    Assert-TestEqual 0 $script:TestWriteAttempts.Count 'absent value removal writes nothing'
    Assert-TestLogContains 'ALREADY_COMPLIANT'

    Set-TestRegistryValue -Path 'HKCU:\TMPC-Test' -Name 'Gone2' -Kind String -Value 'x'
    $present = @'
[HKCU:\TMPC-Test]
!Gone2
'@
    Invoke-RegistryProfile -Text $present -Hive 'HKCU:'
    Assert-TestEqual 1 $script:TestWriteAttempts.Count 'present value removal performs one removal'
    $entry = Get-TestRegistryValue -Path 'HKCU:\TMPC-Test' -Name 'Gone2'
    Assert-TestTrue ($null -eq $entry) 'value must be removed and verified'
    Assert-TestLogContains 'APPLIED'
    Assert-TestEqual 0 $script:Errors 'no errors expected'
}

Invoke-TMPCTestCase 'D10' 'Key removals: absent is compliant, present is verified' {
    $absent = @'
[HKCU:\TMPC-Missing]
!KEY
'@
    Invoke-RegistryProfile -Text $absent -Hive 'HKCU:'
    Assert-TestEqual 0 $script:TestWriteAttempts.Count 'absent key removal writes nothing'
    Assert-TestLogContains 'ALREADY_COMPLIANT'

    Add-TestRegistryKey -Path 'HKCU:\TMPC-Key'
    Set-TestRegistryValue -Path 'HKCU:\TMPC-Key' -Name 'Value' -Kind DWord -Value 1
    $present = @'
[HKCU:\TMPC-Key]
!KEY
'@
    Invoke-RegistryProfile -Text $present -Hive 'HKCU:'
    Assert-TestEqual 1 $script:TestWriteAttempts.Count 'present key removal performs one removal'
    Assert-TestTrue (-not $script:TestRegistry.ContainsKey('HKCU:\TMPC-Key')) 'key must be removed and verified'
    Assert-TestEqual 0 $script:Errors 'no errors expected'
}

Invoke-TMPCTestCase 'D11' 'Binary preferences: unrelated bits preserved and idempotent' {
    Set-TestRegistryValue -Path 'HKCU:\Control Panel\Desktop' -Name 'UserPreferencesMask' -Kind Binary -Value ([byte[]](0x03,0xFF,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00))
    Invoke-UserBinaryPreferences
    $entry = Get-TestRegistryValue -Path 'HKCU:\Control Panel\Desktop' -Name 'UserPreferencesMask'
    Assert-TestEqual ([Microsoft.Win32.RegistryValueKind]::Binary) $entry.Kind 'binary kind expected'
    $bytes = [byte[]]$entry.Value
    Assert-TestEqual 12 $bytes.Length 'blob length preserved'
    Assert-TestEqual 0x01 $bytes[0] 'masked bit cleared; bit 0x01 preserved'
    Assert-TestEqual 0xD3 $bytes[1] 'only the three masked bits cleared (0x2C)'
    Assert-TestEqual 0xFB $bytes[2] 'only the masked bit cleared'
    Assert-TestEqual 0x00 $bytes[3] 'unaffected byte preserved'

    $before = @($script:TestWriteAttempts | Where-Object { $_.Contains('UserPreferencesMask') }).Count
    Invoke-UserBinaryPreferences
    $after = @($script:TestWriteAttempts | Where-Object { $_.Contains('UserPreferencesMask') }).Count
    Assert-TestEqual $before $after 'second run must not rewrite compliant binary preferences'
    Assert-TestEqual 0 $script:Errors 'no errors expected'
}

Invoke-TMPCTestCase 'D12' 'Post-write verification failure is an error' {
    Add-TestRegistryKey -Path 'HKCU:\TMPC-Test'
    $script:TestCorruptAfterWrite = $true
    $inventory = @'
[HKCU:\TMPC-Test]
Alpha|DWord|5
'@
    Invoke-RegistryProfile -Text $inventory -Hive 'HKCU:'
    Assert-TestEqual 1 $script:Errors 'verification failure must be a real error'
    Assert-TestLogContains 'VERIFY_FAILED'
    Assert-TestLogNotContains ': APPLIED.'
}

Invoke-TMPCTestCase 'D27' 'Operation protocol: skipped, compliant and applied states distinguished' {
    Invoke-Operation 'probe skipped' { return 'SKIPPED_NOT_APPLICABLE' }
    Invoke-Operation 'probe compliant' { return 'ALREADY_COMPLIANT' }
    Invoke-Operation 'probe applied' { }
    Assert-TestLogContains 'probe skipped: SKIPPED_NOT_APPLICABLE'
    Assert-TestLogContains 'probe compliant: ALREADY_COMPLIANT'
    Assert-TestLogContains 'probe applied: APPLIED'
    Assert-TestEqual 1 $script:Skipped 'skipped counter'
    Assert-TestEqual 1 $script:Compliant 'compliant counter'
    Assert-TestEqual 1 $script:Completed 'applied counter'
    Assert-TestEqual 0 $script:Errors 'no errors expected'
}

# ---------------------------------------------------------------------------
# Phase 2: layered compatibility preflight
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '--- Phase 2: layered compatibility preflight ---'

Invoke-TMPCTestCase 'D13' 'Preflight: tested 26H2 reference accepted' {
    Set-TestSystemInfo @{}
    $pre = Get-TMPCPreflightResult -UserOnly:$false -Restart:$false -NetFx3Source $null
    Assert-TestTrue $pre.Ok 'the tested reference must be accepted'
    Assert-TestTrue $pre.TestedReference 'tested reference flag'
    Assert-TestTrue $pre.CanApplyUser 'desktop identity verified'
    Assert-TestTrue ($pre.Summary.Contains('TESTED_ON')) 'summary records TESTED_ON'
    Assert-TestTrue (-not $pre.Summary.Contains('S-1-5-21')) 'summary must not contain the account SID'
}

Invoke-TMPCTestCase 'D14' 'Preflight: future Windows 11 build accepted as NOT_RUNTIME_TESTED' {
    Set-TestSystemInfo @{ Build = 27000; Ubr = 1; DisplayVersion = '27H1' }
    $pre = Get-TMPCPreflightResult -UserOnly:$false -Restart:$false -NetFx3Source $null
    Assert-TestTrue $pre.Ok 'a future client Windows 11 build must not be rejected'
    Assert-TestTrue (-not $pre.TestedReference) 'it is not the tested reference'
    Assert-TestTrue ($pre.UntestedNote.Contains('NOT_RUNTIME_TESTED')) 'NOT_RUNTIME_TESTED is recorded'
}

Invoke-TMPCTestCase 'D15' 'Preflight: Windows Server rejected' {
    Set-TestSystemInfo @{ ProductType = 2 }
    $pre = Get-TMPCPreflightResult -UserOnly:$false -Restart:$false -NetFx3Source $null
    Assert-TestTrue (-not $pre.Ok) 'Server must be rejected'
    Assert-TestTrue ($pre.Message.Contains('client')) 'rejection explains the client requirement'
}

Invoke-TMPCTestCase 'D16' 'Preflight: Windows 10 rejected' {
    Set-TestSystemInfo @{ Build = 19045; DisplayVersion = '22H2' }
    $pre = Get-TMPCPreflightResult -UserOnly:$false -Restart:$false -NetFx3Source $null
    Assert-TestTrue (-not $pre.Ok) 'Windows 10 must be rejected'
    Assert-TestTrue ($pre.Message.Contains('Windows 11')) 'rejection explains the Windows 11 requirement'
}

Invoke-TMPCTestCase 'D17' 'Preflight: non-AMD64 and 32-bit rejected' {
    Set-TestSystemInfo @{ MachineArch = 'ARM64' }
    $arm = Get-TMPCPreflightResult -UserOnly:$false -Restart:$false -NetFx3Source $null
    Assert-TestTrue (-not $arm.Ok) 'ARM64 must be rejected'
    Assert-TestTrue ($arm.Message.Contains('AMD64')) 'rejection explains the AMD64 requirement'

    Set-TestSystemInfo @{ Is64BitProcess = $false; ProcessArch = 'x86' }
    $x86 = Get-TMPCPreflightResult -UserOnly:$false -Restart:$false -NetFx3Source $null
    Assert-TestTrue (-not $x86.Ok) '32-bit PowerShell must be rejected'
}

Invoke-TMPCTestCase 'D18' 'Preflight: PowerShell 7 / Core rejected' {
    Set-TestSystemInfo @{ PSEdition = 'Core'; PSVersionMajor = 7; PSVersion = '7.4.0 (Core)' }
    $pre = Get-TMPCPreflightResult -UserOnly:$false -Restart:$false -NetFx3Source $null
    Assert-TestTrue (-not $pre.Ok) 'PowerShell 7 must be rejected'
    Assert-TestTrue ($pre.Message.Contains('PowerShell 5.1')) 'rejection explains the PowerShell requirement'
}

Invoke-TMPCTestCase 'D19' 'Preflight: Full requires elevation; UserOnly keeps its contract' {
    Set-TestSystemInfo @{ IsAdministrator = $false }
    $full = Get-TMPCPreflightResult -UserOnly:$false -Restart:$false -NetFx3Source $null
    Assert-TestTrue (-not $full.Ok) 'Full without elevation must be rejected'
    Assert-TestTrue ($full.Message.Contains('administrator')) 'rejection explains the elevation requirement'

    $userOnly = Get-TMPCPreflightResult -UserOnly:$true -Restart:$false -NetFx3Source $null
    Assert-TestTrue $userOnly.Ok 'UserOnly needs no elevation'
    Assert-TestTrue $userOnly.CanApplyUser 'UserOnly applies to the executing account'

    $invalid = Get-TMPCPreflightResult -UserOnly:$true -Restart:$true -NetFx3Source $null
    Assert-TestTrue (-not $invalid.Ok) 'UserOnly must reject Restart'
    Assert-TestTrue ($invalid.Message.Contains('UserOnly does not accept')) 'rejection explains the parameter contract'
}

Invoke-TMPCTestCase 'D20' 'Preflight: different desktop identity defers HKCU safely' {
    Set-TestSystemInfo @{ DesktopVerified = $false }
    $full = Get-TMPCPreflightResult -UserOnly:$false -Restart:$false -NetFx3Source $null
    Assert-TestTrue $full.Ok 'Full is accepted but HKCU must be deferred'
    Assert-TestTrue (-not $full.CanApplyUser) 'HKCU must be deferred'
    Assert-TestEqual 3 (Get-TMPCExitCode -Errors 0 -UserDeferred (-not $full.CanApplyUser)) 'deferred HKCU maps to exit code 3'
}

Invoke-TMPCTestCase 'D21' 'Exit codes: 0/1/3 mapping preserved' {
    Assert-TestEqual 0 (Get-TMPCExitCode -Errors 0 -UserDeferred $false) 'clean run'
    Assert-TestEqual 1 (Get-TMPCExitCode -Errors 1 -UserDeferred $false) 'error run'
    Assert-TestEqual 3 (Get-TMPCExitCode -Errors 0 -UserDeferred $true) 'deferred user phase'
    Assert-TestEqual 1 (Get-TMPCExitCode -Errors 2 -UserDeferred $true) 'errors win over deferral'
}

Invoke-TMPCTestCase 'D22' 'Restart gate: never with errors, only explicitly' {
    Assert-TestTrue (Test-TMPCRestartRequested -RestartRequested $true -ExitCode 0) 'explicit restart on success'
    Assert-TestTrue (-not (Test-TMPCRestartRequested -RestartRequested $true -ExitCode 1)) 'no restart with errors'
    Assert-TestTrue (-not (Test-TMPCRestartRequested -RestartRequested $true -ExitCode 3)) 'no restart on deferral'
    Assert-TestTrue (-not (Test-TMPCRestartRequested -RestartRequested $false -ExitCode 0)) 'no restart without the switch'
}

# ---------------------------------------------------------------------------
# Phase 3: OneNote hardening (structural)
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '--- Phase 3: OneNote hardening ---'

Invoke-TMPCTestCase 'D23' 'OneNote: no arbitrary uninstall string, no process termination' {
    $tokens = $null; $errors = $null
    $bloatAst = [System.Management.Automation.Language.Parser]::ParseInput($bloatText, [ref]$tokens, [ref]$errors)
    Assert-TestEqual 0 @($errors).Count 'embedded bloat script must parse'
    $commandNames = @($bloatAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() })
    Assert-TestTrue (-not ($commandNames -contains 'Stop-Process')) 'no forced process termination in the bloat script'
    Assert-TestTrue (-not ($bloatText.Contains('$uninstallString'))) 'no uninstall-string variable is used'
    Assert-TestTrue ($bloatText.Contains('desktop uninstall deferred; no uninstall string is executed')) 'deferral is explicit'
    Assert-TestTrue ($bloatText.Contains("'OneNote'")) 'the OneNote target is preserved'

    $standaloneBloat = Get-TMPCFunctionText -Text $standaloneText -Names @('Invoke-BloatRemoval')
    $sbTokens = $null; $sbErrors = $null
    $sbAst = [System.Management.Automation.Language.Parser]::ParseInput($standaloneBloat, [ref]$sbTokens, [ref]$sbErrors)
    $sbCommands = @($sbAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object { $_.GetCommandName() })
    Assert-TestTrue (-not ($sbCommands -contains 'Stop-Process')) 'standalone keeps no forced termination'
    Assert-TestTrue ($standaloneBloat.Contains('desktop special uninstall deferred')) 'standalone defers the OneNote desktop uninstaller'
    Assert-TestTrue ($standaloneBloat.Contains("'OneNote'")) 'standalone keeps the OneNote target'
}

# ---------------------------------------------------------------------------
# Phase 4: OneDrive safety (standalone reference and embedded XML variant)
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '--- Phase 4: OneDrive safety ---'

$productionFunctions = New-TMPCFunctionsScriptBlock -Text $standaloneText -Names $standaloneOneDriveFunctions
. $productionFunctions
. (Join-Path $script:TestsRoot 'TMPC.Tests.Helpers.ps1')

Invoke-TMPCTestCase 'D24a' 'Standalone OneDrive: unrecognized uninstall form never runs' {
    Set-TestRegistryValue -Path 'HKCU:\TMPC-OD' -Name 'UninstallString' -Kind String -Value 'C:\Temp\weird.exe /remove-everything'
    $result = Invoke-OneDriveUninstaller -RegistryPath 'HKCU:\TMPC-OD'
    Assert-TestTrue (-not $result) 'unrecognized command must not run'
    Assert-TestEqual 0 $script:TestUninstallerCalls.Count 'nothing may be executed'
    Assert-TestLogContains 'not a recognized safe form'
}

Invoke-TMPCTestCase 'D24b' 'Standalone OneDrive: machine scope without allusers is deferred' {
    Set-TestRegistryValue -Path 'HKCU:\TMPC-OD' -Name 'UninstallString' -Kind String -Value '"C:\Program Files\Microsoft OneDrive\OneDriveSetup.exe" /uninstall'
    $result = Invoke-OneDriveUninstaller -RegistryPath 'HKCU:\TMPC-OD' -Machine
    Assert-TestTrue (-not $result) 'wrong-scope machine uninstall must be deferred'
    Assert-TestEqual 0 $script:TestUninstallerCalls.Count 'nothing may be executed'
    Assert-TestLogContains 'lacks allusers scope'
}

Invoke-TMPCTestCase 'D24c' 'Standalone OneDrive: path outside known locations never runs' {
    Set-TestRegistryValue -Path 'HKCU:\TMPC-OD' -Name 'UninstallString' -Kind String -Value '"C:\Temp\OneDriveSetup.exe" /uninstall /allusers'
    Assert-TestThrows { Invoke-OneDriveUninstaller -RegistryPath 'HKCU:\TMPC-OD' -Machine } 'outside known software locations' 'untrusted path'
    Assert-TestEqual 0 $script:TestUninstallerCalls.Count 'nothing may be executed'
}

Invoke-TMPCTestCase 'D24d' 'Standalone OneDrive: signature and signer verified before execution' {
    $exe = Join-Path $env:ProgramFiles 'Microsoft OneDrive\OneDriveSetup.exe'
    Add-TestPathChain -Path $exe
    Set-TestRegistryValue -Path 'HKCU:\TMPC-OD' -Name 'UninstallString' -Kind String -Value ('"' + $exe + '" /uninstall /allusers')

    $script:TestSignature = [pscustomobject]@{ Status = 'NotSigned'; SignerCertificate = $null }
    Assert-TestThrows { Invoke-OneDriveUninstaller -RegistryPath 'HKCU:\TMPC-OD' -Machine } 'signature not verified' 'invalid signature'
    Assert-TestEqual 0 $script:TestUninstallerCalls.Count 'no execution with an unverified signature'

    $script:TestSignature = [pscustomobject]@{ Status = 'Valid'; SignerCertificate = [pscustomobject]@{ Subject = 'CN=Fake Vendor, O=Fake Corp, C=XX' } }
    Assert-TestThrows { Invoke-OneDriveUninstaller -RegistryPath 'HKCU:\TMPC-OD' -Machine } 'signature not verified' 'wrong signer'
    Assert-TestEqual 0 $script:TestUninstallerCalls.Count 'no execution with a foreign signer'

    $script:TestSignature = [pscustomobject]@{ Status = 'Valid'; SignerCertificate = [pscustomobject]@{ Subject = 'CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US' } }
    $result = Invoke-OneDriveUninstaller -RegistryPath 'HKCU:\TMPC-OD' -Machine
    Assert-TestTrue $result 'a fully verified uninstaller runs'
    Assert-TestEqual 1 $script:TestUninstallerCalls.Count 'executed exactly once'
    Assert-TestTrue ($script:TestUninstallerCalls[0].EndsWith('/uninstall /allusers')) 'bounded arguments preserved'
}

Invoke-TMPCTestCase 'D24e' 'Standalone OneDrive: reparse points and protected roots never deleted' {
    $allowed = Join-Path $env:ProgramFiles 'Microsoft OneDrive'
    Add-TestPathItem -Path $allowed -Attributes ([System.IO.FileAttributes]::ReparsePoint) -IsContainer $true
    Assert-TestThrows { Remove-OneDriveRemnant -Path $allowed } 'Linked remnant preserved' 'reparse point'

    $script:OneDriveProtectionReady = $true
    $script:ProtectedOneDriveRoots = @('C:\Users\TMPC-Test\OneDrive')
    Assert-TestThrows { Remove-OneDriveRemnant -Path 'C:\Users\TMPC-Test\OneDrive\remnant' } 'Sync-root overlap' 'custom sync root'

    Assert-TestThrows { Remove-OneDriveRemnant -Path 'C:\Users\TMPC-Test\Documents' } 'Deletion target rejected' 'path outside the allowlist'
    Assert-TestThrows { Remove-OneDriveRemnant -Path (Join-Path $env:USERPROFILE 'OneDrive') } 'Deletion target rejected' 'user OneDrive folder'
}

$productionFunctions = New-TMPCFunctionsScriptBlock -Text $oneDriveText -Names $xmlOneDriveFunctions
. $productionFunctions
. (Join-Path $script:TestsRoot 'TMPC.Tests.Helpers.ps1')

Invoke-TMPCTestCase 'D24f' 'XML OneDrive: strict parse and verified signature before execution' {
    Set-TestRegistryValue -Path 'HKLM:\TMPC-OD' -Name 'UninstallString' -Kind String -Value 'cmd.exe /c something-arbitrary'
    $result = Invoke-OneDriveUninstaller -RegistryPath 'HKLM:\TMPC-OD'
    Assert-TestTrue (-not $result) 'a shell command must never run'
    Assert-TestEqual 0 $script:TestUninstallerCalls.Count 'nothing may be executed'
    Assert-TestLogContains 'not a recognized safe form'

    $exe = Join-Path $env:SystemRoot 'System32\OneDriveSetup.exe'
    Add-TestPathChain -Path $exe
    Set-TestRegistryValue -Path 'HKLM:\TMPC-OD' -Name 'UninstallString' -Kind String -Value ('"' + $exe + '" /uninstall')

    $script:TestSignature = [pscustomobject]@{ Status = 'UnknownError'; SignerCertificate = $null }
    Assert-TestThrows { Invoke-OneDriveUninstaller -RegistryPath 'HKLM:\TMPC-OD' } 'signature not verified' 'invalid signature'
    Assert-TestEqual 0 $script:TestUninstallerCalls.Count 'no execution with an unverified signature'

    $script:TestSignature = [pscustomobject]@{ Status = 'Valid'; SignerCertificate = [pscustomobject]@{ Subject = 'CN=Microsoft Corporation, O=Microsoft Corporation' } }
    $result = Invoke-OneDriveUninstaller -RegistryPath 'HKLM:\TMPC-OD'
    Assert-TestTrue $result 'a fully verified inbox uninstaller runs'
    Assert-TestEqual 1 $script:TestUninstallerCalls.Count 'executed exactly once'
    Assert-TestTrue ($script:TestUninstallerCalls[0].EndsWith('/uninstall')) 'bounded arguments preserved'
}

Invoke-TMPCTestCase 'D24g' 'XML OneDrive: reparse point, sync root and allowlist guards' {
    $allowed = Join-Path $env:ProgramFiles 'Microsoft OneDrive'
    Add-TestPathItem -Path $allowed -Attributes ([System.IO.FileAttributes]::ReparsePoint) -IsContainer $true
    Assert-TestThrows { Remove-OneDriveRemnant -Path $allowed -AllowedRoots @($allowed) -ProtectedRoots @() } 'Linked remnant preserved' 'reparse point'

    Assert-TestThrows { Remove-OneDriveRemnant -Path 'C:\Users\TMPC-Test\OneDrive\junk' -AllowedRoots @('C:\Users\TMPC-Test\OneDrive\junk') -ProtectedRoots @('C:\Users\TMPC-Test\OneDrive') } 'Sync-root overlap' 'custom sync root'
    Assert-TestThrows { Remove-OneDriveRemnant -Path 'C:\Users\TMPC-Test\Documents' -AllowedRoots @() -ProtectedRoots @() } 'Deletion target rejected' 'path outside the allowlist'
}

# ---------------------------------------------------------------------------
# Phase 5: inventory parity and static validator
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '--- Phase 5: inventory parity and static validator ---'

Invoke-TMPCTestCase 'D25' 'Registry inventory parity XML vs standalone (common blocks)' {
    $scopes = @(
        @{ Function = 'Get-SystemRegistryProfile'; Hive = 'HKLM:'; StartPins = $true },
        @{ Function = 'Get-UserRegistryProfile'; Hive = 'HKCU:'; StartPins = $false }
    )
    foreach ($scope in $scopes) {
        $actual = @(Get-TMPCStandaloneInventoryTuples -Text $standaloneText -FunctionName $scope.Function)
        $expected = @(Get-TMPCXmlRegistryTuples -SysText $sysText -Hive $scope.Hive)
        if ($scope.StartPins) {
            $flag = "-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'ConfigureStartPins' -Type 'DWord' -Value 1"
            $json = "-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'ConfigureStartPinsJSON' -Type 'ExpandString' -Value 'C:\ProgramData\TMPC-Windows-11-Optimization\LayoutModification.json'"
            if (@([regex]::Matches($xmlText, [regex]::Escape($flag))).Count -eq 1 -and @([regex]::Matches($xmlText, [regex]::Escape($json))).Count -eq 1) {
                $actual += 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer|SET|ConfigureStartPins|DWord|1'
                $actual += 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer|SET|ConfigureStartPinsJSON|ExpandString|C:\ProgramData\TMPC-Windows-11-Optimization\LayoutModification.json'
            }
        }
        $delta = @(Compare-Object ($expected | Sort-Object -Unique) ($actual | Sort-Object -Unique))
        if ($delta.Count -gt 0) {
            throw ('registry parity delta for {0}: {1}' -f $scope.Hive, (($delta | ForEach-Object { $_.SideIndicator + ' ' + $_.InputObject }) -join ' ; '))
        }
    }

    $bloatTokens = $null; $bloatErrors = $null
    $bloatAst = [System.Management.Automation.Language.Parser]::ParseInput($bloatText, [ref]$bloatTokens, [ref]$bloatErrors)
    $standaloneTokens = $null; $standaloneErrors = $null
    $standaloneAst = [System.Management.Automation.Language.Parser]::ParseInput($standaloneText, [ref]$standaloneTokens, [ref]$standaloneErrors)
    foreach ($name in @('packages','capabilities','optionalFeatures','specialApps')) {
        $find = { param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq ('$' + $name) }
        $sourceNodes = @($bloatAst.FindAll($find, $true))
        $targetNodes = @($standaloneAst.FindAll($find, $true))
        if ($sourceNodes.Count -ne 1 -or $targetNodes.Count -ne 1) { throw ('list is not unambiguous: {0}' -f $name) }
        $sourceList = @($sourceNodes[0].Right.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true) | ForEach-Object Value)
        $targetList = @($targetNodes[0].Right.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true) | ForEach-Object Value)
        $listDelta = @(Compare-Object $sourceList $targetList)
        if ($listDelta.Count -gt 0) { throw ('debloat list parity delta: {0}' -f $name) }
    }
}

if (-not $SkipValidatorCase) {
    Invoke-TMPCTestCase 'D26' 'Static validator passes on this repository' {
        $validator = Join-Path $RepoRoot 'scripts\validate-baseline.ps1'
        Push-Location $RepoRoot
        try {
            $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $validator 2>&1)
            $code = $LASTEXITCODE
        } finally {
            Pop-Location
        }
        if ($code -ne 0) {
            throw ('validator exit code {0}; last output: {1}' -f $code, (($output | Select-Object -Last 6) -join ' | '))
        }
        Assert-TestTrue ((($output | Out-String)).Contains('RESULTADO: OK')) 'validator must report RESULTADO: OK'
    }
}

# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '=== RESULTADO TESTS ==='
Write-Host ('Comprobaciones OK: {0}' -f $script:TestCounters.OK)
Write-Host ('Comprobaciones FAIL: {0}' -f $script:TestCounters.FAIL)
if ($script:TestCounters.FAIL -gt 0) {
    Write-Host 'RESULTADO: FAIL'
    exit 1
}
Write-Host 'RESULTADO: OK'
exit 0
