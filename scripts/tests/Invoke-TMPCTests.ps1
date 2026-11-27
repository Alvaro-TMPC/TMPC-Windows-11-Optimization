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
$networkNode = @($doc.SelectNodes("//*[local-name()='File' and @path]") | Where-Object { $_.GetAttribute('path').EndsWith('NetworkGuard.ps1', [System.StringComparison]::Ordinal) })
if ($networkNode.Count -ne 1) { throw 'NetworkGuard.ps1: expected exactly one File node' }
$networkText = $networkNode[0].InnerText.Trim()
$netfxNode = @($doc.SelectNodes("//*[local-name()='File' and @path]") | Where-Object { $_.GetAttribute('path').EndsWith('NetFx3.ps1', [System.StringComparison]::Ordinal) })
if ($netfxNode.Count -ne 1) { throw 'NetFx3.ps1: expected exactly one File node' }
$netfxText = $netfxNode[0].InnerText.Trim()
$bloatText = Get-TMPCHereStringBody -Text $sysText -VariableName 'bloatRemovalContent'
$oneDriveText = Get-TMPCHereStringBody -Text $sysText -VariableName 'oneDriveRemovalContent'

$registryFunctions = @(
    'Write-Log','Invoke-Operation','ConvertTo-TMPCRegistryValueName','Test-TMPCRegistryValueName',
    'Get-TMPCRegistryEntryState','Write-TMPCRegistryEntry',
    'Remove-TMPCRegistryEntry','Test-TMPCRegistryStateEqual','Invoke-RegistryProfile',
    'Invoke-UserBinaryPreferences','Get-TMPCSystemInfo','Get-TMPCPreflightResult',
    'Get-TMPCExitCode','Test-TMPCRestartRequested'
)
$standaloneOneDriveFunctions = @(
    'Write-Log','Get-TMPCPathItem','Assert-NoReparsePath','Remove-OneDriveRemnant',
    'Get-TMPCSignature','Start-TMPCVerifiedUninstaller','Invoke-OneDriveUninstaller',
    'Get-TMPCOneDriveRegistrationState','Get-TMPCOneDriveCleanupPlan'
)
$xmlOneDriveFunctions = @(
    'Write-Log','Get-RegistryEntryState','Get-RegistryErrorReason','Remove-RegistryEntryIfPresent',
    'Get-TMPCPathItem','Assert-NoReparsePath','Remove-OneDriveRemnant','Get-TMPCSignature',
    'Start-TMPCVerifiedUninstaller','Invoke-OneDriveUninstaller'
)
$xmlRegistryFunctions = @(
    'Write-Log','ConvertTo-RegistryValueName','Test-RegistryValueName',
    'Get-RegistryEntryState','Test-RegistryStateEqual','Get-RegistryErrorReason',
    'Write-RegistryValue','Set-RegistryValue'
)
$xmlIdentityFunctions = @(
    'Resolve-TMPCInteractiveIdentity','Test-TMPCIdentityMatch'
)
$xmlOneDriveScopeFunctions = @(
    'Write-Log','Get-RegistryEntryState','Get-TMPCOneDriveRegistrationState',
    'Get-TMPCOneDriveCleanupPlan'
)
$xmlDefaultHiveFunctions = @(
    'Write-Log','Get-RegistryEntryState','Get-RegistryErrorReason',
    'Remove-RegistryEntryIfPresent','Get-TMPCPathItem','Assert-NoReparsePath',
    'Get-TMPCDefaultHivePath','Test-TMPCDefaultHiveMounted',
    'Invoke-TMPCDefaultHiveLoad','Invoke-TMPCDefaultHiveUnload',
    'New-TMPCRegistryKey','Set-TMPCRegistryEntryValue','Invoke-DefaultOneDrivePolicy'
)
$xmlH03Functions = @(
    'Get-TMPCPrivilegedSidList','Test-TMPCPrivilegedSid','Get-TMPCAclSnapshot',
    'Test-TMPCDirectoryAclSnapshot','Test-TMPCFileAclSnapshot','Test-TMPCDiagnosticAclSnapshot',
    'Test-TMPCPropertyPresent','Get-TMPCOverallStatus','Test-TMPCSetupSummarySchema',
    'Test-TMPCSetupExecutionIdentity','Resolve-TMPCCleanupTaskState','Get-TMPCCleanupTaskState',
    'Get-TMPCCleanupDecision'
)
$xmlCleanupCommandFunctions = @(
    $xmlH03Functions +
    @('Get-TMPCDiagnosticDirectory','Get-TMPCSetupSummaryPath','Read-TMPCSetupSummary',
      'Write-TMPCSetupSummary','Get-TMPCSetupExecutionId','Get-TMPCCleanupCommand')
)
$xmlSummaryFunctions = @(
    $xmlCleanupCommandFunctions + @('Update-TMPCUserPhaseSummary')
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

Invoke-TMPCTestCase 'D28' 'Default registry value: "(Default)" addresses the unnamed value' {
    Set-TestRegistryValue -Path 'HKCU:\TMPC-Default' -Name '' -Kind String -Value 'legacy'
    $inventory = @'
[HKCU:\TMPC-Default]
(Default)|String|
'@
    Invoke-RegistryProfile -Text $inventory -Hive 'HKCU:'
    Assert-TestEqual 1 $script:TestWriteAttempts.Count 'one default-value write expected'
    Assert-TestTrue ($script:TestWriteAttempts[0].EndsWith('Default||String')) 'write must use the empty default value name'
    $entry = Get-TestRegistryValue -Path 'HKCU:\TMPC-Default' -Name ''
    Assert-TestTrue ($null -ne $entry) 'the unnamed default value must exist'
    Assert-TestEqual ([Microsoft.Win32.RegistryValueKind]::String) $entry.Kind 'default value kind must be String'
    Assert-TestEqual '' $entry.Value 'default value must be set to the expected content'
    Assert-TestTrue ($null -eq (Get-TestRegistryValue -Path 'HKCU:\TMPC-Default' -Name '(Default)')) 'no literal (Default) value may be created'

    Invoke-RegistryProfile -Text $inventory -Hive 'HKCU:'
    Assert-TestEqual 1 $script:TestWriteAttempts.Count 'second run must not rewrite the compliant default value'
    Assert-TestEqual 1 $script:Compliant 'default value must be recognized as compliant'
    Assert-TestEqual 0 $script:Errors 'no errors expected'

    $state = Get-TMPCRegistryEntryState -Path 'HKCU:\TMPC-Default' -Name '(Default)'
    Assert-TestTrue $state.ValueExists 'the alias must read the default value'
    Assert-TestEqual '' $state.Value 'the alias must return the default value'
    $keyOnly = Get-TMPCRegistryEntryState -Path 'HKCU:\TMPC-Default' -Name $null
    Assert-TestTrue $keyOnly.PathExists 'key probe must still work'
    Assert-TestTrue (-not $keyOnly.ValueExists) 'key probe must not report a value'
}

Invoke-TMPCTestCase 'D28b' 'GetValueNames model: empty string is the default; other names are unchanged' {
    Assert-TestTrue (Test-TMPCRegistryValueName -ValueNames @('', 'Alpha') -Name '(Default)') 'the alias must map to the empty default name'
    Assert-TestTrue (Test-TMPCRegistryValueName -ValueNames @('', 'Alpha') -Name '') 'the empty name must map to the default value'
    Assert-TestTrue (Test-TMPCRegistryValueName -ValueNames @('', 'Alpha') -Name 'Alpha') 'normal names must be preserved'
    Assert-TestTrue (-not (Test-TMPCRegistryValueName -ValueNames @('(Default)') -Name '(Default)')) 'a literal "(Default)" value must not be mistaken for the default'
    Assert-TestTrue (-not (Test-TMPCRegistryValueName -ValueNames @('') -Name $null)) 'a null probe must not be treated as a value'
    Assert-TestTrue (-not (Test-TMPCRegistryValueName -ValueNames @('') -Name '(Default)Value')) 'similar names must not be rewritten'
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

Invoke-TMPCTestCase 'D30a' 'OneDrive scope: presence alone authorizes no cleanup' {
    foreach ($canUser in @($true, $false)) {
        $plan = Get-TMPCOneDriveCleanupPlan -MachineUninstalled $false -UserUninstalled $false -MachineAbsentVerified $false -UserAbsentVerified $false -CanApplyUser $canUser
        Assert-TestTrue (-not $plan.MachineEvidence) 'machine presence is not evidence for cleanup'
        Assert-TestTrue (-not $plan.UserEvidence) 'user presence is not evidence for cleanup'
        Assert-TestTrue (-not $plan.RemoveMachineConfiguration) 'machine configuration must be preserved'
        Assert-TestTrue (-not $plan.RemoveMachineRemnants) 'machine remnants must be preserved'
        Assert-TestTrue (-not $plan.RemoveUserConfiguration) 'user configuration must be preserved'
        Assert-TestTrue (-not $plan.RemoveUserRemnants) 'user remnants must be preserved'
    }
}

Invoke-TMPCTestCase 'D30b' 'OneDrive scope: machine evidence authorizes only machine cleanup' {
    foreach ($machineAbsent in @($false, $true)) {
        $plan = Get-TMPCOneDriveCleanupPlan -MachineUninstalled (-not $machineAbsent) -UserUninstalled $false -MachineAbsentVerified $machineAbsent -UserAbsentVerified $false -CanApplyUser $true
        Assert-TestTrue $plan.RemoveMachineConfiguration 'machine configuration cleanup expected'
        Assert-TestTrue $plan.RemoveMachineRemnants 'machine remnant cleanup expected'
        Assert-TestTrue (-not $plan.RemoveUserConfiguration) 'machine evidence must not authorize user configuration cleanup'
        Assert-TestTrue (-not $plan.RemoveUserRemnants) 'machine evidence must not authorize user remnant cleanup'
    }
}

Invoke-TMPCTestCase 'D30c' 'OneDrive scope: user success never authorizes machine cleanup' {
    $userUninstalled = Get-TMPCOneDriveCleanupPlan -MachineUninstalled $false -UserUninstalled $true -MachineAbsentVerified $false -UserAbsentVerified $false -CanApplyUser $true
    Assert-TestTrue $userUninstalled.RemoveUserConfiguration 'user-success configuration cleanup expected'
    Assert-TestTrue $userUninstalled.RemoveUserRemnants 'user-success remnant cleanup expected'
    Assert-TestTrue (-not $userUninstalled.RemoveMachineConfiguration) 'user success must never authorize machine configuration cleanup'
    Assert-TestTrue (-not $userUninstalled.RemoveMachineRemnants) 'user success must never authorize machine remnant cleanup'

    $userAbsent = Get-TMPCOneDriveCleanupPlan -MachineUninstalled $false -UserUninstalled $false -MachineAbsentVerified $false -UserAbsentVerified $true -CanApplyUser $true
    Assert-TestTrue $userAbsent.RemoveUserConfiguration 'verified user absence must authorize user cleanup'
    Assert-TestTrue (-not $userAbsent.RemoveMachineConfiguration) 'verified user absence must not authorize machine cleanup'

    $deferred = Get-TMPCOneDriveCleanupPlan -MachineUninstalled $false -UserUninstalled $true -MachineAbsentVerified $false -UserAbsentVerified $false -CanApplyUser $false
    Assert-TestTrue (-not $deferred.UserEvidence) 'an unauthorized target account cannot authorize user cleanup'
    Assert-TestTrue (-not $deferred.RemoveMachineConfiguration) 'an unauthorized user success must not authorize machine cleanup'
    Assert-TestTrue (-not $deferred.RemoveMachineRemnants) 'an unauthorized user success must not authorize machine remnants'
}

Invoke-TMPCTestCase 'D30d' 'OneDrive scope: denied read is unknown, not verified absence' {
    Add-TestRegistryKey -Path 'HKLM:\TMPC-OD-Machine'
    $present = Get-TMPCOneDriveRegistrationState -Path 'HKLM:\TMPC-OD-Machine'
    Assert-TestEqual 'PRESENT' $present 'a readable key must be reported as present'

    $absent = Get-TMPCOneDriveRegistrationState -Path 'HKLM:\TMPC-OD-Missing'
    Assert-TestEqual 'ABSENT_VERIFIED' $absent 'a successful read with no key is verified absence'

    $script:TestFailRead = $true
    $unknown = Get-TMPCOneDriveRegistrationState -Path 'HKLM:\TMPC-OD-Machine'
    Assert-TestEqual 'UNKNOWN' $unknown 'a denied read must never be inferred as absence'
    $plan = Get-TMPCOneDriveCleanupPlan -MachineUninstalled $false -UserUninstalled $true -MachineAbsentVerified ($unknown -eq 'ABSENT_VERIFIED') -UserAbsentVerified $false -CanApplyUser $true
    Assert-TestTrue (-not $plan.RemoveMachineConfiguration) 'unknown machine state must defer machine cleanup'
    Assert-TestTrue (-not $plan.RemoveMachineRemnants) 'unknown machine state must preserve machine remnants'
}

Invoke-TMPCTestCase 'D30e' 'OneDrive scope: cleanup loops use the independent scope plan' {
    $removal = Get-TMPCFunctionText -Text $standaloneText -Names @('Invoke-OneDriveRemoval')
    foreach ($fragment in @('$plan.RemoveMachineConfiguration', '$plan.RemoveMachineRemnants', '$plan.RemoveUserConfiguration', '$plan.RemoveUserRemnants')) {
        Assert-TestTrue $removal.Contains($fragment) ('missing scope gate: {0}' -f $fragment)
    }
    Assert-TestTrue (-not $removal.Contains('$script:OneDriveUninstalled -or')) 'the combined uninstall flag must not gate machine cleanup'
    Assert-TestTrue (-not $removal.Contains('Test-Path -LiteralPath $machine')) 'machine absence must not be inferred with Test-Path'
    Assert-TestTrue (-not $removal.Contains('Test-Path -LiteralPath $user')) 'user absence must not be inferred with Test-Path'
}

Invoke-TMPCTestCase 'D30f' 'OneDrive scope: A-J scenario matrix' {
    $scenarios = @(
        @{ Name='A machine-only install'; M=$false; U=$false; MA=$false; UA=$true; Can=$true; Machine=$false; User=$true },
        @{ Name='B user-only install'; M=$false; U=$false; MA=$true; UA=$false; Can=$true; Machine=$true; User=$false },
        @{ Name='C both installs present'; M=$false; U=$false; MA=$false; UA=$false; Can=$true; Machine=$false; User=$false },
        @{ Name='D machine uninstalled'; M=$true; U=$false; MA=$false; UA=$false; Can=$true; Machine=$true; User=$false },
        @{ Name='E user uninstalled'; M=$false; U=$true; MA=$false; UA=$false; Can=$true; Machine=$false; User=$true },
        @{ Name='F HKLM read denied'; M=$false; U=$true; MA=$false; UA=$false; Can=$true; Machine=$false; User=$true },
        @{ Name='G machine state unknown'; M=$false; U=$false; MA=$false; UA=$false; Can=$true; Machine=$false; User=$false },
        @{ Name='H uninstaller failed'; M=$false; U=$false; MA=$false; UA=$false; Can=$true; Machine=$false; User=$false },
        @{ Name='I machine absent verified'; M=$false; U=$false; MA=$true; UA=$false; Can=$true; Machine=$true; User=$false },
        @{ Name='J multiple users, target not authorized'; M=$false; U=$true; MA=$false; UA=$false; Can=$false; Machine=$false; User=$false }
    )
    foreach ($scenario in $scenarios) {
        $plan = Get-TMPCOneDriveCleanupPlan -MachineUninstalled $scenario.M -UserUninstalled $scenario.U -MachineAbsentVerified $scenario.MA -UserAbsentVerified $scenario.UA -CanApplyUser $scenario.Can
        Assert-TestEqual $scenario.Machine $plan.RemoveMachineConfiguration ('machine configuration gate: {0}' -f $scenario.Name)
        Assert-TestEqual $scenario.Machine $plan.RemoveMachineRemnants ('machine remnant gate: {0}' -f $scenario.Name)
        Assert-TestEqual $scenario.User $plan.RemoveUserConfiguration ('user configuration gate: {0}' -f $scenario.Name)
        Assert-TestEqual $scenario.User $plan.RemoveUserRemnants ('user remnant gate: {0}' -f $scenario.Name)
        if ($scenario.U -and -not $scenario.M -and -not $scenario.MA) {
            Assert-TestTrue (-not $plan.RemoveMachineConfiguration) ('user success enabled machine cleanup: {0}' -f $scenario.Name)
            Assert-TestTrue (-not $plan.RemoveMachineRemnants) ('user success enabled machine remnants: {0}' -f $scenario.Name)
        }
    }
}

$productionFunctions = New-TMPCFunctionsScriptBlock -Text $oneDriveText -Names $xmlOneDriveFunctions
. $productionFunctions
. (Join-Path $script:TestsRoot 'TMPC.Tests.Helpers.ps1')

Invoke-TMPCTestCase 'D24f' 'XML OneDrive: strict command, machine /allusers and verified signature' {
    Set-TestRegistryValue -Path 'HKLM:\TMPC-OD' -Name 'UninstallString' -Kind String -Value 'cmd.exe /c something-arbitrary'
    $result = Invoke-OneDriveUninstaller -RegistryPath 'HKLM:\TMPC-OD' -Machine
    Assert-TestTrue (-not $result) 'a shell command must never run'
    Assert-TestEqual 0 $script:TestUninstallerCalls.Count 'nothing may be executed'
    Assert-TestLogContains 'not a recognized safe form'

    $exe = Join-Path $env:SystemRoot 'System32\OneDriveSetup.exe'
    Add-TestPathChain -Path $exe
    Set-TestRegistryValue -Path 'HKLM:\TMPC-OD' -Name 'UninstallString' -Kind String -Value ('"' + $exe + '" /uninstall')
    $result = Invoke-OneDriveUninstaller -RegistryPath 'HKLM:\TMPC-OD' -Machine
    Assert-TestTrue (-not $result) 'a machine entry without /allusers must be deferred'
    Assert-TestEqual 0 $script:TestUninstallerCalls.Count 'wrong-scope machine uninstall must not run'
    Assert-TestLogContains 'lacks allusers scope'

    Set-TestRegistryValue -Path 'HKLM:\TMPC-OD' -Name 'UninstallString' -Kind String -Value ('"' + $exe + '" /uninstall /allusers /extra')
    $result = Invoke-OneDriveUninstaller -RegistryPath 'HKLM:\TMPC-OD' -Machine
    Assert-TestTrue (-not $result) 'unknown extra arguments must be rejected'
    Assert-TestEqual 0 $script:TestUninstallerCalls.Count 'unknown arguments must not run'
    Assert-TestLogContains 'not a recognized safe form'

    Set-TestRegistryValue -Path 'HKLM:\TMPC-OD' -Name 'UninstallString' -Kind String -Value ('"' + $exe + '" /uninstall /allusers')
    $script:TestSignature = [pscustomobject]@{ Status = 'UnknownError'; SignerCertificate = $null }
    Assert-TestThrows { Invoke-OneDriveUninstaller -RegistryPath 'HKLM:\TMPC-OD' -Machine } 'signature not verified' 'invalid signature'
    Assert-TestEqual 0 $script:TestUninstallerCalls.Count 'no execution with an unverified signature'

    $script:TestSignature = [pscustomobject]@{ Status = 'Valid'; SignerCertificate = [pscustomobject]@{ Subject = 'CN=Microsoft Corporation, O=Microsoft Corporation' } }
    $result = Invoke-OneDriveUninstaller -RegistryPath 'HKLM:\TMPC-OD' -Machine
    Assert-TestTrue $result 'a fully verified inbox uninstaller runs'
    Assert-TestEqual 1 $script:TestUninstallerCalls.Count 'executed exactly once'
    Assert-TestTrue ($script:TestUninstallerCalls[0].EndsWith('/uninstall /allusers')) 'the machine scope is preserved exactly'
    Assert-TestTrue ($oneDriveText.Contains('Invoke-OneDriveUninstaller -RegistryPath $machineUninstallKey -Machine')) 'the XML machine caller must request machine scope'
}

Invoke-TMPCTestCase 'D24g' 'XML OneDrive: reparse point, sync root and allowlist guards' {
    $allowed = Join-Path $env:ProgramFiles 'Microsoft OneDrive'
    Add-TestPathItem -Path $allowed -Attributes ([System.IO.FileAttributes]::ReparsePoint) -IsContainer $true
    Assert-TestThrows { Remove-OneDriveRemnant -Path $allowed -AllowedRoots @($allowed) -ProtectedRoots @() } 'Linked remnant preserved' 'reparse point'

    Assert-TestThrows { Remove-OneDriveRemnant -Path 'C:\Users\TMPC-Test\OneDrive\junk' -AllowedRoots @('C:\Users\TMPC-Test\OneDrive\junk') -ProtectedRoots @('C:\Users\TMPC-Test\OneDrive') } 'Sync-root overlap' 'custom sync root'
    Assert-TestThrows { Remove-OneDriveRemnant -Path 'C:\Users\TMPC-Test\Documents' -AllowedRoots @() -ProtectedRoots @() } 'Deletion target rejected' 'path outside the allowlist'
}

$productionFunctions = New-TMPCFunctionsScriptBlock -Text $sysText -Names $xmlIdentityFunctions
. $productionFunctions

Invoke-TMPCTestCase 'D31' 'Identity: SID from Explorer/ProfileList, not the profile name' {
    $profiles = @([pscustomobject]@{ Sid = 'S-1-5-21-1001'; ProfileImagePath = 'C:\Users\OldName' })
    $explorers = @([pscustomobject]@{ SessionId = 2; OwnerSid = 'S-1-5-21-1001'; OwnerUser = 'NewName' })
    $identity = Resolve-TMPCInteractiveIdentity -ExplorerProcesses $explorers -Profiles $profiles
    Assert-TestEqual 'OK' $identity.Status 'renamed account and different profile folder must resolve'
    Assert-TestEqual 'S-1-5-21-1001' $identity.Sid 'SID must come from the owner'
    Assert-TestEqual 'C:\Users\OldName' $identity.ProfilePath 'profile path must come from ProfileList by SID'
    Assert-TestEqual 'NewName' $identity.UserName 'owner name is informative only'

    $msaProfiles = @([pscustomobject]@{ Sid = 'S-1-5-21-2002'; ProfileImagePath = 'C:\Users\alvar' })
    $msaExplorers = @([pscustomobject]@{ SessionId = 3; OwnerSid = 'S-1-5-21-2002'; OwnerUser = 'alvaro@example.com' })
    $msa = Resolve-TMPCInteractiveIdentity -ExplorerProcesses $msaExplorers -Profiles $msaProfiles
    Assert-TestEqual 'OK' $msa.Status 'Microsoft account simulation must resolve by SID'
    Assert-TestEqual 'C:\Users\alvar' $msa.ProfilePath 'MSA profile folder may differ from the account name'

    $sameSidExplorers = @(
        [pscustomobject]@{ SessionId = 4; OwnerSid = 'S-1-5-21-3003'; OwnerUser = 'User' },
        [pscustomobject]@{ SessionId = 4; OwnerSid = 'S-1-5-21-3003'; OwnerUser = 'User' }
    )
    $sameSid = Resolve-TMPCInteractiveIdentity -ExplorerProcesses $sameSidExplorers -Profiles @([pscustomobject]@{ Sid = 'S-1-5-21-3003'; ProfileImagePath = 'C:\Users\User' })
    Assert-TestEqual 'OK' $sameSid.Status 'multiple Explorer processes with the same SID are valid'

    $otherSession = @(
        [pscustomobject]@{ SessionId = 5; OwnerSid = 'S-1-5-21-4004'; OwnerUser = 'User' },
        [pscustomobject]@{ SessionId = 6; OwnerSid = 'S-1-5-21-4004'; OwnerUser = 'User' }
    )
    $other = Resolve-TMPCInteractiveIdentity -ExplorerProcesses $otherSession -Profiles @([pscustomobject]@{ Sid = 'S-1-5-21-4004'; ProfileImagePath = 'C:\Users\User' })
    Assert-TestEqual 'AMBIGUOUS_SESSION' $other.Status 'more than one interactive session must defer'

    $differentIdentities = @(
        [pscustomobject]@{ SessionId = 7; OwnerSid = 'S-1-5-21-5005'; OwnerUser = 'UserA' },
        [pscustomobject]@{ SessionId = 7; OwnerSid = 'S-1-5-21-6006'; OwnerUser = 'UserB' }
    )
    $different = Resolve-TMPCInteractiveIdentity -ExplorerProcesses $differentIdentities -Profiles @()
    Assert-TestEqual 'AMBIGUOUS_IDENTITY' $different.Status 'different SIDs in one session must defer'

    $noExplorer = Resolve-TMPCInteractiveIdentity -ExplorerProcesses @() -Profiles @()
    Assert-TestEqual 'NO_EXPLORER' $noExplorer.Status 'no Explorer is not a fallback account'

    $unknownProfile = Resolve-TMPCInteractiveIdentity -ExplorerProcesses $explorers -Profiles @()
    Assert-TestEqual 'PROFILE_NOT_FOUND' $unknownProfile.Status 'SID without ProfileList entry must defer'

    $mismatch = Resolve-TMPCInteractiveIdentity -ExplorerProcesses $explorers -Profiles $profiles -CurrentSid 'S-1-5-21-9999'
    Assert-TestEqual 'IDENTITY_MISMATCH' $mismatch.Status 'a mismatched current SID must defer'
}

Invoke-TMPCTestCase 'D31b' 'Identity: selected and linked tokens must match the expected SID' {
    Assert-TestTrue (Test-TMPCIdentityMatch -ExpectedSid 'S-1-5-21-1' -ActualSid 'S-1-5-21-1') 'matching token'
    Assert-TestTrue (-not (Test-TMPCIdentityMatch -ExpectedSid 'S-1-5-21-1' -ActualSid 'S-1-5-21-2')) 'different token SID'
    Assert-TestTrue (-not (Test-TMPCIdentityMatch -ExpectedSid 'S-1-5-21-1' -ActualSid 'S-1-5-21-1' -LinkedSid 'S-1-5-21-2')) 'different linked token SID'
    Assert-TestTrue (-not (Test-TMPCIdentityMatch -ExpectedSid 'S-1-5-21-1' -ActualSid '')) 'unknown token SID'
}

$productionFunctions = New-TMPCFunctionsScriptBlock -Text $oneDriveText -Names $xmlDefaultHiveFunctions
. $productionFunctions
. (Join-Path $script:TestsRoot 'TMPC.Tests.Helpers.ps1')

function Reset-TestDefaultHiveState {
    $script:TestDefaultMountPresent = $false
    $script:TestDefaultUnloadExit = 0
    $script:TestDefaultKeepMounted = $false
    $script:TestDefaultLoadExit = 0
    $script:TestDefaultLoadCalls = 0
    $script:TestDefaultUnloadCalls = 0
    $script:TestDefaultMountName = $null
    $script:TestFailDefaultValueWrite = $false
    $script:TestFailMarkerWrite = $false
}
function Get-TMPCDefaultHivePath { return 'C:\Users\Default\NTUSER.DAT' }
function Test-TMPCDefaultHiveMounted { param([string]$MountName) return [bool]$script:TestDefaultMountPresent }
function Invoke-TMPCDefaultHiveLoad {
    param([string]$MountName, [string]$HivePath)
    $script:TestDefaultLoadCalls++
    if ($script:TestDefaultLoadExit -ne 0) { return [int]$script:TestDefaultLoadExit }
    $script:TestDefaultMountName = $MountName
    $script:TestDefaultMountPresent = $true
    $run = "Registry::HKEY_USERS\$MountName\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    $thdf = "Registry::HKEY_USERS\$MountName\SOFTWARE\Microsoft\OneDrive"
    Add-TestRegistryKey -Path $run
    Add-TestRegistryKey -Path $thdf
    Set-TestRegistryValue -Path $run -Name 'OneDriveSetup' -Kind String -Value 'present'
    Set-TestRegistryValue -Path $thdf -Name 'EnableTHDFFeatures' -Kind DWord -Value 1
    return 0
}
function Invoke-TMPCDefaultHiveUnload {
    param([string]$MountName)
    $script:TestDefaultUnloadCalls++
    if ($script:TestDefaultUnloadExit -eq 0 -and -not $script:TestDefaultKeepMounted) { $script:TestDefaultMountPresent = $false }
    return [int]$script:TestDefaultUnloadExit
}
function New-TMPCRegistryKey { param([string]$Path) Add-TestRegistryKey -Path $Path }
function Set-TMPCRegistryEntryValue {
    param([string]$Path, [string]$Name, [string]$Type, $Value)
    if ($script:TestFailDefaultValueWrite) { throw 'value write denied by test double' }
    if ($script:TestFailMarkerWrite -and $Path -eq 'HKLM:\SOFTWARE\Autounattend\OneDriveRemoval') { throw 'marker write denied by test double' }
    $kind = switch ($Type) {
        'DWord' { [Microsoft.Win32.RegistryValueKind]::DWord }
        'String' { [Microsoft.Win32.RegistryValueKind]::String }
        default { throw 'Unsupported registry type.' }
    }
    Set-TestRegistryValue -Path $Path -Name $Name -Kind $kind -Value $Value
}

Invoke-TMPCTestCase 'D32' 'Default hive: load, write and unload verified before marker' {
    Reset-TestDefaultHiveState
    Add-TestPathChain -Path 'C:\Users\Default\NTUSER.DAT' -LeafIsContainer $false
    $result = Invoke-DefaultOneDrivePolicy
    Assert-TestEqual 'APPLIED' $result 'verified lifecycle must apply'
    Assert-TestTrue (-not $script:TestDefaultMountPresent) 'temporary mount must be gone'
    $marker = Get-TestRegistryValue -Path 'HKLM:\SOFTWARE\Autounattend\OneDriveRemoval' -Name 'DefaultUserConfigured'
    Assert-TestTrue ($null -ne $marker) 'marker must exist after verified unload'
    $run = Get-TestRegistryValue -Path ("Registry::HKEY_USERS\$($script:TestDefaultMountName)\SOFTWARE\Microsoft\Windows\CurrentVersion\Run") -Name 'OneDriveSetup'
    Assert-TestTrue ($null -eq $run) 'OneDriveSetup Run value must be removed'
    $thdf = Get-TestRegistryValue -Path ("Registry::HKEY_USERS\$($script:TestDefaultMountName)\SOFTWARE\Microsoft\OneDrive") -Name 'EnableTHDFFeatures'
    Assert-TestEqual 0 $thdf.Value 'EnableTHDFFeatures must be 0'
}

Invoke-TMPCTestCase 'D32b' 'Default hive: load failure does not write the marker' {
    Reset-TestDefaultHiveState
    $script:TestDefaultLoadExit = 1
    Add-TestPathChain -Path 'C:\Users\Default\NTUSER.DAT' -LeafIsContainer $false
    $result = Invoke-DefaultOneDrivePolicy
    Assert-TestEqual 'FAILED' $result 'load failure is a failure'
    Assert-TestEqual 1 $script:TestDefaultLoadCalls 'load attempted once'
    Assert-TestTrue ($null -eq (Get-TestRegistryValue -Path 'HKLM:\SOFTWARE\Autounattend\OneDriveRemoval' -Name 'DefaultUserConfigured')) 'no marker on load failure'
}

Invoke-TMPCTestCase 'D32c' 'Default hive: unload nonzero or still mounted prevents success' {
    Reset-TestDefaultHiveState
    $script:TestDefaultUnloadExit = 1
    $script:TestDefaultKeepMounted = $true
    Add-TestPathChain -Path 'C:\Users\Default\NTUSER.DAT' -LeafIsContainer $false
    $result = Invoke-DefaultOneDrivePolicy
    Assert-TestEqual 'FAILED' $result 'unload failure is not success'
    Assert-TestTrue ($script:TestDefaultUnloadCalls -ge 3) 'unload retries must be bounded but attempted'
    Assert-TestTrue ($null -eq (Get-TestRegistryValue -Path 'HKLM:\SOFTWARE\Autounattend\OneDriveRemoval' -Name 'DefaultUserConfigured')) 'no marker after unload failure'
}

Invoke-TMPCTestCase 'D32d' 'Default hive: unload code zero with key still present prevents success' {
    Reset-TestDefaultHiveState
    $script:TestDefaultUnloadExit = 0
    $script:TestDefaultKeepMounted = $true
    Add-TestPathChain -Path 'C:\Users\Default\NTUSER.DAT' -LeafIsContainer $false
    $result = Invoke-DefaultOneDrivePolicy
    Assert-TestEqual 'FAILED' $result 'a remaining mount is not a verified unload'
    Assert-TestEqual 3 $script:TestDefaultUnloadCalls 'the bounded retry count must be exhausted'
    Assert-TestTrue ($null -eq (Get-TestRegistryValue -Path 'HKLM:\SOFTWARE\Autounattend\OneDriveRemoval' -Name 'DefaultUserConfigured')) 'no marker while the mount remains'
}

Invoke-TMPCTestCase 'D32e' 'Default hive: a preexisting foreign mount is not touched' {
    Reset-TestDefaultHiveState
    $script:TestDefaultMountPresent = $true
    Add-TestPathChain -Path 'C:\Users\Default\NTUSER.DAT' -LeafIsContainer $false
    $result = Invoke-DefaultOneDrivePolicy
    Assert-TestEqual 'DEFERRED' $result 'preexisting mount must defer'
    Assert-TestEqual 0 $script:TestDefaultLoadCalls 'no load on a preexisting mount'
    Assert-TestTrue ($null -eq (Get-TestRegistryValue -Path 'HKLM:\SOFTWARE\Autounattend\OneDriveRemoval' -Name 'DefaultUserConfigured')) 'no marker on deferral'
}

Invoke-TMPCTestCase 'D32f' 'Default hive: value or marker write failure prevents success' {
    Reset-TestDefaultHiveState
    $script:TestFailDefaultValueWrite = $true
    Add-TestPathChain -Path 'C:\Users\Default\NTUSER.DAT' -LeafIsContainer $false
    Assert-TestEqual 'FAILED' (Invoke-DefaultOneDrivePolicy) 'value write failure must fail'
    Assert-TestTrue ($null -eq (Get-TestRegistryValue -Path 'HKLM:\SOFTWARE\Autounattend\OneDriveRemoval' -Name 'DefaultUserConfigured')) 'no marker on value failure'

    Reset-TestDefaultHiveState
    $script:TestFailMarkerWrite = $true
    Add-TestPathChain -Path 'C:\Users\Default\NTUSER.DAT' -LeafIsContainer $false
    Assert-TestEqual 'FAILED' (Invoke-DefaultOneDrivePolicy) 'marker write failure must fail'
    Assert-TestTrue (-not $script:TestDefaultMountPresent) 'unload must still be verified'
}

Invoke-TMPCTestCase 'D32g' 'Default hive: a legacy marker is revalidated after verified unload' {
    Reset-TestDefaultHiveState
    Set-TestRegistryValue -Path 'HKLM:\SOFTWARE\Autounattend\OneDriveRemoval' -Name 'DefaultUserConfigured' -Kind String -Value '2026-01-01 00:00:00'
    Add-TestPathChain -Path 'C:\Users\Default\NTUSER.DAT' -LeafIsContainer $false
    $result = Invoke-DefaultOneDrivePolicy
    Assert-TestEqual 'APPLIED' $result 'legacy marker must not be trusted'
    $marker = Get-TestRegistryValue -Path 'HKLM:\SOFTWARE\Autounattend\OneDriveRemoval' -Name 'DefaultUserConfigured'
    Assert-TestTrue ([string]$marker.Value).StartsWith('R1|') 'the replacement marker must carry the R1 schema'
    Assert-TestTrue (-not $script:TestDefaultMountPresent) 'verified unload required before the new marker'
}

$productionFunctions = New-TMPCFunctionsScriptBlock -Text $oneDriveText -Names $xmlOneDriveScopeFunctions
. $productionFunctions
. (Join-Path $script:TestsRoot 'TMPC.Tests.Helpers.ps1')

Invoke-TMPCTestCase 'D33' 'XML OneDrive: UNKNOWN is not absence and scopes stay independent' {
    Set-TestRegistryValue -Path 'HKLM:\TMPC-OD-Machine' -Name 'UninstallString' -Kind String -Value 'present'
    Assert-TestEqual 'PRESENT' (Get-TMPCOneDriveRegistrationState -Path 'HKLM:\TMPC-OD-Machine') 'present registration'
    Assert-TestEqual 'ABSENT_VERIFIED' (Get-TMPCOneDriveRegistrationState -Path 'HKLM:\TMPC-OD-Missing') 'missing key is verified absence'
    $script:TestFailRead = $true
    Assert-TestEqual 'UNKNOWN' (Get-TMPCOneDriveRegistrationState -Path 'HKLM:\TMPC-OD-Machine') 'denied read is unknown'
    $script:TestFailRead = $false

    $machineOnly = Get-TMPCOneDriveCleanupPlan -MachineUninstalled $true -UserUninstalled $false -MachineAbsentVerified $false -UserAbsentVerified $false -CanApplyUser $true
    Assert-TestTrue ($machineOnly.RemoveMachineConfiguration -and -not $machineOnly.RemoveUserConfiguration) 'machine evidence only authorizes machine cleanup'
    $userOnly = Get-TMPCOneDriveCleanupPlan -MachineUninstalled $false -UserUninstalled $true -MachineAbsentVerified $false -UserAbsentVerified $false -CanApplyUser $true
    Assert-TestTrue ($userOnly.RemoveUserConfiguration -and -not $userOnly.RemoveMachineConfiguration) 'user evidence only authorizes user cleanup'
    $noIdentity = Get-TMPCOneDriveCleanupPlan -MachineUninstalled $false -UserUninstalled $true -MachineAbsentVerified $false -UserAbsentVerified $false -CanApplyUser $false
    Assert-TestTrue (-not $noIdentity.RemoveUserConfiguration -and -not $noIdentity.RemoveUserRemnants) 'no verified identity means no user cleanup'
    $absent = Get-TMPCOneDriveCleanupPlan -MachineUninstalled $false -UserUninstalled $false -MachineAbsentVerified $true -UserAbsentVerified $true -CanApplyUser $true
    Assert-TestTrue ($absent.RemoveMachineConfiguration -and $absent.RemoveMachineRemnants -and $absent.RemoveUserConfiguration -and $absent.RemoveUserRemnants) 'independent verified absence authorizes each scope'
}

$productionFunctions = New-TMPCFunctionsScriptBlock -Text $sysText -Names $xmlSummaryFunctions
. $productionFunctions

$script:TestExecutionId = '11111111-1111-1111-1111-111111111111'
function New-TestH03Summary {
    param([string]$SystemPhase = 'SUCCESS', [string]$HkcUserPhase = 'PENDING')
    $bloat = 'SUCCESS'
    $oneDrive = 'SUCCESS'
    $systemErrors = $false
    $systemDeferred = $false
    switch ($SystemPhase) {
        'PARTIAL_SUCCESS' { $oneDrive = 'FAILED'; $systemErrors = $true }
        'FAILED' { $bloat = 'FAILED'; $oneDrive = 'FAILED'; $systemErrors = $true }
        'DEFERRED' { $bloat = 'DEFERRED'; $oneDrive = 'DEFERRED'; $systemDeferred = $true }
    }
    $hkcErrors = ($HkcUserPhase -eq 'FAILED')
    $hkcDeferred = ($HkcUserPhase -eq 'DEFERRED')
    $hkcAttempts = if ($HkcUserPhase -eq 'PENDING') { 0 } else { 1 }
    $hkcOutcome = switch ($HkcUserPhase) {
        'SUCCESS' { 'SUCCESS' }
        'FAILED' { 'TRANSIENT' }
        'DEFERRED' { 'DEFERRED' }
        default { 'PENDING' }
    }
    $overall = if ($HkcUserPhase -eq 'PENDING') { 'UNKNOWN_OR_INTERRUPTED' } else { Get-TMPCOverallStatus -SystemPhase $SystemPhase -HkcUserPhase $HkcUserPhase }
    return [pscustomobject]@{
        SchemaVersion       = 1
        Profile             = 'TMPC-Windows-11-Optimization'
        Revision            = 'R2-local'
        ExecutionId         = [string]$script:TestExecutionId
        SystemPhase         = $SystemPhase
        SystemHadErrors     = $systemErrors
        SystemDeferred      = $systemDeferred
        BloatStatus         = $bloat
        OneDriveStatus      = $oneDrive
        UserTaskRegistration = 'SUCCESS'
        HkcUserPhase        = $HkcUserPhase
        HkcHadErrors        = $hkcErrors
        HkcDeferred         = $hkcDeferred
        HkcAttempts         = $hkcAttempts
        HkcOutcome          = $hkcOutcome
        HkcRetryExhausted   = $false
        HkcReason           = ''
        CleanupStatus       = 'PENDING'
        CleanupAttempts     = 0
        CleanupReason       = ''
        CleanupTimestampUtc = ''
        OverallStatus       = $overall
        TimestampUtc        = (Get-Date).ToUniversalTime().ToString('o')
    }
}
function Read-TMPCSetupSummary {
    return $script:TestSummaryObject
}
function Write-TMPCSetupSummary {
    param([hashtable]$Values, [switch]$Reset)
    foreach ($key in $Values.Keys) {
        $script:TestSummaryObject | Add-Member -NotePropertyName $key -NotePropertyValue $Values[$key] -Force
    }
    $script:TestLastSummaryValues = $Values
    return 'test-summary'
}
function Get-TMPCSetupExecutionId {
    return [string]$script:TestExecutionId
}

Invoke-TMPCTestCase 'D34' 'Summary: a later HKCU success cannot erase a SYSTEM failure' {
    $script:TestSummaryObject = New-TestH03Summary -SystemPhase 'SUCCESS' -HkcUserPhase 'PENDING'
    $result = Update-TMPCUserPhaseSummary -Phase 'SUCCESS' -HadErrors $false -Deferred $false
    Assert-TestEqual 'test-summary' $result 'summary update path'
    Assert-TestEqual 'SUCCESS' $script:TestLastSummaryValues.OverallStatus 'both phases successful'

    $script:TestSummaryObject = New-TestH03Summary -SystemPhase 'PARTIAL_SUCCESS' -HkcUserPhase 'PENDING'
    $null = Update-TMPCUserPhaseSummary -Phase 'SUCCESS' -HadErrors $false -Deferred $false
    Assert-TestEqual 'PARTIAL_SUCCESS' $script:TestLastSummaryValues.OverallStatus 'SYSTEM partial plus HKCU success remains partial'

    $script:TestSummaryObject = New-TestH03Summary -SystemPhase 'FAILED' -HkcUserPhase 'PENDING'
    $null = Update-TMPCUserPhaseSummary -Phase 'SUCCESS' -HadErrors $false -Deferred $false
    Assert-TestEqual 'PARTIAL_SUCCESS' $script:TestLastSummaryValues.OverallStatus 'SYSTEM failure is not converted to global success'

    $script:TestSummaryObject = New-TestH03Summary -SystemPhase 'FAILED' -HkcUserPhase 'PENDING'
    $null = Update-TMPCUserPhaseSummary -Phase 'FAILED' -HadErrors $true -Deferred $false
    Assert-TestEqual 'FAILED' $script:TestLastSummaryValues.OverallStatus 'both phases failed'

    $script:TestSummaryObject = New-TestH03Summary -SystemPhase 'SUCCESS' -HkcUserPhase 'PENDING'
    $null = Update-TMPCUserPhaseSummary -Phase 'DEFERRED' -HadErrors $false -Deferred $true
    Assert-TestEqual 'DEFERRED' $script:TestLastSummaryValues.OverallStatus 'deferred user phase'

    $script:TestSummaryObject = New-TestH03Summary -SystemPhase 'DEFERRED' -HkcUserPhase 'PENDING'
    $null = Update-TMPCUserPhaseSummary -Phase 'FAILED' -HadErrors $true -Deferred $false
    Assert-TestEqual 'PARTIAL_SUCCESS' $script:TestLastSummaryValues.OverallStatus 'a failure is not hidden by a deferral'

    $script:TestSummaryObject = New-TestH03Summary -SystemPhase 'UNKNOWN_OR_INTERRUPTED' -HkcUserPhase 'PENDING'
    $null = Update-TMPCUserPhaseSummary -Phase 'SUCCESS' -HadErrors $false -Deferred $false
    Assert-TestEqual 'UNKNOWN_OR_INTERRUPTED' $script:TestLastSummaryValues.OverallStatus 'unknown SYSTEM state stays unknown'

    $script:TestSummaryObject = $null
    Assert-TestThrows { Update-TMPCUserPhaseSummary -Phase 'SUCCESS' -HadErrors $false -Deferred $false } 'missing or invalid' 'missing summary must not be accepted'
}

$productionFunctions = New-TMPCFunctionsScriptBlock -Text $sysText -Names $xmlCleanupCommandFunctions
. $productionFunctions

Invoke-TMPCTestCase 'D34b' 'Cleanup: only trusted SUCCESS authorizes deletion' {
    $command = Get-TMPCCleanupCommand
    Assert-TestTrue ($command.Contains('Get-TMPCCleanupDecision')) 'cleanup must use the decision helper'
    Assert-TestTrue ($command.Contains('Test-TMPCSetupSummarySchema')) 'cleanup must validate the summary schema'
    Assert-TestTrue ($command.Contains('Test-TMPCSetupExecutionIdentity')) 'cleanup must validate the execution identity'
    Assert-TestTrue ($command.Contains('Get-TMPCCleanupTaskState')) 'cleanup must classify the one-shot task'
    Assert-TestTrue ($command.Contains('ABSENT_VERIFIED')) 'cleanup must require verified absence'
    Assert-TestTrue ($command.Contains('PRESENT') -and $command.Contains('UNKNOWN')) 'cleanup must distinguish present and unknown task states'
    Assert-TestTrue ($command.Contains('Get-TMPCAclSnapshot')) 'cleanup must revalidate ACLs'
    Assert-TestTrue ($command.Contains("TMPC-Windows-11-Optimization")) 'cleanup must revalidate the parent directory ACL'
    Assert-TestTrue ($command.Contains('CleanupStatus')) 'cleanup must persist its real status'
    Assert-TestTrue ($command.Contains('Test-Path -LiteralPath')) 'cleanup must verify deletion'
    Assert-TestTrue ($command.Contains('Unregister-ScheduledTask')) 'cleanup must unregister only after handling'
    Assert-TestTrue ($command.Contains('IN_PROGRESS')) 'cleanup must record an in-progress state before deletion'
    Assert-TestTrue (-not ($command -match 'S-1-5-21-\d+-\d+-\d+-\d+')) 'cleanup command must not contain user SIDs'
    Assert-TestTrue (-not $command.Contains('$env:USERNAME')) 'cleanup command must not contain user names'
}

Invoke-TMPCTestCase 'D34c' 'Cleanup command parses with the Windows PowerShell 5.1 parser' {
    $command = Get-TMPCCleanupCommand
    Assert-TestTrue (-not $command.Contains('"')) 'cleanup command must not contain double quotes'
    Assert-TestTrue ($command.Length -lt 30000) 'cleanup command must fit the task argument budget'
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseInput($command, [ref]$tokens, [ref]$errors) | Out-Null
    Assert-TestEqual 0 @($errors).Count 'the cleanup command must be syntactically valid'
}

function New-TestAclSnapshot {
    param(
        [bool]$IsContainer,
        [string]$OwnerSid = 'S-1-5-18',
        [string]$UserRights = 'ReadAndExecute, Synchronize',
        [System.IO.FileAttributes]$Attributes = [System.IO.FileAttributes]::Normal
    )
    $rightsValue = [int][System.Security.AccessControl.FileSystemRights]$UserRights
    return [pscustomobject]@{
        Path        = 'C:\Test'
        Exists      = $true
        IsContainer = $IsContainer
        Attributes  = $Attributes
        OwnerSid    = $OwnerSid
        Rules       = @(
            [pscustomobject]@{ Identity = 'S-1-5-18'; Rights = 'FullControl'; RightsValue = 2032127; Type = 'Allow' },
            [pscustomobject]@{ Identity = 'S-1-5-32-544'; Rights = 'FullControl'; RightsValue = 2032127; Type = 'Allow' },
            [pscustomobject]@{ Identity = 'S-1-5-32-545'; Rights = $UserRights; RightsValue = $rightsValue; Type = 'Allow' }
        )
    }
}

Invoke-TMPCTestCase 'D35' 'Diagnostic ACL: owner and effective write rights are enforced' {
    $directory = New-TestAclSnapshot -IsContainer $true -Attributes ([System.IO.FileAttributes]::Directory)
    $file = New-TestAclSnapshot -IsContainer $false
    Assert-TestTrue (Test-TMPCDiagnosticAclSnapshot -DirectorySnapshot $directory -FileSnapshot $file) 'trusted SYSTEM ACL'

    $unsafeDirectory = New-TestAclSnapshot -IsContainer $true -UserRights 'Modify' -Attributes ([System.IO.FileAttributes]::Directory)
    Assert-TestTrue (-not (Test-TMPCDiagnosticAclSnapshot -DirectorySnapshot $unsafeDirectory -FileSnapshot $file)) 'directory Modify is unsafe'

    $unsafeFile = New-TestAclSnapshot -IsContainer $false -UserRights 'Write'
    Assert-TestTrue (-not (Test-TMPCDiagnosticAclSnapshot -DirectorySnapshot $directory -FileSnapshot $unsafeFile)) 'file write is unsafe'

    $untrustedOwner = New-TestAclSnapshot -IsContainer $false -OwnerSid 'S-1-1-0'
    Assert-TestTrue (-not (Test-TMPCDiagnosticAclSnapshot -DirectorySnapshot $directory -FileSnapshot $untrustedOwner)) 'untrusted owner is rejected'

    $reparse = New-TestAclSnapshot -IsContainer $false -Attributes ([System.IO.FileAttributes]::ReparsePoint)
    Assert-TestTrue (-not (Test-TMPCDiagnosticAclSnapshot -DirectorySnapshot $directory -FileSnapshot $reparse)) 'reparse point is rejected'
    Assert-TestTrue (-not (Test-TMPCDiagnosticAclSnapshot -DirectorySnapshot $null -FileSnapshot $file)) 'missing ACL snapshot is rejected'

    # Numeric masks are authoritative: a deceptive friendly name cannot hide
    # an effective Modify grant, and a missing mask fails closed.
    $masked = New-TestAclSnapshot -IsContainer $true -Attributes ([System.IO.FileAttributes]::Directory)
    $masked.Rules[2].Rights = 'ReadAndExecute, Synchronize'
    $masked.Rules[2].RightsValue = [int][System.Security.AccessControl.FileSystemRights]::Modify
    Assert-TestTrue (-not (Test-TMPCDirectoryAclSnapshot -Snapshot $masked)) 'effective Modify mask is rejected despite a read-only label'
    $masked.Rules[2].RightsValue = [int][System.Security.AccessControl.FileSystemRights]::ReadAndExecute
    Assert-TestTrue (Test-TMPCDirectoryAclSnapshot -Snapshot $masked) 'read-only mask is accepted'
    $masked.Rules[2].PSObject.Properties.Remove('RightsValue')
    Assert-TestTrue (-not (Test-TMPCDirectoryAclSnapshot -Snapshot $masked)) 'missing numeric mask fails closed'
}

Invoke-TMPCTestCase 'D35b' 'Summary schema: required fields and phase consistency' {
    $summary = New-TestH03Summary -SystemPhase 'SUCCESS' -HkcUserPhase 'SUCCESS'
    Assert-TestTrue (Test-TMPCSetupSummarySchema -Summary $summary) 'valid summary'

    $missing = New-TestH03Summary -SystemPhase 'SUCCESS' -HkcUserPhase 'SUCCESS'
    $missing.PSObject.Properties.Remove('ExecutionId')
    Assert-TestTrue (-not (Test-TMPCSetupSummarySchema -Summary $missing)) 'missing execution id'

    $revision = New-TestH03Summary -SystemPhase 'SUCCESS' -HkcUserPhase 'SUCCESS'
    $revision.Revision = 'R1-local'
    Assert-TestTrue (-not (Test-TMPCSetupSummarySchema -Summary $revision)) 'incompatible revision'
    $contradiction = New-TestH03Summary -SystemPhase 'SUCCESS' -HkcUserPhase 'FAILED'
    $contradiction.OverallStatus = 'SUCCESS'
    Assert-TestTrue (-not (Test-TMPCSetupSummarySchema -Summary $contradiction)) 'overall status contradiction'

    $systemErrors = New-TestH03Summary -SystemPhase 'SUCCESS' -HkcUserPhase 'SUCCESS'
    $systemErrors.SystemHadErrors = $true
    Assert-TestTrue (-not (Test-TMPCSetupSummarySchema -Summary $systemErrors)) 'SYSTEM success with errors'

    $systemSubstatus = New-TestH03Summary -SystemPhase 'SUCCESS' -HkcUserPhase 'SUCCESS'
    $systemSubstatus.BloatStatus = 'FAILED'
    Assert-TestTrue (-not (Test-TMPCSetupSummarySchema -Summary $systemSubstatus)) 'SYSTEM success with failed substatus'

    $hkcErrors = New-TestH03Summary -SystemPhase 'SUCCESS' -HkcUserPhase 'FAILED'
    $hkcErrors.HkcHadErrors = $false
    Assert-TestTrue (-not (Test-TMPCSetupSummarySchema -Summary $hkcErrors)) 'HKCU failure without error marker'

    $hkcDeferred = New-TestH03Summary -SystemPhase 'SUCCESS' -HkcUserPhase 'DEFERRED'
    $hkcDeferred.HkcDeferred = $false
    Assert-TestTrue (-not (Test-TMPCSetupSummarySchema -Summary $hkcDeferred)) 'HKCU deferral without deferral marker'

    $attempts = New-TestH03Summary -SystemPhase 'SUCCESS' -HkcUserPhase 'SUCCESS'
    $attempts.CleanupAttempts = -1
    Assert-TestTrue (-not (Test-TMPCSetupSummarySchema -Summary $attempts)) 'negative cleanup attempts'

    $hkcAttempts = New-TestH03Summary -SystemPhase 'SUCCESS' -HkcUserPhase 'SUCCESS'
    $hkcAttempts.HkcAttempts = 0
    Assert-TestTrue (-not (Test-TMPCSetupSummarySchema -Summary $hkcAttempts)) 'successful HKCU phase with zero attempts'

    $hkcOutcome = New-TestH03Summary -SystemPhase 'SUCCESS' -HkcUserPhase 'SUCCESS'
    $hkcOutcome.HkcOutcome = 'TRANSIENT'
    Assert-TestTrue (-not (Test-TMPCSetupSummarySchema -Summary $hkcOutcome)) 'successful HKCU phase with a non-success outcome'

    $exhausted = New-TestH03Summary -SystemPhase 'SUCCESS' -HkcUserPhase 'FAILED'
    $exhausted.HkcRetryExhausted = $true
    $exhausted.HkcAttempts = 3
    Assert-TestTrue (Test-TMPCSetupSummarySchema -Summary $exhausted) 'exhausted HKCU failure is valid'
    $exhausted.HkcUserPhase = 'SUCCESS'
    $exhausted.HkcAttempts = 1
    Assert-TestTrue (-not (Test-TMPCSetupSummarySchema -Summary $exhausted)) 'exhausted flag on success is rejected'

    $missingHkc = New-TestH03Summary -SystemPhase 'SUCCESS' -HkcUserPhase 'SUCCESS'
    $missingHkc.PSObject.Properties.Remove('HkcOutcome')
    Assert-TestTrue (-not (Test-TMPCSetupSummarySchema -Summary $missingHkc)) 'missing HKCU outcome is rejected'

    $timestamp = New-TestH03Summary -SystemPhase 'SUCCESS' -HkcUserPhase 'SUCCESS'
    $timestamp.TimestampUtc = 'not-a-date'
    Assert-TestTrue (-not (Test-TMPCSetupSummarySchema -Summary $timestamp)) 'invalid timestamp'

    $pending = New-TestH03Summary -SystemPhase 'PENDING' -HkcUserPhase 'PENDING'
    Assert-TestTrue (-not (Test-TMPCSetupSummarySchema -Summary $pending)) 'interrupted SYSTEM phase is rejected'
}

Invoke-TMPCTestCase 'D35c' 'Execution identity: summary must match protected HKLM id' {
    $summary = New-TestH03Summary -SystemPhase 'SUCCESS' -HkcUserPhase 'SUCCESS'
    Assert-TestTrue (Test-TMPCSetupExecutionIdentity -Summary $summary -RegistryExecutionId $script:TestExecutionId) 'matching execution id'
    Assert-TestTrue (Test-TMPCSetupExecutionIdentity -Summary $summary -RegistryExecutionId $script:TestExecutionId.ToUpperInvariant()) 'case-insensitive execution id'
    Assert-TestTrue (-not (Test-TMPCSetupExecutionIdentity -Summary $summary -RegistryExecutionId '22222222-2222-2222-2222-222222222222')) 'different execution id'
    Assert-TestTrue (-not (Test-TMPCSetupExecutionIdentity -Summary $summary -RegistryExecutionId 'INVALID')) 'invalidated execution id'
    Assert-TestTrue (-not (Test-TMPCSetupExecutionIdentity -Summary $summary -RegistryExecutionId $null)) 'missing registry execution id'
}

Invoke-TMPCTestCase 'D35d' 'One-shot task state: present, absent verified and unknown' {
    Assert-TestEqual 'PRESENT' (Resolve-TMPCCleanupTaskState -QuerySucceeded $true -TaskFound $true -ErrorIsNotFound $false) 'present task'
    Assert-TestEqual 'UNKNOWN' (Resolve-TMPCCleanupTaskState -QuerySucceeded $true -TaskFound $false -ErrorIsNotFound $false) 'unexpected null is unknown'
    Assert-TestEqual 'ABSENT_VERIFIED' (Resolve-TMPCCleanupTaskState -QuerySucceeded $false -TaskFound $false -ErrorIsNotFound $true) 'not-found error is verified absence'
    Assert-TestEqual 'UNKNOWN' (Resolve-TMPCCleanupTaskState -QuerySucceeded $false -TaskFound $false -ErrorIsNotFound $false) 'access error is unknown'
}

Invoke-TMPCTestCase 'D35e' 'Cleanup decision: ACL, schema, identity, status and task state' {
    $directory = New-TestAclSnapshot -IsContainer $true -Attributes ([System.IO.FileAttributes]::Directory)
    $file = New-TestAclSnapshot -IsContainer $false
    $summary = New-TestH03Summary -SystemPhase 'SUCCESS' -HkcUserPhase 'SUCCESS'
    Assert-TestEqual 'ALLOW' (Get-TMPCCleanupDecision -Summary $summary -RegistryExecutionId $script:TestExecutionId -DirectoryAcl $directory -FileAcl $file -TaskState 'ABSENT_VERIFIED') 'all conditions allow cleanup'
    Assert-TestEqual 'RETRY' (Get-TMPCCleanupDecision -Summary $summary -RegistryExecutionId $script:TestExecutionId -DirectoryAcl $directory -FileAcl $file -TaskState 'PRESENT') 'present task retries'
    Assert-TestEqual 'RETRY' (Get-TMPCCleanupDecision -Summary $summary -RegistryExecutionId $script:TestExecutionId -DirectoryAcl $directory -FileAcl $file -TaskState 'UNKNOWN') 'unknown task retries'
    Assert-TestEqual 'STOP' (Get-TMPCCleanupDecision -Summary $summary -RegistryExecutionId $script:TestExecutionId -DirectoryAcl $directory -FileAcl (New-TestAclSnapshot -IsContainer $false -UserRights 'Modify') -TaskState 'ABSENT_VERIFIED') 'unsafe ACL stops'
    Assert-TestEqual 'STOP' (Get-TMPCCleanupDecision -Summary $summary -RegistryExecutionId '22222222-2222-2222-2222-222222222222' -DirectoryAcl $directory -FileAcl $file -TaskState 'ABSENT_VERIFIED') 'execution mismatch stops'
    $partial = New-TestH03Summary -SystemPhase 'PARTIAL_SUCCESS' -HkcUserPhase 'SUCCESS'
    Assert-TestEqual 'STOP' (Get-TMPCCleanupDecision -Summary $partial -RegistryExecutionId $script:TestExecutionId -DirectoryAcl $directory -FileAcl $file -TaskState 'ABSENT_VERIFIED') 'non-success overall stops'
}

function Read-TMPCSetupSummary { return $script:TestSummaryObject }
function Write-TMPCSetupSummary {
    param([hashtable]$Values, [switch]$Reset)
    $script:TestSummaryObject.HkcUserPhase = 'FAILED'
    $script:TestSummaryObject.HkcHadErrors = $false
    $script:TestSummaryObject.OverallStatus = 'SUCCESS'
    return 'test-summary'
}
function Get-TMPCSetupExecutionId { return [string]$script:TestExecutionId }

Invoke-TMPCTestCase 'D35f' 'Summary write-back: inconsistent persisted state is rejected' {
    $script:TestSummaryObject = New-TestH03Summary -SystemPhase 'SUCCESS' -HkcUserPhase 'PENDING'
    Assert-TestThrows { Update-TMPCUserPhaseSummary -Phase 'FAILED' -HadErrors $false -Deferred $false } 'schema verification failed' 'read-back inconsistency must fail'
}

$productionFunctions = New-TMPCFunctionsScriptBlock -Text $sysText -Names $xmlRegistryFunctions
. $productionFunctions
. (Join-Path $script:TestsRoot 'TMPC.Tests.Helpers.ps1')

Invoke-TMPCTestCase 'D29' 'XML registry: default value and REG_BINARY use exact bytes' {
    $script:CustomizationHadErrors = $false
    Set-TestRegistryValue -Path 'HKCU:\TMPC-XML' -Name '' -Kind String -Value 'legacy'
    Set-RegistryValue -Path 'HKCU:\TMPC-XML' -Name '(Default)' -Type 'String' -Value '' -Description 'default value probe'
    Assert-TestEqual 1 $script:TestWriteAttempts.Count 'one default-value write expected'
    Assert-TestTrue ($script:TestWriteAttempts[0].EndsWith('||String')) 'the default write must use the empty value name'
    $defaultEntry = Get-TestRegistryValue -Path 'HKCU:\TMPC-XML' -Name ''
    Assert-TestTrue ($null -ne $defaultEntry) 'the unnamed default value must exist'
    Assert-TestEqual '' $defaultEntry.Value 'the default value must be applied'
    Assert-TestTrue ($null -eq (Get-TestRegistryValue -Path 'HKCU:\TMPC-XML' -Name '(Default)')) 'no literal (Default) value may be created'

    Set-RegistryValue -Path 'HKCU:\TMPC-XML' -Name '(Default)' -Type 'String' -Value '' -Description 'default value probe'
    Assert-TestEqual 1 $script:TestWriteAttempts.Count 'the default value must be idempotent'

    Set-TestRegistryValue -Path 'HKCU:\TMPC-XML' -Name 'link' -Kind Binary -Value ([byte[]](0x00,0x01))
    Set-RegistryValue -Path 'HKCU:\TMPC-XML' -Name 'link' -Type 'Binary' -Value @(0x15,0x00,0x00,0x00) -Description 'binary probe'
    Assert-TestEqual 2 $script:TestWriteAttempts.Count 'one binary write expected'
    $binaryEntry = Get-TestRegistryValue -Path 'HKCU:\TMPC-XML' -Name 'link'
    Assert-TestTrue ($null -ne $binaryEntry) 'the binary value must exist'
    Assert-TestEqual ([Microsoft.Win32.RegistryValueKind]::Binary) $binaryEntry.Kind 'the binary kind must be preserved'
    Assert-TestTrue ($binaryEntry.Value -is [byte[]]) 'the stored binary value must be a byte[]'
    Assert-TestEqual 4 $binaryEntry.Value.Length 'the exact binary length must be stored'
    Assert-TestEqual 0x15 $binaryEntry.Value[0] 'byte 0 must match'
    Assert-TestEqual 0x00 $binaryEntry.Value[1] 'byte 1 must match'
    Assert-TestEqual 0x00 $binaryEntry.Value[2] 'byte 2 must match'
    Assert-TestEqual 0x00 $binaryEntry.Value[3] 'byte 3 must match'

    Set-RegistryValue -Path 'HKCU:\TMPC-XML' -Name 'link' -Type 'Binary' -Value @(0x15,0x00,0x00,0x00) -Description 'binary probe'
    Assert-TestEqual 2 $script:TestWriteAttempts.Count 'the binary value must be idempotent'

    Set-TestRegistryValue -Path 'HKCU:\TMPC-XML' -Name 'Word' -Kind String -Value '1'
    Set-RegistryValue -Path 'HKCU:\TMPC-XML' -Name 'Word' -Type 'DWord' -Value 1 -Description 'non-binary probe'
    $wordEntry = Get-TestRegistryValue -Path 'HKCU:\TMPC-XML' -Name 'Word'
    Assert-TestEqual ([Microsoft.Win32.RegistryValueKind]::DWord) $wordEntry.Kind 'non-binary types must keep their kind'
    Assert-TestEqual 1 $wordEntry.Value 'non-binary values must keep their value'
    Assert-TestEqual $false $script:CustomizationHadErrors 'no registry error expected'
}

Invoke-TMPCTestCase 'D29b' 'XML registry: binary post-write verification failure is a real error' {
    $script:CustomizationHadErrors = $false
    $script:TestCorruptAfterWrite = $true
    Set-RegistryValue -Path 'HKCU:\TMPC-XML' -Name 'link' -Type 'Binary' -Value @(0x15,0x00,0x00,0x00) -Description 'corrupted binary probe'
    Assert-TestTrue $script:CustomizationHadErrors 'a corrupted binary write must set the error flag'
    Assert-TestLogContains 'VERIFY_FAILED'
}

Invoke-TMPCTestCase 'D29c' 'XML GetValueNames model: empty string is the default; other names unchanged' {
    Assert-TestTrue (Test-RegistryValueName -ValueNames @('', 'Alpha') -Name '(Default)') 'the alias must map to the empty default name'
    Assert-TestTrue (Test-RegistryValueName -ValueNames @('', 'Alpha') -Name '') 'the empty name must map to the default value'
    Assert-TestTrue (Test-RegistryValueName -ValueNames @('', 'Alpha') -Name 'Alpha') 'normal names must be preserved'
    Assert-TestTrue (-not (Test-RegistryValueName -ValueNames @('(Default)') -Name '(Default)')) 'a literal "(Default)" value must not be mistaken for the default'
    Assert-TestTrue (-not (Test-RegistryValueName -ValueNames @('') -Name $null)) 'a null probe must not be treated as a value'
    Assert-TestTrue (-not (Test-RegistryValueName -ValueNames @('') -Name '(Default)Value')) 'similar names must not be rewritten'
}

# ---------------------------------------------------------------------------
# Phase 4b: H01 network restore, H04 bounded retries, H07 NetFx3
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '--- Phase 4b: H01/H04/H07 hardening ---'

$networkFunctions = @(
    'Test-TMPCPrivilegedSid','Get-TMPCNetworkAdapterGuid','Get-TMPCNetworkDisablePlan',
    'Get-TMPCNetworkRestorePlan','Test-TMPCNetworkStateSchema','Test-TMPCNetworkStateAclSnapshot',
    'Get-TMPCNetworkFileAclSnapshot','Test-TMPCNetworkPathAclSnapshot',
    'Test-TMPCNetworkRecoveryLocationDecision','Test-TMPCNetworkRecoveryLocation'
)
$productionFunctions = New-TMPCFunctionsScriptBlock -Text $networkText -Names $networkFunctions
. $productionFunctions

Invoke-TMPCTestCase 'D36' 'H01 network: GUID plan preserves preexisting administrative state' {
    $up = [pscustomobject]@{ InterfaceGuid = 'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA'; InterfaceDescription = 'Ethernet'; Status = 'Up'; AdminStatus = 'Up' }
    $wifi = [pscustomobject]@{ InterfaceGuid = 'BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB'; InterfaceDescription = 'Wi-Fi'; Status = 'Disconnected'; AdminStatus = 'Up' }
    $already = [pscustomobject]@{ InterfaceGuid = 'CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC'; InterfaceDescription = 'Disabled NIC'; Status = 'Disabled'; AdminStatus = 'Down' }
    $absent = [pscustomobject]@{ InterfaceGuid = 'DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD'; InterfaceDescription = 'USB NIC'; Status = 'Not Present'; AdminStatus = 'Down' }
    $invalid = [pscustomobject]@{ InterfaceGuid = 'not-a-guid'; InterfaceDescription = 'Invalid'; Status = 'Up'; AdminStatus = 'Up' }
    $plan = Get-TMPCNetworkDisablePlan -Adapters @($up, $wifi, $already, $absent, $invalid)
    Assert-TestEqual 2 @($plan.Selected).Count 'only enabled, present adapters are selected'
    Assert-TestTrue (@($plan.Selected | Where-Object { $_.InterfaceGuid -eq 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' }).Count -eq 1) 'GUID identifies the selected adapter'
    Assert-TestTrue (@($plan.Skipped | Where-Object { $_.Reason -eq 'ALREADY_DISABLED' }).Count -eq 1) 'already disabled adapter is preserved'
    Assert-TestTrue (@($plan.Skipped | Where-Object { $_.Reason -eq 'NOT_PRESENT' }).Count -eq 1) 'not-present adapter is preserved'
    Assert-TestTrue (@($plan.Skipped | Where-Object { $_.Reason -eq 'INVALID_GUID' }).Count -eq 1) 'invalid GUID is never selected'
    Assert-TestEqual 'Up' $plan.Selected[0].PreviousStatus 'previous status is persisted'
}

Invoke-TMPCTestCase 'D36b' 'H01 restore: only TMPC-disabled GUIDs, OOBE gated' {
    $persisted = @(
        [pscustomobject]@{ InterfaceGuid = 'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA'; Description = 'Ethernet'; PreviousStatus = 'Up'; DisableAttempted = $true; DisabledByTmpc = $true; RestoreStatus = 'PENDING' },
        [pscustomobject]@{ InterfaceGuid = 'BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB'; Description = 'Wi-Fi'; PreviousStatus = 'Up'; DisableAttempted = $true; DisabledByTmpc = $true; RestoreStatus = 'PENDING' },
        [pscustomobject]@{ InterfaceGuid = 'CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC'; Description = 'User disabled'; PreviousStatus = 'Disabled'; DisableAttempted = $false; DisabledByTmpc = $false; RestoreStatus = 'NOT_DISABLED' }
    )
    $current = @(
        [pscustomobject]@{ InterfaceGuid = 'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA'; Status = 'Disabled' },
        [pscustomobject]@{ InterfaceGuid = 'BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB'; Status = 'Up' }
    )
    $plan = Get-TMPCNetworkRestorePlan -PersistedAdapters $persisted -CurrentAdapters $current -OobeComplete $true
    Assert-TestEqual 'RESTORE' $plan.Decision 'eligible adapters produce a restore plan'
    Assert-TestEqual 2 @($plan.Actions).Count 'only the two TMPC-guided entries are considered'
    Assert-TestEqual 'ENABLE' @($plan.Actions | Where-Object { $_.InterfaceGuid -eq 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' })[0].Action 'disabled TMPC adapter is enabled'
    Assert-TestEqual 'ALREADY_ENABLED' @($plan.Actions | Where-Object { $_.InterfaceGuid -eq 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' })[0].Action 'user re-enabled adapter is not touched'
    Assert-TestTrue (@($plan.Actions | Where-Object { $_.InterfaceGuid -eq 'cccccccc-cccc-cccc-cccc-cccccccccccc' }).Count -eq 0) 'an adapter that was already disabled is never restored'

    $absentPlan = Get-TMPCNetworkRestorePlan -PersistedAdapters @($persisted[0]) -CurrentAdapters @() -OobeComplete $true
    Assert-TestEqual 'ABSENT' $absentPlan.Actions[0].Action 'missing adapter is not guessed'
    $deferred = Get-TMPCNetworkRestorePlan -PersistedAdapters $persisted -CurrentAdapters $current -OobeComplete $false
    Assert-TestEqual 'DEFER' $deferred.Decision 'OOBE gate defers restore'
}

Invoke-TMPCTestCase 'D36c' 'H01 state: schema, GUID and trusted ACL are enforced' {
    $entry = [pscustomobject]@{ InterfaceGuid = 'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA'; Description = 'Ethernet'; PreviousStatus = 'Up'; DisableAttempted = $true; DisabledByTmpc = $true; RestoreStatus = 'PENDING' }
    $state = [pscustomobject]@{
        SchemaVersion = 1; RequestId = '11111111-1111-1111-1111-111111111111'; Phase = 'DISABLED'
        CreatedUtc = (Get-Date).ToUniversalTime().ToString('o'); UpdatedUtc = (Get-Date).ToUniversalTime().ToString('o'); Adapters = @($entry)
    }
    Assert-TestTrue (Test-TMPCNetworkStateSchema -State $state) 'valid state schema'
    $badBool = $state.PSObject.Copy(); $badBool.Adapters = @([pscustomobject]@{ InterfaceGuid = 'AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA'; Description = 'Ethernet'; PreviousStatus = 'Up'; DisableAttempted = $true; DisabledByTmpc = 'true'; RestoreStatus = 'PENDING' })
    Assert-TestTrue (-not (Test-TMPCNetworkStateSchema -State $badBool)) 'string boolean is rejected'
    $badGuid = $state.PSObject.Copy(); $badGuid.Adapters = @([pscustomobject]@{ InterfaceGuid = 'bad'; Description = 'Ethernet'; PreviousStatus = 'Up'; DisableAttempted = $true; DisabledByTmpc = $true; RestoreStatus = 'PENDING' })
    Assert-TestTrue (-not (Test-TMPCNetworkStateSchema -State $badGuid)) 'invalid GUID is rejected'
    $badPhase = $state.PSObject.Copy(); $badPhase.Phase = 'ENABLE_ALL'
    Assert-TestTrue (-not (Test-TMPCNetworkStateSchema -State $badPhase)) 'unknown phase is rejected'

    $trusted = [pscustomobject]@{ OwnerSid = 'S-1-5-18'; Rules = @([pscustomobject]@{ Identity = 'S-1-5-32-545'; Rights = [int][System.Security.AccessControl.RegistryRights]::ReadKey; Type = 'Allow' }) }
    Assert-TestTrue (Test-TMPCNetworkStateAclSnapshot -Snapshot $trusted) 'read-only users ACL is trusted'
    $untrusted = [pscustomobject]@{ OwnerSid = 'S-1-5-18'; Rules = @([pscustomobject]@{ Identity = 'S-1-5-21-1000-2000-3000-1001'; Rights = [int][System.Security.AccessControl.RegistryRights]::SetValue; Type = 'Allow' }) }
    Assert-TestTrue (-not (Test-TMPCNetworkStateAclSnapshot -Snapshot $untrusted)) 'non-privileged SetValue is rejected'
    $badOwner = [pscustomobject]@{ OwnerSid = 'S-1-5-21-1000-2000-3000-1001'; Rules = @() }
    Assert-TestTrue (-not (Test-TMPCNetworkStateAclSnapshot -Snapshot $badOwner)) 'untrusted owner is rejected'
}

Invoke-TMPCTestCase 'D36d' 'H01 XML: no indiscriminate restore and conditional recovery' {
    Assert-TestTrue ($xmlText.Contains('NetworkGuard.ps1" -Mode Disable')) 'specialize uses the stateful disable guard'
    Assert-TestTrue ($xmlText.Contains('NetworkGuard.ps1" -Mode Restore')) 'first logon uses the stateful restore guard'
    Assert-TestTrue (-not $xmlText.Contains('Get-NetAdapter | Enable-NetAdapter')) 'no indiscriminate enable command remains'
    Assert-TestTrue (-not $xmlText.Contains('Get-NetAdapter | Disable-NetAdapter')) 'no indiscriminate disable command remains'
    Assert-TestTrue ($networkText.Contains('AtLogOn')) 'recovery uses a logon trigger'
    Assert-TestTrue (-not $networkText.Contains('New-ScheduledTaskTrigger -AtStartup')) 'no AtStartup recovery task is created'
    Assert-TestTrue ($networkText.Contains('Test-TMPCNetworkOobeComplete')) 'recovery is conditioned on OOBE completion'
    Assert-TestTrue ($networkText.Contains('Register-TMPCNetworkRecoveryTask')) 'recovery task registration exists only for pending restore'
    Assert-TestTrue ($networkText.Contains('RestoreStatus') -and $networkText.Contains('DisabledByTmpc')) 'restore tracks per-adapter ownership'
}

Invoke-TMPCTestCase 'D36e' 'H01 recovery script: owner, ACL, reparse and substitution gate' {
    $read = [int][System.Security.AccessControl.FileSystemRights]::ReadAndExecute
    $append = [int][System.Security.AccessControl.FileSystemRights]::AppendData
    $write = [int][System.Security.AccessControl.FileSystemRights]::WriteData
    $deleteSub = [int][System.Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles
    function New-NetworkFileSnapshot {
        param([bool]$IsContainer, [int]$Rights, [string]$Owner = 'S-1-5-18', [bool]$Reparse = $false)
        return [pscustomobject]@{
            Path = 'C:\Test'; Exists = $true; IsContainer = $IsContainer
            IsReparse = $Reparse; OwnerSid = $Owner
            Rules = @([pscustomobject]@{ Identity = 'S-1-5-32-545'; Rights = $Rights; Type = 'Allow'; Inherited = $true })
        }
    }
    $ancestor = New-NetworkFileSnapshot -IsContainer $true -Rights $append
    $directory = New-NetworkFileSnapshot -IsContainer $true -Rights $read
    $sourceDir = New-NetworkFileSnapshot -IsContainer $true -Rights $read
    $sourceFile = New-NetworkFileSnapshot -IsContainer $false -Rights $read
    $targetFile = New-NetworkFileSnapshot -IsContainer $false -Rights $read
    $safe = Test-TMPCNetworkRecoveryLocationDecision -AncestorSnapshots @($ancestor) -DirectorySnapshot $directory -SourceDirectorySnapshot $sourceDir -SourceSnapshot $sourceFile -TargetSnapshot $null
    Assert-TestTrue $safe.Safe 'standard create-folder ancestor right is accepted'

    $badAncestor = New-NetworkFileSnapshot -IsContainer $true -Rights $deleteSub
    $unsafe = Test-TMPCNetworkRecoveryLocationDecision -AncestorSnapshots @($badAncestor) -DirectorySnapshot $directory -SourceDirectorySnapshot $sourceDir -SourceSnapshot $sourceFile -TargetSnapshot $null
    Assert-TestEqual 'ANCESTOR_ACL_UNTRUSTED' $unsafe.Reason 'ancestor delete-subtree right is rejected'
    $badDirectory = New-NetworkFileSnapshot -IsContainer $true -Rights $append
    $unsafe = Test-TMPCNetworkRecoveryLocationDecision -AncestorSnapshots @($ancestor) -DirectorySnapshot $badDirectory -SourceDirectorySnapshot $sourceDir -SourceSnapshot $sourceFile -TargetSnapshot $null
    Assert-TestEqual 'DESTINATION_DIRECTORY_UNTRUSTED' $unsafe.Reason 'destination directory append right is rejected'
    $badSource = New-NetworkFileSnapshot -IsContainer $false -Rights $write
    $unsafe = Test-TMPCNetworkRecoveryLocationDecision -AncestorSnapshots @($ancestor) -DirectorySnapshot $directory -SourceDirectorySnapshot $sourceDir -SourceSnapshot $badSource -TargetSnapshot $null
    Assert-TestEqual 'SOURCE_SCRIPT_UNTRUSTED' $unsafe.Reason 'writable source script is rejected'
    $badTarget = New-NetworkFileSnapshot -IsContainer $false -Rights $write
    $unsafe = Test-TMPCNetworkRecoveryLocationDecision -AncestorSnapshots @($ancestor) -DirectorySnapshot $directory -SourceDirectorySnapshot $sourceDir -SourceSnapshot $sourceFile -TargetSnapshot $badTarget
    Assert-TestEqual 'DESTINATION_SCRIPT_UNTRUSTED' $unsafe.Reason 'writable existing destination is rejected'
    $reparse = New-NetworkFileSnapshot -IsContainer $false -Rights $read -Reparse $true
    Assert-TestTrue (-not (Test-TMPCNetworkPathAclSnapshot -Snapshot $reparse -Kind 'File')) 'reparse point is rejected'
    $untrustedOwner = New-NetworkFileSnapshot -IsContainer $false -Rights $read -Owner 'S-1-5-21-1000-2000-3000-1001'
    Assert-TestTrue (-not (Test-TMPCNetworkPathAclSnapshot -Snapshot $untrustedOwner -Kind 'File')) 'unprivileged owner is rejected'
    $missingMask = New-NetworkFileSnapshot -IsContainer $false -Rights $read
    $missingMask.Rules[0].PSObject.Properties.Remove('Rights')
    Assert-TestTrue (-not (Test-TMPCNetworkPathAclSnapshot -Snapshot $missingMask -Kind 'File')) 'missing numeric mask fails closed'

    $preCopy = $networkText.IndexOf('$location = Test-TMPCNetworkRecoveryLocation')
    $copy = $networkText.IndexOf('Copy-Item -LiteralPath $PSCommandPath')
    $postCopy = $networkText.IndexOf('$afterCopy = Test-TMPCNetworkRecoveryLocation')
    $register = $networkText.IndexOf('Register-ScheduledTask -TaskName $script:RecoveryTaskName')
    Assert-TestTrue ($preCopy -ge 0 -and $copy -gt $preCopy -and $postCopy -gt $copy -and $register -gt $postCopy) 'gate runs before copy and before task registration'
    Assert-TestTrue (-not $networkText.Contains('New-Item -Path $script:RecoveryDir')) 'no directory is created before the security gate'
    Assert-TestTrue ($networkText.Contains('unsafeTask') -and $networkText.Contains('Unregister-ScheduledTask')) 'a failed gate removes any older task'
    Assert-TestTrue ($networkText.Contains('Recovery task action does not reference the verified script copy')) 'registered action is verified'
}

$h04Functions = @(
    'Get-TMPCUserPhaseOutcome','Get-TMPCUserRetryDecision','Get-TMPCOperationKey',
    'Test-TMPCAppliedOperation','Add-TMPCAppliedOperation','Initialize-TMPCAppliedOperations',
    'ConvertTo-RegistryValueName','Test-RegistryValueName','Get-RegistryEntryState',
    'Test-RegistryStateEqual','Write-RegistryValue','Get-RegistryErrorReason','Set-RegistryValue'
)
$productionFunctions = New-TMPCFunctionsScriptBlock -Text $sysText -Names $h04Functions
. $productionFunctions
. (Join-Path $script:TestsRoot 'TMPC.Tests.Helpers.ps1')

Invoke-TMPCTestCase 'D37' 'H04 outcome: transient, permanent, deferred and not applicable are distinct' {
    Assert-TestEqual 'SUCCESS' (Get-TMPCUserPhaseOutcome -ExitCode 0 -HadErrors $false -Deferred $false) 'success'
    Assert-TestEqual 'TRANSIENT' (Get-TMPCUserPhaseOutcome -ExitCode 1 -HadErrors $true -Deferred $false) 'exit 1 is transient'
    Assert-TestEqual 'PERMANENT' (Get-TMPCUserPhaseOutcome -ExitCode 3 -HadErrors $true -Deferred $false) 'exit 3 is permanent'
    Assert-TestEqual 'NOT_APPLICABLE' (Get-TMPCUserPhaseOutcome -ExitCode 4 -HadErrors $true -Deferred $false) 'exit 4 is not applicable'
    Assert-TestEqual 'DEFERRED' (Get-TMPCUserPhaseOutcome -ExitCode 2 -HadErrors $false -Deferred $false) 'exit 2 is deferred'
    Assert-TestEqual 'DEFERRED' (Get-TMPCUserPhaseOutcome -ExitCode 0 -HadErrors $false -Deferred $true) 'explicit deferral'
    Assert-TestEqual 'TRANSIENT' (Get-TMPCUserPhaseOutcome -ExitCode 0 -HadErrors $true -Deferred $false) 'errors never become success'
    Assert-TestEqual 'UNKNOWN' (Get-TMPCUserPhaseOutcome -ExitCode 99 -HadErrors $true -Deferred $false) 'unknown exit is not success'
}

Invoke-TMPCTestCase 'D37b' 'H04 retry: bounded, marker-aware and permanent-stop' {
    Assert-TestEqual 'RUN' (Get-TMPCUserRetryDecision -MarkerApplied $false -Attempts 0 -LastOutcome 'PENDING') 'first attempt runs'
    Assert-TestEqual 'RUN' (Get-TMPCUserRetryDecision -MarkerApplied $false -Attempts 2 -LastOutcome 'TRANSIENT') 'third attempt runs'
    Assert-TestEqual 'EXHAUSTED' (Get-TMPCUserRetryDecision -MarkerApplied $false -Attempts 3 -LastOutcome 'TRANSIENT') 'attempt limit stops retries'
    Assert-TestEqual 'STOP_PERMANENT' (Get-TMPCUserRetryDecision -MarkerApplied $false -Attempts 1 -LastOutcome 'PERMANENT') 'permanent error stops retries'
    Assert-TestEqual 'STOP_PERMANENT' (Get-TMPCUserRetryDecision -MarkerApplied $false -Attempts 1 -LastOutcome 'NOT_APPLICABLE') 'not applicable stops retries'
    Assert-TestEqual 'ALREADY_APPLIED' (Get-TMPCUserRetryDecision -MarkerApplied $true -Attempts 3 -LastOutcome 'TRANSIENT') 'verified marker wins over the retry limit'
}

Invoke-TMPCTestCase 'D37c' 'H04 completed operations: a retry does not overwrite completed preferences' {
    $script:TrackAppliedOperations = $true
    $script:CustomizationHadErrors = $false
    $script:AppliedOperationKeys = New-Object 'System.Collections.Generic.HashSet[string]'
    Set-RegistryValue -Path 'HKCU:\TMPC-H04' -Name 'Alpha' -Type 'DWord' -Value 1 -Description 'initial preference'
    $first = Get-TestRegistryValue -Path 'HKCU:\TMPC-H04' -Name 'Alpha'
    Assert-TestTrue ($null -ne $first -and [int]$first.Value -eq 1) 'initial value applied'
    $writesAfterFirst = $script:TestWriteAttempts.Count
    Assert-TestTrue ($writesAfterFirst -ge 2) 'value and completed-operation state were written'
    Set-TestRegistryValue -Path 'HKCU:\TMPC-H04' -Name 'Alpha' -Kind DWord -Value 9
    Set-RegistryValue -Path 'HKCU:\TMPC-H04' -Name 'Alpha' -Type 'DWord' -Value 1 -Description 'retry preference'
    $afterRetry = Get-TestRegistryValue -Path 'HKCU:\TMPC-H04' -Name 'Alpha'
    Assert-TestEqual 9 $afterRetry.Value 'user change is preserved on retry'
    Assert-TestEqual $writesAfterFirst $script:TestWriteAttempts.Count 'completed operation is not rewritten'
    Assert-TestLogContains 'ALREADY_COMPLETED_PREVIOUS_RUN'
    Set-RegistryValue -Path 'HKCU:\TMPC-H04' -Name 'Beta' -Type 'DWord' -Value 2 -Description 'new operation'
    $beta = Get-TestRegistryValue -Path 'HKCU:\TMPC-H04' -Name 'Beta'
    Assert-TestTrue ($null -ne $beta -and [int]$beta.Value -eq 2) 'different operation still applies'
    Assert-TestEqual (Get-TMPCOperationKey -Operation 'SET' -Path 'HKCU:\TMPC-H04' -Name 'Alpha' -Type 'DWord' -Value '1') (Get-TMPCOperationKey -Operation 'SET' -Path 'HKCU:\TMPC-H04' -Name 'Alpha' -Type 'DWord' -Value '1') 'operation key is stable'
    Assert-TestTrue ((Get-TMPCOperationKey -Operation 'SET' -Path 'HKCU:\TMPC-H04' -Name 'Alpha' -Type 'DWord' -Value '1') -ne (Get-TMPCOperationKey -Operation 'SET' -Path 'HKCU:\TMPC-H04' -Name 'Alpha' -Type 'DWord' -Value '2')) 'operation key includes the expected value'
    $script:TrackAppliedOperations = $false
}

$netfxFunctions = @('Get-TMPCNetFx3SourceAssessment','Get-TMPCNetFx3Decision')
$productionFunctions = New-TMPCFunctionsScriptBlock -Text $netfxText -Names $netfxFunctions
. $productionFunctions

Invoke-TMPCTestCase 'D38' 'H07 XML: source suitability and DISM/final-state decisions' {
    $ready = Get-TMPCNetFx3SourceAssessment -Path 'D:\sources\sxs' -DirectoryExists $true -IsReparsePoint $false -FileNames @('microsoft-windows-netfx3-ondemand-package~31bf3856ad364e35~amd64~~.cab','other.cab')
    Assert-TestTrue $ready.Usable 'NetFx3 payload is accepted'
    Assert-TestEqual 'SOURCE_READY' $ready.Status 'ready status'
    $noPayload = Get-TMPCNetFx3SourceAssessment -Path 'D:\sources\sxs' -DirectoryExists $true -IsReparsePoint $false -FileNames @('other.cab')
    Assert-TestTrue (-not $noPayload.Usable) 'unrelated CABs are not a NetFx3 source'
    Assert-TestEqual 'SOURCE_PAYLOAD_MISSING' $noPayload.Status 'payload missing is distinct'
    $missing = Get-TMPCNetFx3SourceAssessment -Path 'D:\sources\sxs' -DirectoryExists $false -IsReparsePoint $false -FileNames @()
    Assert-TestEqual 'SOURCE_NOT_FOUND' $missing.Status 'missing source is distinct'
    $linked = Get-TMPCNetFx3SourceAssessment -Path 'D:\sources\sxs' -DirectoryExists $true -IsReparsePoint $true -FileNames @('microsoft-windows-netfx3-ondemand-package~31bf3856ad364e35~amd64~~.cab')
    Assert-TestEqual 'SOURCE_REPARSE' $linked.Status 'reparse source is rejected'

    Assert-TestEqual 'ALREADY_ENABLED' (Get-TMPCNetFx3Decision -InitialState 'Enabled' -SourceStatus 'SOURCE_READY' -DismExitCode 0 -FinalState 'Enabled' -RestartNeeded $false) 'enabled feature is not reinstalled'
    Assert-TestEqual 'PENDING_REBOOT' (Get-TMPCNetFx3Decision -InitialState 'EnablePending' -SourceStatus 'SOURCE_READY' -DismExitCode 0 -FinalState 'EnablePending' -RestartNeeded $true) 'already staged feature is pending reboot'
    Assert-TestEqual 'SOURCE_UNAVAILABLE' (Get-TMPCNetFx3Decision -InitialState 'Disabled' -SourceStatus 'SOURCE_NOT_FOUND' -DismExitCode 0 -FinalState 'Disabled' -RestartNeeded $false) 'missing source is not a failed install'
    Assert-TestEqual 'APPLIED' (Get-TMPCNetFx3Decision -InitialState 'Disabled' -SourceStatus 'SOURCE_READY' -DismExitCode 0 -FinalState 'Enabled' -RestartNeeded $false) 'final enabled state verifies success'
    Assert-TestEqual 'PENDING_REBOOT' (Get-TMPCNetFx3Decision -InitialState 'Disabled' -SourceStatus 'SOURCE_READY' -DismExitCode 3010 -FinalState 'EnablePending' -RestartNeeded $true) 'DISM 3010 and pending state are distinguished'
    Assert-TestEqual 'FAILED' (Get-TMPCNetFx3Decision -InitialState 'Disabled' -SourceStatus 'SOURCE_READY' -DismExitCode 1603 -FinalState 'Disabled' -RestartNeeded $false) 'failed DISM is a real failure'
    Assert-TestEqual 'FAILED' (Get-TMPCNetFx3Decision -InitialState 'Disabled' -SourceStatus 'SOURCE_READY' -DismExitCode 0 -FinalState 'Disabled' -RestartNeeded $false) 'unverified final state is failure'
    Assert-TestEqual 'NOT_APPLICABLE' (Get-TMPCNetFx3Decision -InitialState 'DisablePending' -SourceStatus 'SOURCE_READY' -DismExitCode 0 -FinalState 'DisablePending' -RestartNeeded $false) 'pending disable is not applicable'
}

$productionFunctions = New-TMPCFunctionsScriptBlock -Text $standaloneText -Names $netfxFunctions
. $productionFunctions

Invoke-TMPCTestCase 'D38b' 'H07 standalone: same decisions and preserved -NetFx3Source' {
    $ready = Get-TMPCNetFx3SourceAssessment -Path 'E:\sources\sxs' -DirectoryExists $true -IsReparsePoint $false -FileNames @('MICROSOFT-WINDOWS-NETFX3-ONDEMAND-PACKAGE~31BF3856AD364E35~AMD64~~.CAB')
    Assert-TestTrue $ready.Usable 'case-insensitive NetFx3 payload is accepted'
    Assert-TestEqual 'PENDING_REBOOT' (Get-TMPCNetFx3Decision -InitialState 'Disabled' -SourceStatus 'SOURCE_READY' -DismExitCode 3010 -FinalState 'EnablePending' -RestartNeeded $true) 'standalone pending reboot'
    Assert-TestEqual 'SOURCE_UNAVAILABLE' (Get-TMPCNetFx3Decision -InitialState 'Disabled' -SourceStatus 'SOURCE_PAYLOAD_MISSING' -DismExitCode 0 -FinalState 'Disabled' -RestartNeeded $false) 'standalone source unavailable'
    Assert-TestEqual 'ALREADY_ENABLED' (Get-TMPCNetFx3Decision -InitialState 'Enabled' -SourceStatus 'SOURCE_READY' -DismExitCode 0 -FinalState 'Enabled' -RestartNeeded $false) 'standalone enabled'
    Assert-TestTrue ($standaloneText.Contains('-NetFx3Source')) 'standalone parameter preserved'
    Assert-TestTrue ($standaloneText.Contains('Invoke-TMPCNetFx3 -SourcePath $NetFx3Source')) 'standalone uses the verified helper'
    Assert-TestTrue ($standaloneText.Contains('Enable-WindowsOptionalFeature') -and $standaloneText.Contains('-NoRestart')) 'standalone never restarts automatically'
    Assert-TestTrue ($netfxText.Contains('dism.exe') -and $netfxText.Contains('/LimitAccess') -and $netfxText.Contains('/NoRestart')) 'XML DISM uses a local source without reboot'
    Assert-TestTrue ($netfxText.Contains('LASTEXITCODE') -and $netfxText.Contains('Get-TMPCNetFx3FeatureState')) 'DISM exit code and final state are checked'
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
