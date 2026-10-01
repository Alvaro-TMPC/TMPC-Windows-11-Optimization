#Requires -Version 5.1
<#
.SYNOPSIS
    Apply-TMPCOptimizations.ps1 - TMPC profile for an existing Windows installation.
.DESCRIPTION
    Full mode (default): system profile, curated debloat, OneDrive removal and
    current-user preferences when the desktop identity can be verified.
    UserOnly: current-user preferences, without elevation or global changes.
    WARNING: modifies system configuration and removes the baseline apps.
    Review this file and back up your data before use. No automatic restart.
.PARAMETER UserOnly
    Reapply preferences to the account executing this script (including new accounts).
.PARAMETER Restart
    Request a restart with 60 seconds notice, only after a run without errors.
    Not accepted with UserOnly; sign out or restart manually in that mode.
.PARAMETER NetFx3Source
    Optional local sources\sxs directory from matching Windows media. No download.
.NOTES
    Standalone version: 0.1.0. Source profile: v0.1.5.
    Reference validated for the clean-install baseline: Windows 11 Pro 25H2 x64.
    This standalone has STATIC validation only; NO_RUNTIME_VALIDATION.
    Restricted to Windows 11 25H2 (build 26200), native AMD64 PowerShell 5.1.
    Project: https://github.com/Alvaro-TMPC/TMPC-Windows-11-Optimization
    SOURCE_AUTOUNATTEND_SHA256 = 70D5DA63FEA8078FDA45F8F20FCA82E4A476060DDB5304EDEB3DA8A21CC95FF6
    validate-baseline.ps1 checks this binding AND the registry/removal inventories.
    Derived from autounattend.xml, including material based on
    memstechtips/UnattendedWinstall, revision cca752363772a845eb0fed9d3a5b89b5d0a10d20.
    Historical attribution: https://github.com/memstechtips/Autounattend
    Copyright (c) 2026 Alvaro-TMPC
    Copyright (c) 2025 Marco du Plessis (memstechtips)

    MIT License (applies to this file and incorporated upstream portions):
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:
    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.

    COVERAGE MATRIX (source XML line ranges; all functional blocks accounted for):
    6-69,82-106: SETUP_ONLY_NOT_APPLICABLE: empty passes, windowsPE LabConfig hardware
      bypasses, ProductKey/EULA, BypassNRO, OOBE screens/ProtectYourPC and network
      disable/enable. No Setup simulation, accounts, activation or disk operations.
    70-75: REQUIRES_DIFFERENT_POST_INSTALL_IMPLEMENTATION: NetFx3 uses an explicit
      local source + LimitAccess + NoRestart; missing source is a reported limitation.
    76-81,108-239,401-532,890-902,1405-1438: ORCHESTRATION_NOT_NEEDED: extraction,
      Setup logging, generated child files, elevation wrappers and identity helpers.
    240-398: POST_INSTALL_INCLUDE / USER_ONLY_INCLUDE: registry helpers; same
      values and binary masks, errors counted instead of a Setup fail-open result.
    533-888: REQUIRES_DIFFERENT_POST_INSTALL_IMPLEMENTATION: same package,
      capability, optional-feature and special-app lists; sequential, checked,
      NoRestart. OneNote desktop uninstall deferred (see below), no process kill.
    903-1403: REQUIRES_DIFFERENT_POST_INSTALL_IMPLEMENTATION: OneDrive AppX,
      uninstaller, registry, namespace, tasks, default hive and software remnants.
      Strict allowlist, no reparse traversal, correct user only; retain ALL content
      in %USERPROFILE%\OneDrive. No takeown, recursive ACL grants or reboot deletes.
    1440-1733: POST_INSTALL_INCLUDE: Balanced, hibernation/Fast Startup, Spooler,
      Game DVR/Xbox services, telemetry tasks, Defender notification policy, UAC,
      privacy, permissions, AI, sound, Update/Store, Explorer, Start and Taskbar.
      HKCR deletions adapt to HKLM\Software\Classes (original SYSTEM context).
      PreventDeviceEncryption does NOT decrypt an already encrypted device.
      ConfigureStartPins retains EXACT applyOnce JSON; existing pins may remain.
      Windows 10 layout branch is SETUP_ONLY_NOT_APPLICABLE on this target.
    1736-2057,2654-2698: ORCHESTRATION_NOT_NEEDED: empty extension hooks,
      SYSTEM token duplication, retries, one-shot/marker/recovery, final Setup
      cleanup and forced restart. Direct invocation, persistent logs, optional Restart.
    2058-2651: USER_ONLY_INCLUDE: ALL HKCU preferences: gaming, binary visual
      effects, accessibility shortcuts, notifications, Quiet Hours COM + recognized
      CloudStore fallback, privacy/AI, sound, Update/Store, Explorer/Downloads,
      Start/Taskbar, dark theme and wallpaper/cache values. No Bags/BagMRU reset.
    NOT_SAFE_OR_NOT_EQUIVALENT_WITHOUT_NEW_DECISION: arbitrary OneNote desktop
      uninstall strings (could affect an existing Office installation), forced
      termination of apps with unsaved work, unverified user-context OneDrive
      uninstall under a different elevated account, linked software-remnant paths.
      These are deferred with warnings/errors, never represented as equivalent.
      Setup used SYSTEM; this standalone uses an administrator. Protected keys
      or in-use packages can fail on an existing PC; no ACL takeover is added.

    Exit codes: 0 completed (warnings may describe limitations); 1 operation/log
    failure; 2 preflight failure; 3 system phase finished but UserOnly still needed.
    Restart required/recommended is reported separately, not encoded as success.
#>
[CmdletBinding()]
param(
    [switch]$UserOnly,
    [switch]$Restart,
    [string]$NetFx3Source
)

$ErrorActionPreference = 'Stop'
$script:Completed = 0
$script:Warnings = 0
$script:Errors = 0
$script:RestartNeeded = $false
$script:UserDeferred = $false
$script:LogPath = $null
$script:Mode = if ($UserOnly) { 'UserOnly' } else { 'Full' }

function Write-Log {
    param([string]$Message, [ValidateSet('INFO','SUCCESS','WARNING','ERROR')][string]$Level = 'INFO')
    switch ($Level) {
        'SUCCESS' { $script:Completed++ }
        'WARNING' { $script:Warnings++ }
        'ERROR' { $script:Errors++ }
    }
    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    if ($script:LogPath) {
        # Logs contain operation identifiers, not user names, SIDs, uninstall
        # strings, registry blobs or personal paths/error payloads.
        Add-Content -LiteralPath $script:LogPath -Value $line -Encoding UTF8 -ErrorAction Stop
    }
}

function Invoke-Operation {
    param([string]$Name, [scriptblock]$Action)
    try {
        & $Action | Out-Null
        Write-Log $Name 'SUCCESS'
    } catch {
        # Avoid logging raw exception messages from user-controlled paths/registry.
        Write-Log ("{0} failed ({1}, HRESULT 0x{2:X8}); inspect this operation locally." -f $Name, $_.Exception.GetType().Name, $_.Exception.HResult) 'ERROR'
    }
}

function Invoke-Native {
    param([string]$File, [string[]]$Arguments)
    & $File @Arguments 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Native operation returned $LASTEXITCODE" }
}

function Test-CurrentDesktopIdentity {
    # No impersonation: every Explorer in this process's session must belong
    # to this exact SID. Same-account UAC elevation passes; alternate credentials
    # and missing/ambiguous desktop identity fail closed for HKCU and user cleanup.
    try {
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        $session = [Diagnostics.Process]::GetCurrentProcess().SessionId
        $desktop = @(Get-CimInstance Win32_Process -Filter "Name = 'explorer.exe'" |
            Where-Object { $_.SessionId -eq $session })
        if ($desktop.Count -eq 0) { return $false }
        foreach ($process in $desktop) {
            $owner = Invoke-CimMethod -InputObject $process -MethodName GetOwnerSid
            if ($owner.ReturnValue -ne 0 -or $owner.Sid -ne $sid) { return $false }
        }
        return $true
    } catch { return $false }
}

# Registry inventory format: [absolute provider path], then Name|Type|Value.
# !Name removes a value; !KEY removes the current registry key. This is DATA,
# never evaluated as PowerShell. Preserve exact baseline names/types/values.
function Get-SystemRegistryProfile {
    return @'
[HKLM:\SYSTEM\CurrentControlSet\Control\Power]
HibernateEnabled|DWord|0
[HKLM:\SYSTEM\ControlSet001\Control\Session Manager\Power]
HiberbootEnabled|DWord|0
[HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings]
ShowHibernateOption|DWord|0
ShowLockOption|DWord|1
ShowSleepOption|DWord|0
[HKLM:\SYSTEM\CurrentControlSet\Services\Spooler]
Start|DWord|2
[HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR]
AllowGameDVR|DWord|0
[HKLM:\SYSTEM\CurrentControlSet\Services\XblAuthManager]
Start|DWord|3
[HKLM:\SYSTEM\CurrentControlSet\Services\XblGameSave]
Start|DWord|3
[HKLM:\SYSTEM\CurrentControlSet\Services\XboxNetApiSvc]
Start|DWord|3
[HKLM:\Software\Policies\Microsoft\Windows Defender Security Center\Notifications]
DisableEnhancedNotifications|DWord|1
[HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System]
ConsentPromptBehaviorAdmin|DWord|5
PromptOnSecureDesktop|DWord|1
[HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker]
PreventDeviceEncryption|DWord|1
[HKLM:\Software\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting]
Value|DWord|0
[HKLM:\Software\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots]
Value|DWord|0
[HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance]
MaintenanceDisabled|DWord|0
[HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance]
fAllowToGetHelp|DWord|0
[HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon]
DisableLockWorkstation|DWord|0
[HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo]
DisabledByGroupPolicy|DWord|1
[HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization]
AllowInputPersonalization|DWord|0
[HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection]
AllowTelemetry|DWord|0
MaxTelemetryAllowed|DWord|0
[HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection]
AllowTelemetry|DWord|0
DoNotShowFeedbackNotifications|DWord|1
[HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat]
AITEnable|DWord|0
[HKLM:\Software\Policies\Microsoft\Windows\CloudContent]
DisableTailoredExperiencesWithDiagnosticData|DWord|1
DisableWindowsConsumerFeatures|DWord|1
[HKLM:\SOFTWARE\Policies\Microsoft\Windows\System]
PublishUserActivities|DWord|0
EnableActivityFeed|DWord|0
UploadUserActivities|DWord|0
AllowCrossDeviceClipboard|DWord|0
[HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search]
AllowCortana|DWord|0
[HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location]
Value|String|Deny
[HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors]
DisableLocation|DWord|1
[HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userAccountInformation]
Value|String|Deny
[HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\appDiagnostics]
Value|String|Deny
[HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE]
DisablePrivacyExperience|DWord|1
[HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy]
LetAppsAccessAccountInfo|DWord|2
LetAppsAccessCalendar|DWord|2
LetAppsAccessCallHistory|DWord|2
LetAppsAccessContacts|DWord|2
LetAppsAccessEmail|DWord|2
LetAppsAccessMessaging|DWord|2
LetAppsAccessLocation|DWord|2
LetAppsAccessNotifications|DWord|2
LetAppsAccessTasks|DWord|2
LetAppsAccessRadios|DWord|2
LetAppsGetDiagnosticInfo|DWord|2
[HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\systemAIModels]
Value|String|Deny
[HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI]
AllowRecallEnablement|DWord|0
DisableAIDataAnalysis|DWord|1
DisableClickToDo|DWord|1
DisableSettingsAgent|DWord|1
[HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Paint]
DisableCocreator|DWord|1
DisableGenerativeFill|DWord|1
DisableImageCreator|DWord|1
[HKLM:\SOFTWARE\Policies\WindowsNotepad]
DisableAIFeatures|DWord|1
[HKLM:\SOFTWARE\Policies\Microsoft\OneDrive]
KFMBlockOptIn|DWord|1
[HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive]
DisableFileSyncNGSC|DWord|1
[HKLM:\Software\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\BootAnimation]
DisableStartupSound|DWord|0
[HKLM:\Software\Microsoft\Windows\CurrentVersion\EditionOverrides]
UserSetting_DisableStartupSound|DWord|0
[HKLM:\Software\Microsoft\Windows\CurrentVersion\SpeechOneCore\Settings]
AgentActivationEnabled|DWord|0
AgentActivationLastUsed|DWord|0
[HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization]
DODownloadMode|DWord|0
[HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings]
IsContinuousInnovationOptedIn|DWord|0
AllowMUUpdateService|DWord|0
IsExpedited|DWord|0
RestartNotificationsAllowed2|DWord|0
AllowAutoWindowsUpdateDownloadOverMeteredNetwork|DWord|0
[HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU]
NoAutoRebootWithLoggedOnUsers|DWord|1
[HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate]
!SetUpdateNotificationLevel
ExcludeWUDriversInQualityUpdate|DWord|1
[HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore]
AutoDownload|DWord|4
[HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked]
!{9F156763-7844-4DC4-B2B1-901F640F5155}
[HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}]
!KEY
[HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}]
!KEY
[HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}]
!KEY
[HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem]
LongPathsEnabled|DWord|1
[HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer]
HideRecommendedSection|DWord|1
DisableSearchBoxSuggestions|DWord|1
[HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Start]
HideRecommendedSection|DWord|1
ConfigureStartPins|String|{"applyOnce":true,"pinnedList":[]}
[HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer]
HideSCAMeetNow|DWord|1
[HKLM:\Software\Policies\Microsoft\Dsh]
AllowNewsAndInterests|DWord|0
[HKLM:\Software\Policies\Microsoft\Windows\Windows Feeds]
EnableFeeds|DWord|0
'@
}

function Get-UserRegistryProfile {
    return @'
[HKCU:\Software\Microsoft\GameBar]
AutoGameModeEnabled|DWord|1
UseNexusForGameBarEnabled|DWord|0
ShowStartupPanel|DWord|0
[HKCU:\Control Panel\Mouse]
MouseSpeed|String|0
[HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Search\Preferences]
WholeFileSystem|DWord|0
[HKCU:\Control Panel\Desktop]
JPEGImportQuality|DWord|100
MenuShowDelay|String|0
DragFullWindows|String|1
FontSmoothing|String|2
DstNotification|DWord|0
[HKCU:\Software\Microsoft\Windows\DWM]
!CompositionPolicy
EnableAeroPeek|DWord|1
AlwaysHibernateThumbnails|DWord|0
[HKCU:\System\GameConfigStore]
GameDVR_Enabled|DWord|0
[HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR]
AppCaptureEnabled|DWord|0
[HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects]
VisualFXSetting|DWord|3
[HKCU:\Control Panel\Desktop\WindowMetrics]
MinAnimate|String|0
[HKCU:\Software\Microsoft\Narrator\NoRoam]
WinEnterLaunchEnabled|DWord|0
OnlineServicesEnabled|DWord|0
ScriptingEnabled|DWord|0
DuckAudio|DWord|0
[HKCU:\Control Panel\Accessibility\StickyKeys]
Flags|String|2
[HKCU:\Control Panel\Accessibility\Keyboard Response]
Flags|String|2
[HKCU:\Control Panel\Accessibility\ToggleKeys]
Flags|String|34
[HKCU:\Control Panel\Accessibility\MouseKeys]
Flags|String|130
[HKCU:\Control Panel\Accessibility\HighContrast]
Flags|String|98
[HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications]
ToastEnabled|DWord|0
LockScreenToastEnabled|DWord|0
[HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings]
NOC_GLOBAL_SETTING_ALLOW_NOTIFICATION_SOUND|DWord|0
NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK|DWord|0
NOC_GLOBAL_SETTING_ALLOW_CRITICAL_TOASTS_ABOVE_LOCK|DWord|0
[HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.CapabilityAccess]
Enabled|DWord|0
[HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.StartupApp]
Enabled|DWord|0
[HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance]
Enabled|DWord|0
[HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location]
ShowGlobalPrompts|DWord|0
Value|String|Deny
[HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement]
ScoobeSystemSettingEnabled|DWord|0
[HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager]
SubscribedContent-310093Enabled|DWord|0
SubscribedContent-338389Enabled|DWord|0
SystemPaneSuggestionsEnabled|DWord|0
ContentDeliveryAllowed|DWord|0
SubscribedContentEnabled|DWord|0
FeatureManagementEnabled|DWord|0
SoftLandingEnabled|DWord|0
OemPreInstalledAppsEnabled|DWord|0
PreInstalledAppsEnabled|DWord|0
PreInstalledAppsEverEnabled|DWord|0
SilentInstalledAppsEnabled|DWord|0
RotatingLockScreenEnabled|DWord|0
RotatingLockScreenOverlayEnabled|DWord|0
SubscribedContent-338387Enabled|DWord|0
SubscribedContent-338393Enabled|DWord|0
SubscribedContent-353694Enabled|DWord|0
SubscribedContent-353696Enabled|DWord|0
SubscribedContent-353698Enabled|DWord|0
SubscribedContent-338388Enabled|DWord|0
[HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo]
Enabled|DWord|0
[HKCU:\Software\Microsoft\Windows\CurrentVersion\CPSS\Store\AdvertisingInfo]
Value|DWord|0
[HKCU:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo]
DisabledByGroupPolicy|DWord|1
[HKCU:\Control Panel\International\User Profile]
HttpAcceptLanguageOptOut|DWord|1
[HKCU:\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications]
EnableAccountNotifications|DWord|0
[HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy]
HasAccepted|DWord|0
[HKCU:\SOFTWARE\Policies\Microsoft\InputPersonalization]
AllowInputPersonalization|DWord|0
[HKCU:\Software\Microsoft\Windows\CurrentVersion\CPSS\Store\InkingAndTypingPersonalization]
Value|DWord|0
[HKCU:\Software\Microsoft\Personalization\Settings]
AcceptedPrivacyPolicy|DWord|0
[HKCU:\Software\Microsoft\InputPersonalization]
RestrictImplicitTextCollection|DWord|1
RestrictImplicitInkCollection|DWord|1
[HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore]
HarvestContacts|DWord|0
[HKCU:\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack]
ShowedToastAtLevel|DWord|1
[HKCU:\SOFTWARE\Policies\Microsoft\Windows\DataCollection]
AllowTelemetry|DWord|0
DoNotShowFeedbackNotifications|DWord|1
[HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection]
AllowTelemetry|DWord|0
MaxTelemetryAllowed|DWord|0
[HKCU:\SOFTWARE\Policies\Microsoft\Windows\AppCompat]
AITEnable|DWord|0
[HKCU:\Software\Microsoft\Input\TIPC]
Enabled|DWord|0
[HKCU:\Software\Microsoft\Windows\CurrentVersion\CPSS\Store\ImproveInkingAndTyping]
Value|DWord|0
[HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy]
TailoredExperiencesWithDiagnosticDataEnabled|DWord|0
[HKCU:\Software\Policies\Microsoft\Windows\CloudContent]
DisableTailoredExperiencesWithDiagnosticData|DWord|1
[HKCU:\SOFTWARE\Policies\Microsoft\Windows\System]
PublishUserActivities|DWord|0
EnableActivityFeed|DWord|0
UploadUserActivities|DWord|0
[HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings]
IsDeviceSearchHistoryEnabled|DWord|0
IsDynamicSearchBoxEnabled|DWord|0
IsMSACloudSearchEnabled|DWord|0
IsAADCloudSearchEnabled|DWord|0
IsGlobalWebSearchProviderToggleEnabled|DWord|0
[HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\systemAIModels]
Value|String|Deny
[HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userAccountInformation]
Value|String|Deny
[HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\appDiagnostics]
Value|String|Deny
[HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI]
DisableAIDataAnalysis|DWord|1
DisableClickToDo|DWord|1
[HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot]
TurnOffWindowsCopilot|DWord|1
[HKCU:\SOFTWARE\Policies\Microsoft\Windows\Windows Search]
AllowCortana|DWord|0
[HKCU:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors]
DisableLocation|DWord|1
[HKCU:\SOFTWARE\Policies\Microsoft\OneDrive]
KFMBlockOptIn|DWord|1
[HKCU:\Software\Microsoft\Multimedia\Audio]
UserDuckingPreference|DWord|3
[HKCU:\Control Panel\Accessibility]
Sound on Activation|DWord|0
Warning Sounds|DWord|0
[HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU]
NoAutoRebootWithLoggedOnUsers|DWord|1
[HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate]
!SetUpdateNotificationLevel
ExcludeWUDriversInQualityUpdate|DWord|1
[HKCU:\SOFTWARE\Policies\Microsoft\WindowsStore]
AutoDownload|DWord|4
[HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer]
link|Binary|15,00,00,00
IconUnderline|DWord|3
ShowRecent|DWord|0
ShowRecommendations|DWord|0
ShowFrequent|DWord|0
ShowCloudFilesInQuickAccess|DWord|0
EnableAutoTray|DWord|0
[HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32]
(Default)|String|
[HKCU:\Software\Microsoft\Lighting]
AmbientLightingEnabled|DWord|0
ControlledByForegroundApp|DWord|0
[HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows]
LegacyDefaultPrinterMode|DWord|1
[HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState]
FullPath|DWord|1
[HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced]
MultiTaskingAltTabFilter|DWord|3
TaskbarAnimations|DWord|0
IconsOnly|DWord|0
ListviewAlphaSelect|DWord|1
ListviewShadow|DWord|0
ShowNotificationIcon|DWord|0
LaunchTo|DWord|1
AlwaysShowMenus|DWord|0
UseCompactMode|DWord|1
ShowTypeOverlay|DWord|1
!FolderContentsInfoTip
Hidden|DWord|1
!HideDrivesWithNoMedia
HideFileExt|DWord|0
HideMergeConflicts|DWord|0
ShowSuperHidden|DWord|0
SeparateProcess|DWord|0
PersistBrowsers|DWord|0
!ShowDriveLettersFirst
ShowEncryptCompressedColor|DWord|1
ShowInfoTip|DWord|1
ShowPreviewHandlers|DWord|0
ShowStatusBar|DWord|1
ShowSyncProviderNotifications|DWord|0
AutoCheckSelect|DWord|0
SharingWizardOn|DWord|0
TypeAhead|DWord|0
NavPaneShowAllCloudStates|DWord|0
NavPaneExpandToCurrentFolder|DWord|0
NavPaneShowAllFolders|DWord|0
Start_Layout|DWord|1
Start_TrackProgs|DWord|1
Start_TrackDocs|DWord|0
Start_IrisRecommendations|DWord|0
Start_AccountNotifications|DWord|0
TaskbarAl|DWord|0
ShowTaskViewButton|DWord|0
ShowCopilotButton|DWord|0
TaskbarSmallIcons|DWord|1
[HKCU:\Software\Classes\CLSID\{031E4825-7B94-4dc3-B131-E946B44C8DD5}]
System.IsPinnedToNameSpaceTree|DWord|0
[HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer]
HideRecommendedSection|DWord|1
DisableSearchBoxSuggestions|DWord|1
HideSCAMeetNow|DWord|1
[HKCU:\Software\Microsoft\Windows\CurrentVersion\Start]
ShowRecentList|DWord|0
ShowFrequentList|DWord|0
[HKCU:\Software\Microsoft\Windows\CurrentVersion\Search]
SearchboxTaskbarMode|DWord|0
[HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer]
HideSCAMeetNow|DWord|1
[HKCU:\Software\Policies\Microsoft\Dsh]
AllowNewsAndInterests|DWord|0
[HKCU:\Software\Policies\Microsoft\Windows\Windows Feeds]
EnableFeeds|DWord|0
[HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings]
TaskbarEndTask|DWord|1
[HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize]
AppsUseLightTheme|DWord|0
SystemUsesLightTheme|DWord|0
EnableTransparency|DWord|0
'@
}

function Invoke-RegistryProfile {
    param([string]$Text, [ValidateSet('HKLM:','HKCU:')][string]$Hive)
    $path = $null
    foreach ($line in ($Text -split '\r?\n')) {
        if (-not $line) { continue }
        if ($line -match '^\[(.+)\]$') {
            $path = $matches[1]
            if (-not $path.StartsWith($Hive, [StringComparison]::OrdinalIgnoreCase)) { throw 'Registry inventory crossed its hive boundary.' }
            continue
        }
        if (-not $path) { throw 'Missing inventory path.' }
        Invoke-Operation "$path | $line" {
            if ($line -eq '!KEY') {
                if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
            } elseif ($line.StartsWith('!')) {
                $name = $line.Substring(1)
                if (Test-Path -LiteralPath $path) {
                    $key = Get-Item -LiteralPath $path
                    try { $present = $key.GetValueNames() -contains $name } finally { $key.Close() }
                    if ($present) { Remove-ItemProperty -LiteralPath $path -Name $name }
                }
            } else {
                $parts = $line -split '\|', 3
                if ($parts.Count -ne 3) { throw 'Invalid registry inventory.' }
                $value = $parts[2]
                switch ($parts[1]) {
                    'DWord' { $value = [int]$value }
                    'Binary' { $value = [byte[]]@($value.Split(',') | ForEach-Object { [Convert]::ToByte($_,16) }) }
                    'String' { }
                    default { throw 'Unsupported registry type.' }
                }
                if (-not (Test-Path -LiteralPath $path)) { New-Item -Path $path -Force | Out-Null }
                Set-ItemProperty -LiteralPath $path -Name $parts[0] -Type $parts[1] -Value $value -Force
            }
        }
    }
}

function Invoke-UserBinaryPreferences {
    # Exact baseline bit inventory: Path suffix|Name|ByteIndex|BitMask|SetBit.
    $binaryPreferences = @'
Control Panel\Desktop|UserPreferencesMask|4|02|0
Control Panel\Desktop|UserPreferencesMask|0|02|0
Control Panel\Desktop|UserPreferencesMask|1|08|0
Control Panel\Desktop|UserPreferencesMask|1|04|0
Control Panel\Desktop|UserPreferencesMask|1|20|0
Control Panel\Desktop|UserPreferencesMask|2|04|0
Control Panel\Desktop|UserPreferencesMask|0|04|0
Control Panel\Desktop|UserPreferencesMask|0|08|0
Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState|Settings|4|20|0
Software\Microsoft\Windows\CurrentVersion\Explorer|ShellState|4|20|1
'@
    foreach ($line in ($binaryPreferences -split '\r?\n')) {
        Invoke-Operation 'HKCU binary preference (preserve other bits)' {
            $p = $line -split '\|'
            $path = 'HKCU:\' + $p[0]
            $index = [int]$p[2]
            $mask = [Convert]::ToByte($p[3],16)
            if (-not (Test-Path -LiteralPath $path)) { New-Item -Path $path -Force | Out-Null }
            $key = Get-Item -LiteralPath $path
            try { $bytes = $key.GetValue($p[1], $null) } finally { $key.Close() }
            if ($null -eq $bytes) { $bytes = New-Object byte[] ([Math]::Max(12,$index+1)) }
            if ($bytes -isnot [byte[]]) { throw 'Existing binary preference is not binary.' }
            if ($bytes.Length -le $index) {
                $expanded = New-Object byte[] ($index+1)
                [Array]::Copy($bytes,$expanded,$bytes.Length)
                $bytes = $expanded
            }
            if ($p[4] -eq '1') { $bytes[$index] = $bytes[$index] -bor $mask }
            else { $bytes[$index] = $bytes[$index] -band (-bnot $mask) }
            Set-ItemProperty -LiteralPath $path -Name $p[1] -Type Binary -Value $bytes -Force
        }
    }
}

function Invoke-QuietHours {
    # Same experimentally validated COM ABI as the source: slots 3,4,9,
    # CLSCTX_LOCAL_SERVER, LPWStr, CoTaskMem strings and Release in finally.
    Invoke-Operation 'HKCU Do Not Disturb OFF' {
        $nativeOff = $false
        try {
            if (-not ('TMPC.QuietHours' -as [type])) {
                Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace TMPC {
    public static class QuietHours {
        [DllImport("ole32.dll", PreserveSig=true)]
        static extern int CoCreateInstance(ref Guid c, IntPtr outer, uint context, ref Guid i, out IntPtr instance);
        delegate int GetString(IntPtr self, out IntPtr value);
        delegate int PutString(IntPtr self, [MarshalAs(UnmanagedType.LPWStr)] string value);
        public static bool Disable() {
            Guid c = new Guid("F53321FA-34F8-4B7F-B9A3-361877CB94CF");
            Guid i = new Guid("6BFF4732-81EC-4FFB-AE67-B6C1BC29631F");
            IntPtr obj=IntPtr.Zero, before=IntPtr.Zero, off=IntPtr.Zero, after=IntPtr.Zero;
            try {
                if (CoCreateInstance(ref c,IntPtr.Zero,0x4,ref i,out obj)!=0 || obj==IntPtr.Zero) return false;
                IntPtr v = Marshal.ReadIntPtr(obj);
                GetString get=(GetString)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(v,3*IntPtr.Size),typeof(GetString));
                PutString put=(PutString)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(v,4*IntPtr.Size),typeof(PutString));
                GetString getOff=(GetString)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(v,9*IntPtr.Size),typeof(GetString));
                get(obj,out before);
                if (getOff(obj,out off)!=0 || off==IntPtr.Zero) return false;
                string profile=Marshal.PtrToStringUni(off);
                if (String.IsNullOrWhiteSpace(profile)) return false;
                // Always invoke setter, including an initially compact/uninitialized state.
                if (put(obj,profile)!=0 || get(obj,out after)!=0 || after==IntPtr.Zero) return false;
                return String.Equals(profile,Marshal.PtrToStringUni(after),StringComparison.OrdinalIgnoreCase);
            } catch { return false; }
            finally {
                if(before!=IntPtr.Zero) Marshal.FreeCoTaskMem(before);
                if(off!=IntPtr.Zero) Marshal.FreeCoTaskMem(off);
                if(after!=IntPtr.Zero) Marshal.FreeCoTaskMem(after);
                if(obj!=IntPtr.Zero) Marshal.Release(obj);
            }
        }
    }
}
'@
            }
            $nativeOff = [TMPC.QuietHours]::Disable()
        } catch { $nativeOff = $false }
        if ($nativeOff) { return }
        Write-Log 'Native Quiet Hours did not verify OFF; checking recognized CloudStore fallback.' 'WARNING'
        $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current\default$windows.data.donotdisturb.quiethourssettings\windows.data.donotdisturb.quiethourssettings'
        $data = (Get-ItemProperty -LiteralPath $path -Name Data).Data
        if ($data -isnot [byte[]]) { throw 'Unrecognized Quiet Hours data; preserved.' }
        $priority = [Text.Encoding]::Unicode.GetBytes('Microsoft.QuietHoursProfile.PriorityOnly')
        $unrestricted = [Text.Encoding]::Unicode.GetBytes('Microsoft.QuietHoursProfile.Unrestricted')
        for ($i=0; $i -le $data.Length-$priority.Length; $i++) {
            $match = $true
            for ($j=0; $j -lt $priority.Length; $j++) {
                if ($data[$i+$j] -ne $priority[$j]) { $match=$false; break }
            }
            if ($match) {
                [Array]::Copy($unrestricted,0,$data,$i,$unrestricted.Length)
                Set-ItemProperty -LiteralPath $path -Name Data -Type Binary -Value $data -Force
                $data = (Get-ItemProperty -LiteralPath $path -Name Data).Data
                break
            }
        }
        if (-not [Text.Encoding]::Unicode.GetString($data).Contains('Microsoft.QuietHoursProfile.Unrestricted')) {
            throw 'OFF not proven; compact/unknown data preserved.'
        }
    }
}

function Invoke-DownloadsPreference {
    Invoke-Operation 'HKCU Downloads FolderType GroupBy empty (HKLM read-only)' {
        $id = '{885a186e-a440-4ada-812b-db871b942259}'
        $top = 'TopViews\{00000000-0000-0000-0000-000000000000}'
        $source = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderTypes\$id"
        $target = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderTypes\$id"
        $key = Get-Item -LiteralPath "$source\$top"
        try {
            if ($key.GetValueKind('GroupBy') -ne [Microsoft.Win32.RegistryValueKind]::String -or
                $key.GetValue('GroupBy') -ne 'System.DateModified') { throw 'Downloads default does not match 25H2.' }
        } finally { $key.Close() }
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
        Invoke-Native 'reg.exe' @('copy',$source.Replace(':',''),$target.Replace(':',''),'/s','/f')
        Set-ItemProperty -LiteralPath "$target\$top" -Name GroupBy -Type String -Value '' -Force
        $key = Get-Item -LiteralPath "$target\$top"
        try {
            if ($key.GetValueKind('GroupBy') -ne [Microsoft.Win32.RegistryValueKind]::String -or
                $key.GetValue('GroupBy') -ne '') { throw 'Downloads override not verified.' }
        } finally { $key.Close() }
    }
}

function Invoke-UserPhase {
    Invoke-RegistryProfile (Get-UserRegistryProfile) 'HKCU:'
    Invoke-UserBinaryPreferences
    Invoke-QuietHours
    Invoke-DownloadsPreference
    $wallpaper = Join-Path $env:SystemRoot 'Web\Wallpaper\Windows\img19.jpg'
    if (-not (Test-Path -LiteralPath $wallpaper -PathType Leaf)) {
        Write-Log 'Baseline dark wallpaper missing; existing wallpaper preserved.' 'WARNING'
    } else {
        Invoke-Operation 'HKCU baseline dark wallpaper and fit' {
            $path = 'HKCU:\Control Panel\Desktop'
            Set-ItemProperty -LiteralPath $path -Name Wallpaper -Type String -Value $wallpaper -Force
            Set-ItemProperty -LiteralPath $path -Name WallpaperStyle -Type String -Value '10' -Force
            Set-ItemProperty -LiteralPath $path -Name TileWallpaper -Type String -Value '0' -Force
            foreach ($name in @('TranscodedImageCache','TranscodedImageCache_000')) {
                $key = Get-Item -LiteralPath $path
                try { $exists = $key.GetValueNames() -contains $name } finally { $key.Close() }
                if ($exists) { Remove-ItemProperty -LiteralPath $path -Name $name }
            }
        }
    }
    Write-Log 'User preferences written; sign out and back in for shell refresh. Existing saved folder views may override Downloads defaults.'
}

function Invoke-BloatRemoval {
    $packages = @(
        'Microsoft.Microsoft3DViewer','Microsoft.MixedReality.Portal','Microsoft.BingSearch',
        'Microsoft.BingNews','Microsoft.BingWeather','Microsoft.WindowsCamera','Clipchamp.Clipchamp',
        'Microsoft.WindowsAlarms','Microsoft.549981C3F5F10','Microsoft.GetHelp','Microsoft.Windows.DevHome',
        'MicrosoftCorporationII.MicrosoftFamily','microsoft.windowscommunicationsapps','Microsoft.SkypeApp',
        'MSTeams','Microsoft.WindowsFeedbackHub','Microsoft.WindowsMaps','Microsoft.MicrosoftOfficeHub',
        'Microsoft.OutlookForWindows','Microsoft.People','Microsoft.PowerAutomateDesktop',
        'MicrosoftCorporationII.QuickAssist','Microsoft.MicrosoftSolitaireCollection','Microsoft.GamingApp',
        'Microsoft.XboxApp','Microsoft.XboxIdentityProvider','Microsoft.XboxGameOverlay','Microsoft.Xbox.TCUI',
        'Microsoft.XboxGamingOverlay','Microsoft.ZuneMusic','Microsoft.ZuneVideo','Microsoft.WindowsSoundRecorder',
        'Microsoft.MicrosoftStickyNotes','Microsoft.Getstarted','Microsoft.Todos','Microsoft.YourPhone',
        'Microsoft.Copilot','Microsoft.Windows.Ai.Copilot.Provider','Microsoft.Copilot_8wekyb3d8bbwe',
        'Microsoft.Office.OneNote'
    )
    $capabilities = @('Microsoft.Windows.PowerShell.ISE','App.Support.QuickAssist','App.StepsRecorder','Microsoft.Windows.WordPad')
    $optionalFeatures = @('Recall')
    $specialApps = @('OneNote')
    # Store, Edge/WebView2, Photos, Paint and Notepad are deliberately NOT targets.
    $provisioned = @(Get-AppxProvisionedPackage -Online)
    $installed = @(Get-AppxPackage -AllUsers)
    foreach ($package in $packages) {
        foreach ($item in @($provisioned | Where-Object DisplayName -eq $package)) {
            Invoke-Operation "Debloat provisioned $package" {
                Remove-AppxProvisionedPackage -Online -PackageName $item.PackageName | Out-Null
            }
        }
        foreach ($item in @($installed | Where-Object Name -eq $package)) {
            Invoke-Operation "Debloat installed $package" { Remove-AppxPackage -AllUsers -Package $item.PackageFullName }
        }
    }
    $allCaps = @(Get-WindowsCapability -Online)
    foreach ($capability in $capabilities) {
        foreach ($item in @($allCaps | Where-Object { $_.Name -like "$capability*" -and $_.State -eq 'Installed' })) {
            Invoke-Operation "Debloat capability $capability" {
                $result = Remove-WindowsCapability -Online -Name $item.Name
                if ($result.RestartNeeded) { $script:RestartNeeded = $true }
            }
        }
    }
    $features = @(Get-WindowsOptionalFeature -Online)
    foreach ($feature in $optionalFeatures) {
        if (@($features | Where-Object { $_.FeatureName -eq $feature -and $_.State -eq 'Enabled' }).Count -gt 0) {
            Invoke-Operation "Debloat optional feature $feature" {
                $result = Disable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart
                if ($result.RestartNeeded) { $script:RestartNeeded = $true }
            }
        }
    }
    foreach ($app in $specialApps) {
        # Source's registry-driven desktop uninstaller is NOT safely equivalent
        # for an existing Office suite. Keep the exact target; report limitation.
        Write-Log "$app desktop special uninstall deferred; remove separately if present. Its baseline AppX package is targeted above." 'WARNING'
    }
}

function Assert-NoReparsePath {
    param([string]$Path)
    $item = Get-Item -LiteralPath $Path -Force
    while ($item) {
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Linked path preserved.' }
        $parent = Split-Path -Parent $item.FullName
        if (-not $parent -or $parent -eq $item.FullName) { break }
        $item = Get-Item -LiteralPath $parent -Force
    }
}

function Remove-OneDriveRemnant {
    param([string]$Path)
    # Sole filesystem deletion entry point: exact software-remnant allowlist.
    # %USERPROFILE%\OneDrive is NEVER an allowed deletion target.
    $allowed = @(
        (Join-Path $env:ProgramFiles 'Microsoft OneDrive'),
        (Join-Path $env:ProgramData 'Microsoft OneDrive'),
        (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\OneDrive.lnk')
    )
    if ($script:CanApplyUser) {
        $allowed += Join-Path $env:USERPROFILE 'AppData\Local\Microsoft\OneDrive'
        $allowed += Join-Path $env:USERPROFILE 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk'
    }
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $protected = [IO.Path]::GetFullPath((Join-Path $env:USERPROFILE 'OneDrive')).TrimEnd('\')
    if (-not $script:OneDriveProtectionReady) { throw 'Sync-root protection inventory unavailable; remnants preserved.' }
    foreach ($root in $script:ProtectedOneDriveRoots) {
        $sync = [IO.Path]::GetFullPath($root).TrimEnd('\')
        if ($full -eq $sync -or $full.StartsWith($sync+'\',[StringComparison]::OrdinalIgnoreCase) -or
            $sync.StartsWith($full+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Sync-root overlap; personal files preserved.' }
    }
    if ($full -eq $protected -or $full.StartsWith($protected+'\',[StringComparison]::OrdinalIgnoreCase) -or
        $protected.StartsWith($full+'\',[StringComparison]::OrdinalIgnoreCase) -or $allowed -notcontains $full) {
        throw 'Deletion target rejected; OneDrive user data is protected.'
    }
    if (-not (Test-Path -LiteralPath $full)) { return }
    Assert-NoReparsePath $full
    # Inspect one level at a time, BEFORE descending: never traverse a junction.
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $pending.Push($full)
    while ($pending.Count -gt 0) {
        $current = $pending.Pop()
        $item = Get-Item -LiteralPath $current -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Linked remnant preserved.' }
        if ($item.PSIsContainer) {
            foreach ($child in @(Get-ChildItem -LiteralPath $current -Force)) { $pending.Push($child.FullName) }
        }
    }
    Remove-Item -LiteralPath $full -Recurse -Force
    if (Test-Path -LiteralPath $full) { throw 'Software remnant still present.' }
}

function Invoke-OneDriveUninstaller {
    param([string]$RegistryPath, [switch]$Machine)
    if (-not (Test-Path -LiteralPath $RegistryPath)) { return $false }
    $command = (Get-ItemProperty -LiteralPath $RegistryPath -Name UninstallString).UninstallString
    # No cmd.exe, arbitrary registry command or shell expansion. Only the
    # installed OneDriveSetup.exe with baseline uninstall switches is accepted.
    if ($command -notmatch '^"?(.+?OneDriveSetup\.exe)"?\s+(/uninstall(?:\s+/allusers)?)\s*$') {
        Write-Log 'OneDrive uninstall command is not a recognized safe form; preserved for manual review.' 'WARNING'
        return $false
    }
    $exe = [IO.Path]::GetFullPath($matches[1])
    $arguments = $matches[2]
    if ($Machine -and $arguments -notmatch '/allusers') {
        Write-Log 'Machine OneDrive uninstall lacks allusers scope; deferred to avoid wrong-account removal.' 'WARNING'
        return $false
    }
    $roots = @((Join-Path $env:ProgramFiles 'Microsoft OneDrive'), (Join-Path $env:SystemRoot 'System32'), (Join-Path $env:SystemRoot 'SysWOW64'))
    if ($script:CanApplyUser) { $roots += Join-Path $env:USERPROFILE 'AppData\Local\Microsoft\OneDrive' }
    $trusted = $false
    foreach ($root in $roots) {
        if ($exe.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)) { $trusted=$true }
    }
    if (-not $trusted) { throw 'Uninstaller outside known software locations.' }
    Assert-NoReparsePath $exe
    $signature = Get-AuthenticodeSignature -LiteralPath $exe
    if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation') {
        throw 'OneDrive uninstaller signature not verified.'
    }
    $process = Start-Process -FilePath $exe -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw 'OneDrive uninstaller failed.' }
    return $true
}

function Invoke-DefaultOneDrivePolicy {
    # Unique temporary mount, no marker, no regedit termination; always unload.
    $profileRoot = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList').Default
    $hive = Join-Path ([Environment]::ExpandEnvironmentVariables($profileRoot)) 'NTUSER.DAT'
    Assert-NoReparsePath $hive
    $mount = 'TMPC_Default_' + [Guid]::NewGuid().ToString('N')
    Invoke-Native 'reg.exe' @('load',"HKU\$mount",$hive)
    try {
        $run = "Registry::HKEY_USERS\$mount\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
        if (Test-Path -LiteralPath $run) {
            $key = Get-Item -LiteralPath $run
            try { $present = $key.GetValueNames() -contains 'OneDriveSetup' } finally { $key.Close() }
            if ($present) { Remove-ItemProperty -LiteralPath $run -Name OneDriveSetup }
        }
        Invoke-Native 'reg.exe' @('add',"HKU\$mount\SOFTWARE\Microsoft\OneDrive",'/v','EnableTHDFFeatures','/t','REG_DWORD','/d','0','/f')
    } finally {
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        Invoke-Native 'reg.exe' @('unload',"HKU\$mount")
    }
}

function Invoke-OneDriveRemoval {
    Write-Log 'OneDrive user content is preserved: %USERPROFILE%\OneDrive is excluded from deletion.'
    # Capture custom sync roots BEFORE uninstall/configuration cleanup changes
    # those keys. Read only UserFolder, never account tokens or credentials.
    $script:OneDriveProtectionReady = $false
    $script:ProtectedOneDriveRoots = @()
    Invoke-Operation 'OneDrive custom sync-root protection inventory (no personal paths logged)' {
        foreach ($hive in @(Get-ChildItem -LiteralPath 'Registry::HKEY_USERS')) {
            $accounts = $hive.PSPath + '\SOFTWARE\Microsoft\OneDrive\Accounts'
            if (Test-Path -LiteralPath $accounts) {
                foreach ($account in @(Get-ChildItem -LiteralPath $accounts)) {
                    $key = Get-Item -LiteralPath $account.PSPath
                    try { $folder = $key.GetValue('UserFolder', $null) } finally { $key.Close() }
                    if ($folder) { $script:ProtectedOneDriveRoots += [string]$folder }
                }
            }
        }
        $script:OneDriveProtectionReady = $true
    }
    Invoke-Operation 'OneDrive AppX removal' {
        foreach ($item in @(Get-AppxPackage -AllUsers -Name '*OneDriveSync*')) {
            Remove-AppxPackage -AllUsers -Package $item.PackageFullName
        }
    }
    # Avoid forcibly stopping sync with unsaved/pending work. Defer executable
    # and remnant cleanup until the user quits OneDrive, while applying policies.
    $running = @(Get-Process -Name '*OneDrive*' -ErrorAction SilentlyContinue).Count -gt 0
    if ($running) {
        Write-Log 'OneDrive is running; quit it after verifying local files, then rerun Full. Uninstall/remnant cleanup deferred.' 'WARNING'
    } else {
        $machine = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe'
        $user = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe'
        $script:OneDriveUninstalled = $false
        $script:OneDriveMachineUninstalled = $false
        $script:OneDriveUserUninstalled = $false
        Invoke-Operation 'OneDrive checked uninstaller' {
            $script:OneDriveMachineUninstalled = Invoke-OneDriveUninstaller $machine -Machine
            if (-not $script:OneDriveMachineUninstalled -and $script:CanApplyUser) {
                $script:OneDriveUserUninstalled = Invoke-OneDriveUninstaller $user
            }
            $script:OneDriveUninstalled = $script:OneDriveMachineUninstalled -or $script:OneDriveUserUninstalled
        }
        # Source step 3.1: remove only a positively uninstalled entry. Do not
        # delete another account's entry or hide failed-uninstall evidence.
        foreach ($entry in @(@{Path=$machine;Done=$script:OneDriveMachineUninstalled},@{Path=$user;Done=$script:OneDriveUserUninstalled})) {
            if ($entry.Done) {
                Invoke-Operation 'OneDrive confirmed uninstall entry cleanup' {
                    if (Test-Path -LiteralPath $entry.Path) { Remove-Item -LiteralPath $entry.Path -Recurse -Force }
                }
            }
        }
        # Never erase uninstall/configuration evidence after a failed or
        # unrecognized uninstall. An already absent installation is idempotent.
        $machineAbsent = -not (Test-Path -LiteralPath $machine)
        $userAbsent = -not $script:CanApplyUser -or -not (Test-Path -LiteralPath $user)
        if ($script:OneDriveUninstalled -or ($machineAbsent -and $userAbsent)) {
            $paths = @('HKLM:\SOFTWARE\Microsoft\OneDrive','HKLM:\SOFTWARE\WOW6432Node\Microsoft\OneDrive')
            if ($script:CanApplyUser) { $paths += @('HKCU:\SOFTWARE\Microsoft\OneDrive','HKCU:\SOFTWARE\WOW6432Node\Microsoft\OneDrive') }
            foreach ($path in $paths) {
                Invoke-Operation 'OneDrive configuration key removal' {
                    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
                }
            }
            $remnants = @(
                (Join-Path $env:ProgramFiles 'Microsoft OneDrive'),
                (Join-Path $env:ProgramData 'Microsoft OneDrive'),
                (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\OneDrive.lnk')
            )
            if ($script:CanApplyUser) {
                $remnants += Join-Path $env:USERPROFILE 'AppData\Local\Microsoft\OneDrive'
                $remnants += Join-Path $env:USERPROFILE 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs\OneDrive.lnk'
            }
            foreach ($path in $remnants) { Invoke-Operation 'OneDrive allowlisted software remnant removal' { Remove-OneDriveRemnant $path } }
        } else {
            Write-Log 'OneDrive uninstall not confirmed; configuration/remnants preserved. Manual review needed.' 'WARNING'
        }
    }
    foreach ($path in @('HKLM:\SOFTWARE\Classes\CLSID','HKLM:\SOFTWARE\Classes\WOW6432Node\CLSID')) {
        Invoke-Operation 'OneDrive Explorer namespace unpin' {
            $key = "$path\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
            if (Test-Path -LiteralPath $key) { Set-ItemProperty -LiteralPath $key -Name System.IsPinnedToNameSpaceTree -Type DWord -Value 0 -Force }
        }
    }
    $tasks = @(Get-ScheduledTask | Where-Object TaskName -like '*OneDrive*')
    foreach ($task in $tasks) {
        Invoke-Operation 'OneDrive scheduled task removal' {
            Unregister-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Confirm:$false
        }
    }
    Invoke-Operation 'Default-profile OneDrive auto-install prevention' { Invoke-DefaultOneDrivePolicy }
    if (-not $script:CanApplyUser) {
        Write-Log 'User-context OneDrive uninstall/remnants deferred: rerun Full as the target account with same-account elevation when available; UserOnly does not uninstall OneDrive.' 'WARNING'
    }
}

function Invoke-SystemPhase {
    # A partial run may already change servicing/power/policies: retain advice
    # even if a later enumeration or log operation aborts the phase.
    $script:RestartNeeded = $true
    Invoke-BloatRemoval
    Invoke-OneDriveRemoval
    Invoke-RegistryProfile (Get-SystemRegistryProfile) 'HKLM:'
    Invoke-Operation 'Standard Balanced power plan' { Invoke-Native 'powercfg.exe' @('/setactive','381b4222-f694-41f0-9685-ff5bb260df2e') }
    Invoke-Operation 'Hibernation off' { Invoke-Native 'powercfg.exe' @('/hibernate','off') }
    # Baseline reg imports run as SYSTEM: resolve HKCR to machine Classes,
    # not the elevated user's merged HKCR view.
    foreach ($suffix in @('*\shell\TakeOwnership','*\shell\runas','Directory\shell\TakeOwnership','Drive\shell\runas',
        'AllFilesystemObjects\shell\Windows.ShowFileExtensions','Directory\Background\shell\Windows.ShowFileExtensions')) {
        Invoke-Operation 'Machine Explorer context-menu baseline deletion' {
            $path = 'HKLM:\SOFTWARE\Classes\' + $suffix
            if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
        }
    }
    $scheduledTasks = @(
        '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
        '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
        '\Microsoft\Windows\Feedback\Siuf\DmClient',
        '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload',
        '\Microsoft\Windows\PI\Sqm-Tasks',
        '\Microsoft\Windows\Application Experience\MareBackup',
        '\Microsoft\Windows\Application Experience\StartupAppTask',
        '\Microsoft\Windows\Maps\MapsUpdateTask',
        '\Microsoft\Windows\Shell\FamilySafetyMonitor',
        '\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem'
    )
    $allTasks = @(Get-ScheduledTask)
    foreach ($name in $scheduledTasks) {
        $task = @($allTasks | Where-Object { ($_.TaskPath+$_.TaskName) -eq $name })
        if ($task.Count -eq 0) { Write-Log "Baseline task not present: $name"; continue }
        Invoke-Operation "Disable baseline task: $name" {
            foreach ($item in $task) { Disable-ScheduledTask -InputObject $item | Out-Null }
        }
    }
    Invoke-Operation '.NET Framework 3.5 local-source check' {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName NetFx3
        if ($feature.State -eq 'Enabled') { return }
        if (-not $NetFx3Source) {
            Write-Log 'NetFx3 is not enabled; supply -NetFx3Source with matching local sources\sxs media. No download attempted.' 'WARNING'
            return
        }
        if ($NetFx3Source -match '^\\\\' -or -not (Test-Path -LiteralPath $NetFx3Source -PathType Container)) { throw 'A local NetFx3 source is required.' }
        $sourcePath = (Resolve-Path -LiteralPath $NetFx3Source).ProviderPath
        $drive = New-Object IO.DriveInfo ([IO.Path]::GetPathRoot($sourcePath))
        if ($drive.DriveType -notin @('Fixed','Removable','CDRom')) { throw 'Network sources are not accepted.' }
        Assert-NoReparsePath $NetFx3Source
        $result = Enable-WindowsOptionalFeature -Online -FeatureName NetFx3 -All -LimitAccess -Source $NetFx3Source -NoRestart
        if ($result.RestartNeeded) { $script:RestartNeeded=$true }
    }
    $script:RestartNeeded = $true
    Write-Log 'ConfigureStartPins applyOnce policy retained; already initialized Start pins may not reset. Existing encryption is not undone.' 'WARNING'
}

function Complete-Run {
    param([int]$ExitCode)
    Write-Host ''
    Write-Host "Mode: $script:Mode; completed operations: $script:Completed; warnings: $script:Warnings; errors: $script:Errors"
    Write-Host "Restart required/recommended: $script:RestartNeeded; sign-out recommended after user preferences."
    Write-Host "Log: $script:LogPath; exit code: $ExitCode"
}

# Preflight BEFORE any configuration mutation (logging starts only after gates).
try {
    if ($PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or
        -not [Environment]::Is64BitProcess -or $env:PROCESSOR_ARCHITECTURE -ne 'AMD64') {
        throw 'Use native x64 Windows PowerShell 5.1.'
    }
    $os = Get-CimInstance Win32_OperatingSystem
    $version = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    if ($os.ProductType -ne 1 -or [int]$os.BuildNumber -ne 26200 -or $version.DisplayVersion -ne '25H2') {
        throw 'Only Windows 11 25H2 x64 (build 26200) is accepted; other builds are untested.'
    }
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if ($sid -in @('S-1-5-18','S-1-5-19','S-1-5-20')) { throw 'Run from a real user account, not a service account.' }
    if ($UserOnly -and ($Restart -or $NetFx3Source)) { throw 'UserOnly does not accept Restart or NetFx3Source.' }
    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $UserOnly -and -not $admin) { throw 'Full mode requires Windows PowerShell opened with Run as administrator. UserOnly needs no elevation.' }
    $script:CanApplyUser = $UserOnly -or (Test-CurrentDesktopIdentity)
} catch {
    Write-Host $_.Exception.Message
    $script:Errors++
    Complete-Run 2
    exit 2
}

try {
    $base = if ($UserOnly) { $env:LOCALAPPDATA } else { $env:ProgramData }
    $logs = Join-Path $base 'TMPC-Windows-11-Optimization\Logs'
    $existingParent = $logs
    while (-not (Test-Path -LiteralPath $existingParent)) { $existingParent = Split-Path -Parent $existingParent }
    Assert-NoReparsePath $existingParent
    New-Item -Path $logs -ItemType Directory -Force | Out-Null
    Assert-NoReparsePath $logs
    $script:LogPath = Join-Path $logs ('Apply-{0}-{1}-{2}.log' -f $script:Mode,(Get-Date -Format 'yyyyMMdd-HHmmss'),[Guid]::NewGuid().ToString('N'))
    Write-Log "Standalone 0.1.0; mode $script:Mode; reference Windows 11 25H2 x64. Static review only; standalone runtime not yet validated."
    if (-not $UserOnly) { Invoke-SystemPhase }
    if ($script:CanApplyUser) { Invoke-UserPhase }
    else {
        $script:UserDeferred = $true
        Write-Log 'HKCU skipped: elevated identity does not match a verified desktop. Run .\Apply-TMPCOptimizations.ps1 -UserOnly from the target account without elevation.' 'WARNING'
    }
    $exitCode = if ($script:Errors -gt 0) { 1 } elseif ($script:UserDeferred) { 3 } else { 0 }
    if ($Restart -and $exitCode -eq 0) {
        Write-Log 'Explicit Restart requested: save work now; restart in 60 seconds, cancellable with shutdown.exe /a.'
        Invoke-Operation 'Explicit restart request' { Invoke-Native 'shutdown.exe' @('/r','/t','60') }
        if ($script:Errors -gt 0) { $exitCode=1 }
    }
    Write-Log "Run finished; exit code $exitCode."
    Complete-Run $exitCode
    exit $exitCode
} catch {
    # Also handles log I/O failures: never report success without a usable log.
    $script:Errors++
    Write-Host 'Run failed; inspect operation/log availability locally. No automatic recovery is claimed.'
    Complete-Run 1
    exit 1
}
