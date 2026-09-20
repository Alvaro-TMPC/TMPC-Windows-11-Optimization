# Configuration, testing, limitations and sources

This document describes the real technical state of the baseline versioned in
this repository: which decisions the profile applies, what has been validated,
what remains unvalidated, which limitations exist and which source references
are present in the files.

Target platform: Windows 11 25H2, x64 / amd64.

It is not an installation guide. Preparation before formatting is documented
in `docs/pre-installation-preparation.md`.

## 1. Main configuration

The reference files are `autounattend.xml` and `ventoy.json`. This summary
collects the current decisions of the profile and does not reproduce the
complete key lists of the answer file.

- Windows Update stays active. The profile adjusts conservative restart and
  update-experience preferences, but it does not disable the update service.
- Drivers distributed through Windows Update are excluded.
- Microsoft Defender is kept. Only non-critical Windows Security
  notifications are reduced.
- Microsoft Store is kept for compatibility, repair and dependency
  installation.
- Edge and WebView2 are kept for compatibility with Windows and applications.
- Microsoft Photos is kept as the built-in image viewer.
- Paint is kept. The configured policies disable Cocreator, Generative Fill
  and Image Creator.
- Notepad is kept. The configured policy disables its AI features.
- OneDrive is removed and blocked as per the current design. This does not
  delete the content the user has in their OneDrive folder; the script
  preserves that data.
- Game Mode is enabled. Game DVR is disabled.
- Power plan: standard Windows Balanced. CPU is not forced to 100 %, EPP 0,
  hidden processor settings, USB overrides or high-performance clones are not
  applied.
- Hibernation and Fast Startup are disabled.
- UAC keeps the normal behavior for administrators and the secure desktop
  prompt.
- Print Spooler is kept on Automatic startup.
- Windows locking is kept: Win+L, the Start menu option and Ctrl+Alt+Del
  remain available.
- No aggressive CPU, GPU, scheduler or network optimizations are applied.
- OOBE and `BypassNRO` are kept.
- `ConfigureStartPins` is kept with an empty list and `applyOnce`.
- `ProductKey` is fictitious, made of zeros; it is not a real key.
- Transparency effects are disabled.
- The Do Not Disturb state is configured through the internal COM interface
  `IQuietHoursSettings` as the main path; Windows / WpnUserService materializes
  the persistent state. Direct writing of the Quiet Hours CloudStore blob is
  kept only as a fallback for recognizable materialized formats. Dependent on
  Windows 11 25H2.
- File Explorer sets, for the user created during installation: compact view
  enabled, item check boxes disabled, file name extensions visible and hidden
  items visible. All of them are applied in HKCU. `ShowSuperHidden` stays at
  0: protected operating system files remain hidden.
- Windows 11 25H2 opens the views of normal folders with "Group by = None" by
  default: generic items (Generic), Documents, Pictures, Music and Videos. The
  profile does not apply any grouping customization to them: it uses the
  native Windows behavior.
- Downloads is the only verified exception: its Windows FolderType groups
  items by modification date. The profile creates a per-user override of the
  shell FolderType: it copies the Downloads FolderType installed by Windows
  into HKCU and leaves `GroupBy` as an empty string. `Bags` and `BagMRU` are
  not deleted and the HKLM FolderType is not modified.
- Home, Gallery, SearchResults, Libraries, StartMenu and other special views
  are out of scope. Their groupings may be structural and are not modified
  automatically.

The second clean installation confirmed the Do Not Disturb behavior and the
transparency effects. Notepad's AI policies came out clean at runtime. Full
cleanup of the Paint AI interface remains open: the registry policies are
applied, but the application still shows AI-related options or messages.

## 2. Validation status

### Statically verified

On the real repository files:

- `autounattend.xml` is well-formed XML.
- All XML components are `amd64`: 3 components
  (`Microsoft-Windows-Setup`, `Microsoft-Windows-Deployment` and
  `Microsoft-Windows-Shell-Setup`); `x86` = 0; `arm64` = 0.
- The embedded PowerShell was syntactically parsed with the Windows
  PowerShell 5.1 parser: `SystemCustomizations.ps1`, `BloatRemoval.ps1` and
  `OneDriveRemoval.ps1`, with 0 errors.
- `ventoy.json` is valid JSON.
- The findings of the technical review of the customization flow are fixed
  and statically verified.
- The analyzed embedded scripts have not been executed on any system.
- The local static validator `scripts/validate-baseline.ps1` reproduces these
  checks in read-only mode and without executing the embedded scripts; it
  does not replace a real clean installation.

SHA-256 hashes of the current baseline:

- `autounattend.xml`:
  `70D5DA63FEA8078FDA45F8F20FCA82E4A476060DDB5304EDEB3DA8A21CC95FF6`.
- `ventoy.json`:
  `2231E01E9B0BA0622888D97EFEDA0F476DBD73A9CB90B11B48656E1F889F2796`.

### Error handling in the SYSTEM phase (specialize)

The SYSTEM-wide phase of specialize records every operation failure in its log.
Those failures do not force a global non-zero exit for that phase: this avoids
turning partial, non-critical customization failures into a Windows Setup
block, so the phase keeps its fail-open design.

The user-customization phase (`-UserCustomizations`) does exit with a non-zero
code when it finishes with errors. That exit code is part of the one-shot
retry/recovery semantics: the scheduled task is kept or restored so the next
logon can retry.

The initial registration of the one-shot task uses a bounded retry of up to
3 attempts, with a short wait only between failed attempts. A definitive
failure after the third attempt is still recorded as an error; it does not
create a loop and does not block Windows Setup.

### Verified with prior evidence

On Windows 11 25H2 it was previously observed, with ProcMon and the system
registry, that the Do Not Disturb state is stored in the Quiet Hours
CloudStore blob:

- `Microsoft.QuietHoursProfile.PriorityOnly` = Do Not Disturb on.
- `Microsoft.QuietHoursProfile.Unrestricted` = Do Not Disturb off.

That evidence corresponds to earlier observations and has not been reproduced
in this revision. The script fallback preserves the existing blob and replaces
only the profile string when applicable.

### Experimentally verified (Windows 11 Pro 25H2, isolated test)

A real installation of the previous baseline revealed that the Do Not Disturb
state was not being disabled. The fix is based on an isolated experimental
test performed on Windows 11 Pro 25H2:

- CLSID `{F53321FA-34F8-4B7F-B9A3-361877CB94CF}` and IID
  `{6BFF4732-81EC-4FFB-AE67-B6C1BC29631F}` activated with
  `CoCreateInstance(CLSCTX_LOCAL_SERVER)`.
- Validated vtable slots: 3 (`get_UserSelectedProfile`), 4
  (`put_UserSelectedProfile`) and 9 (`get_OffProfileId`).
- On a new user, with the compact state, the call
  `put_UserSelectedProfile(get_OffProfileId())` materialized the state
  (`isInitialized = true`, `selectedProfile =
  Microsoft.QuietHoursProfile.Unrestricted`) and the Do Not Disturb switch
  became disabled and remained editable.

The exact reason why the first clean installation ended with Do Not Disturb
enabled is not precisely identified: PENDING / NOT VERIFIED. In particular,
the 13-byte compact blob observed then does not equal `PriorityOnly` and must
not be documented as DND on: for a genuinely uninitialized user the read
returns an empty state and the COM profile is
`Microsoft.QuietHoursProfile.Unrestricted`.

`IQuietHoursSettings` is an internal, undocumented interface: it is not a
public API with contractual Microsoft support and it may change in future
builds.

### Experimentally verified (clean local user, Windows 11 25H2)

On a disposable local user on Windows 11 25H2 the
Downloads override mechanism was validated:

- Clean profile before the experiment: `UseCompactMode` absent,
  `AutoCheckSelect = 1`, `HideFileExt = 1`, `Hidden = 2`,
  `ShowSuperHidden = 0`, `UseAutoGrouping` absent; the Downloads override in
  HKCU did not exist and `Bags` did not exist.
- Before applying any customization, the normal folders opened for the first
  time in the clean user already showed "Group by = None": Generic, Documents,
  Pictures, Music and Videos (PASS). The only view that grouped was Downloads,
  by modification date.
- Method: recursively copy the Downloads FolderType from HKLM to HKCU with
  `reg.exe copy /s /f` and change only
  `TopViews\{00000000-0000-0000-0000-000000000000}\GroupBy` to an empty string
  (`REG_SZ`). The remaining values (`ColumnList`, `GroupAscending`,
  `LogicalViewMode`, `Name`, `Order`, `PrimaryProperty`, `SortByList`) stayed
  identical to HKLM.
- Runtime results of the Downloads override: first open with
  "Group by = None" (PASS), persistence after closing and reopening (PASS), no
  observable regression in `Bags` or in generic folders; `Bags` appeared after
  the first open with 0 grouping values; `BAGS_RESET_REQUIRED = NO`;
  `USEAUTOGROUPING_REQUIRED = NO`.
- The default grouping of normal folders is the native Windows 11 25H2
  behavior (`GLOBAL_NORMAL_FOLDER_GROUPING = PASS experimental`); the only
  grouping customization of the profile is the Downloads override
  (`NATIVE_NONE_DEFAULT + DOWNLOADS_SPECIFIC_OVERRIDE`).
- `UseAutoGrouping = 0` was tested earlier and REJECTED: Downloads kept
  grouping by modification date. It is not part of the baseline.
- It was not necessary to delete `Bags` or `BagMRU`; in a clean installation
  saved views do not exist before the override is applied.
- The FolderTypes override in HKCU is not a stable public Microsoft API and is
  validated specifically on Windows 11 25H2; a major update may remove the
  HKCU key and revert the behavior.

The test computer is permanently detected as slate (`ConvertibleSlateMode = 0`,
`SM_CONVERTIBLESLATEMODE = 0`) even though the official Lenovo ACPI driver was
installed (`LENOVO_VPC2004_DRIVER = PASS`,
`LENOVO_POSTURE_DETECTION = FAIL`). Therefore, the visual appearance of
compact view and check boxes on that machine is not used as a blocking
criterion; the Downloads grouping is validated functionally because it does
not depend on touch spacing. No convertibility hacks are introduced in the
baseline.

### Verified on a real clean installation (Windows 11 Pro 25H2)

The corrected `autounattend.xml` was written to the media with the source
SHA-256 verified, the SSD was cleaned and converted to GPT, and Setup created
its partitions automatically. Result:

- installation, OOBE and desktop reached correctly;
- no mandatory network or Microsoft account prompt;
- no blocking Setup errors.

In the first installation, non-blocking transient BFSVC/BCD messages were
observed in `setuperr.log`; the installation finished and booted correctly,
with the disk in healthy GPT/EFI. It is classified as an observed,
non-blocking Setup incident.

Before touching the Do Not Disturb interface, the evidence was:

- CloudStore with a materialized 116-byte `REG_BINARY` `Data`;
- Quiet Hours state read: `isInitialized = true`,
  `selectedProfile = Microsoft.QuietHoursProfile.Unrestricted`;
- COM getter: `HRESULT 0x00000000`,
  `Microsoft.QuietHoursProfile.Unrestricted`.

Later visual check: Do Not Disturb off, switch editable and manual re-enable
correct. The final cleanup completed: no `C:\ProgramData\Autounattend`, no
scheduled task, no marker and no profile logs. The absence of the final marker
is consistent with a complete cleanup and must not be interpreted as a
failure.

The one-shot retry/recovery path was also observed at runtime on 2026-09-12
with a controlled failure test on the published baseline
`C0EA1741BB09EA88F83F2D4C841081C9441AEE9F81DC4D2681ED6C9C9A5F03D1`: the
one-shot was removed and verified before the fault, the fault was not reported
as success, the recovery restored and verified the one-shot, the retry on the
next logon completed the cleanup and the final restart booted with a clean
system. Status: normal one-shot path = PASS and recovery path = PASS.

### Evaluated implementation: real clean installation and integrated Explorer (2026-09-12)

The evaluated implementation (the one-shot cleanup registration fix, Explorer
preferences and the Downloads override) completed a real destructive clean
installation on the test computer, with the media verified by SHA-256 and
without test instrumentation. Result:

- final desktop reached correctly, with dark mode and default wallpaper
  (`AppsUseLightTheme = 0`, `SystemUsesLightTheme = 0`,
  `WallPaper = C:\Windows\Web\Wallpaper\Windows\img19.jpg`);
- one automatic restart observed during the flow;
- complete normal path of the one-shot flow: task removed and verified, cleanup
  registered and verified, user marker removed, automatic restart executed,
  final cleanup completed and later boot without leftovers
  (`AUTOUNATTEND_TASK_COUNT = 0`, `C:\ProgramData\Autounattend` absent,
  `HKLM\SOFTWARE\Autounattend` absent, user marker absent);
- Explorer registry: `UseCompactMode = 1`, `AutoCheckSelect = 0`,
  `HideFileExt = 0`, `Hidden = 1`, `ShowSuperHidden = 0`; Downloads HKCU
  override present with empty `GroupBy` (`REG_SZ`) and HKLM keeping
  `System.DateModified`; `UseAutoGrouping` absent;
- visual/functional validation: Generic, Documents, Pictures, Music and Videos
  open with "Group by = None" natively and Downloads opens with
  "Group by = None" through the override and keeps the state after closing and
  reopening File Explorer.

Statuses: normal one-shot path revalidated = PASS, evaluated implementation
runtime validation = PASS, Explorer registry validation = PASS, integrated
Explorer clean installation = PASS, Downloads reopen persistence = PASS,
runtime validation = PASS.

The historical first-logon anomaly (taskbar and wallpaper visually light until
a logoff/logon) did not reproduce in this installation; its cause remains
unverified and it is not declared resolved. Compact view and check boxes are
not used as a visual criterion on the test computer due to its already
documented slate anomaly; their registry values were verified.

### Pending / not verified

- Exact cause of Do Not Disturb being enabled in the first clean installation:
  PENDING / NOT VERIFIED; the 13-byte compact blob does not equal
  `PriorityOnly` and must not be documented as DND on.
- Runtime coverage of the remaining reviewed findings is partial: some were
  not observed at runtime and others are only partially verified.
- Fixing and verifying the remaining findings of the technical review.
- Complete effectiveness of Paint AI features: the policies are applied, but
  the visual cleanup was not achieved and the specific effect of each feature
  remains unconfirmed.
- Compatibility with versions, editions or builds other than Windows 11 25H2.
- Any other item marked as pending in the repository documentation.
- The posture detection of the test computer is permanently in slate mode
  (`ConvertibleSlateMode = 0`, `SM_CONVERTIBLESLATEMODE = 0`); the visual
  appearance of compact view and check boxes on that machine is not reliable
  evidence and is not used as a blocking criterion. The Downloads grouping is
  validated functionally on that machine.

**A static validation does not replace a real clean installation.** The
current XML has completed real clean installations on Windows 11 Pro 25H2.
Versioning or tagging a release documents that validated baseline, but it does
not extend or guarantee compatibility with other Windows versions, editions or
builds.

## 3. Limitations and dependencies

- Windows 11 25H2 is the current reference. Compatibility with other versions,
  editions or builds is not verified or guaranteed.
- `BypassNRO` may depend on the specific Windows version or build.
- `ConfigureStartPins` uses an implementation that must be revalidated when
  Windows changes.
- The CloudStore/Quiet Hours configuration depends on Windows 11 25H2
  implementation details. The main path uses the internal, undocumented
  `IQuietHoursSettings` interface, which may change in future builds and must
  be revalidated.
- The per-user override of the Downloads FolderType is not a public Microsoft
  API; a major update may remove `HKCU\...\FolderTypes` and revert the default
  grouping. The rest of the normal folders use the native Windows 11 25H2
  default and have no override.
- Notepad AI features had no visible presence in the real test; Paint AI
  features remain unconfirmed and their visual cleanup was not achieved.
- The remaining findings of the technical review remain pending.
- Release versioning or tagging does not extend the compatibility scope:
  Windows 11 25H2 remains the only currently validated reference.

## 4. Sources, licenses and attributions

Source references present in the versioned files:

- `autounattend.xml` includes the reference
  `Source: https://github.com/memstechtips/Autounattend` in the notes of two
  generated scripts: `BloatRemoval.ps1` (version 2.3) and
  `OneDriveRemoval.ps1` (version 1.2). That historical URL is deliberately
  kept inside the XML so as not to alter the validated baseline.

Project license:

- TMPC Windows 11 Optimization is distributed under the MIT License.
- Copyright (c) 2026 Alvaro-TMPC.
- The full text is in `LICENSE`.

Third-party components:

- Part of `autounattend.xml` is derived from, or based on, code distributed in
  `memstechtips/UnattendedWinstall`.
- Reference revision (snapshot):
  `cca752363772a845eb0fed9d3a5b89b5d0a10d20`.
- Snapshot license: MIT License.
- Copyright: Copyright (c) 2025 Marco du Plessis (memstechtips).
- Identified components: `BloatRemoval.ps1` (version 2.3),
  `OneDriveRemoval.ps1` (version 1.2) and related helper/automation logic.
- Canonical reference for licensing and traceability:
  `https://github.com/memstechtips/UnattendedWinstall`. The historical URL
  `https://github.com/memstechtips/Autounattend` remains inside the XML and is
  documented separately.
- The complete third-party notices, including the MIT text with its
  copyright, are in `THIRD_PARTY_NOTICES.md`.

Other evaluated components:

- Ventoy: the repository only includes its own configuration (`ventoy.json`);
  the user downloads Ventoy externally and no Ventoy binaries are
  redistributed.
- Microsoft: no Windows, ISO or Microsoft binaries are redistributed; the
  all-zero `ProductKey` is fictitious.
- TechPowerUp: it appears only as a provider of optional external tools linked
  from the project documentation (for example, the optional Visual C++
  Redistributable package recommendation in
  `docs/pre-installation-preparation.md` and GPU-Z in the post-installation
  guides); no binaries or content from it are incorporated or redistributed as
  part of the project.

Status:

- Provenance, licensing and attribution audit: CLOSED.
- The Git history does not require rewriting for licensing reasons.
