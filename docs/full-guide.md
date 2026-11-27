# TMPC Windows 11 Optimization full guide

[Español](guia-completa.md) | **English**

[Back to the main README](../README.en.md) · [Spanish README](../README.md) · [Compatibility page](../README.es.md)

This guide contains the complete TMPC Windows 11 Optimization procedure:
clean installation with Ventoy, disk preparation, first logon, post-install
optimization of an existing installation, verification, hashes, limitations and
sources. The [main README](../README.en.md) is the short landing page; this
guide keeps the full technical detail.

## Contents of this guide

- [What this project is](#what-this-project-is)
- [What it does](#what-it-does)
- [Requirements and compatibility](#requirements-and-compatibility)
- [Tested environment](#tested-environment)
- [Important warning](#important-warning)
- [Download and versions](#download-and-versions)
- [Before you start](#before-you-start)
- [Create the Ventoy USB](#create-the-ventoy-usb)
- [Boot from the USB](#boot-from-the-usb)
- [Windows Setup](#windows-setup)
- [First logon and automatic restart](#first-logon-and-automatic-restart)
- [After installation](#after-installation)
- [Quick verification](#quick-verification)
- [Apply the optimizations to an existing Windows installation](#apply-the-optimizations-to-an-existing-windows-installation)
- [File integrity (SHA-256)](#file-integrity-sha-256)
- [Known limitations](#known-limitations)
- [Local static validation](#local-static-validation)
- [Repository layout](#repository-layout)
- [Technical documentation](#technical-documentation)
- [Sources and licensing](#sources-and-licensing)

## What this project is

TMPC Windows 11 Optimization is a reproducible profile for a clean Windows 11
installation. It is aimed at users who want a privacy-oriented system with a
conservative reduction of built-in apps, while staying suitable for gaming,
programming and everyday use.

The profile is delivered as a single answer file (`autounattend.xml`) applied
during Windows Setup, plus a small Ventoy configuration (`ventoy.json`) used to
associate the expected Windows ISO with that answer file on the installation
USB.

For an existing installation, the additional self-contained
[`Apply-TMPCOptimizations.ps1`](../Apply-TMPCOptimizations.ps1) applies the
relevant post-install portion of the same profile. It is not an installer, it
has no graphical interface and it does not download third-party software.

## What it does

The current baseline applies the following decisions:

Privacy:

- telemetry reduced to the minimum allowed by the OS, advertising ID disabled
  and tailored experiences disabled;
- activity feed, cloud activity upload and cross-device clipboard disabled;
- location access denied, non-essential app permissions force-denied;
- on-device generative AI models access denied, Recall prevented and Click to
  Do disabled where supported;
- Copilot entry points disabled and the Copilot app removed;
- camera and microphone access is left under user control;
- automatic device encryption (BitLocker) is prevented during setup.

Debloat (conservative, curated list):

- consumer apps removed, such as news, weather, maps, Solitaire, Xbox companion
  apps, consumer Teams/Skype, Sticky Notes, To Do, Your Phone, OneNote and
  Copilot;
- legacy components removed, such as WordPad, PowerShell ISE and Steps
  Recorder;
- deliberately kept: Microsoft Defender, Microsoft Store, Edge and WebView2,
  Microsoft Photos, Paint and Notepad.

Windows features:

- Windows Update stays active for quality and security updates, but drivers
  distributed through Windows Update are excluded.
  `NoAutoRebootWithLoggedOnUsers` only prevents an automatic restart while users
  are signed in; it does not prevent an update from requiring a restart and does
  not replace the user's decision;
- Microsoft Defender stays enabled; only non-critical Windows Security
  notifications are reduced;
- Microsoft Store stays available for app installation, repair and dependency
  installation;
- OneDrive is removed and blocked, while existing user data in the OneDrive
  folder is preserved;
- Paint and Notepad stay installed with their AI features disabled by policy
  (Cocreator, Generative Fill, Image Creator and Notepad AI);
- Do Not Disturb is configured to OFF at apply time (Windows can turn it on
  again through its own automatic rules; see
  [Known limitations](#known-limitations));
- Game Mode is enabled; Game DVR and the Xbox Live companion services are
  disabled. The Xbox Live service is set to manual start (`Start = 3`): games
  that need it can start it, but it is not kept resident by default;
- power plan is the standard Windows Balanced plan; hibernation and Fast Startup
  are disabled (Sleep and Hibernate entries are hidden from the Start power
  menu, Windows locking stays available);
- transparency effects are disabled and the default theme is dark;
- File Explorer: compact view enabled, item check boxes disabled, file name
  extensions visible and hidden files visible (protected operating system files
  stay hidden), classic context menu, cleaned Quick Access;
- Downloads opens without "Group by date" grouping (per-user folder view
  override); normal folders keep the native Windows 11 default;
- no aggressive CPU, GPU, scheduler or network tweaks are applied.

Windows AI features that are disabled by the profile: Recall, Click to Do,
Settings AI agent, Paint Cocreator, Paint Generative Fill, Paint Image Creator,
Notepad AI features and legacy Windows Copilot entry points.

This document summarizes the behavior; it is not a full registry dump. The
answer file remains the authoritative source.

## Requirements and compatibility

- Target platform: Windows 11 Pro 26H2, x64 / amd64 (build base 26300; the OS
  revision/UBR is not fixed).
- Installation path: UEFI, amd64, with a genuine Windows 11 x64 ISO and a USB
  drive you can erase.
- The published v0.1.5 baseline was validated on Windows 11 Pro 25H2 as a
  historical reference; that evidence is not attributed to 26H2.
- The standalone accepts, by design, Windows 11 client editions (build 22000
  or later) in native AMD64 Windows PowerShell 5.1, from a real user account.
  Full mode requires an elevated console.
- Windows Server, Windows 10 or older families (`UNSUPPORTED`) and non-AMD64 or
  32-bit hosts (`INCOMPATIBLE`) are rejected before any change.
- No hardware-specific drivers and no third-party software are included.
- WSL, Bash, Python and any external dependency are not required.

The project's documented categories are `TESTED_ON`, `SUPPORTED_BY_DESIGN`,
`NOT_RUNTIME_TESTED`, `UNSUPPORTED` and `INCOMPATIBLE`. Other Windows 11 builds
inside the supported envelope are accepted and reported as
`NOT_RUNTIME_TESTED`; full compatibility is not claimed.

## Tested environment

Current reference: Windows 11 Pro 26H2 (x64 / amd64, build base 26300; the OS
revision is not fixed). On a clean 26H2 installation used as test environment:

- the Start pins policy pair was applied as the ADMX-exact machine policy and
  its result was verified at runtime (empty Pinned section, later user pins
  preserved);
- the Outlook for Windows promotional taskbar pin was visually absent for a
  genuinely new local user, with Edge, File Explorer and Microsoft Store kept;
- `AllAppsViewMode` (DWord 2) was applied programmatically on an existing
  profile: List visible after signing out and back in, and the value persisted.

The integrated answer file with the latest changes has not been retested on
another clean installation, and the standalone has no host runtime test yet.

Historical evidence: the published v0.1.5 baseline completed real clean
installations on Windows 11 Pro 25H2 (x64 / amd64), including:

- Setup, OOBE and first desktop reached without blocking errors;
- local account creation with no mandatory network or Microsoft account prompt;
- user-specific customizations applied with a one-time task;
- automatic restart executed by the profile and final desktop reached;
- final cleanup completed with no leftover setup tasks or temporary files;
- Explorer defaults and the Downloads view override verified.

That evidence documents the historical 25H2 baseline; it is not a 26H2
clean-install claim. Other Windows 11 versions, editions or builds are not
guaranteed. Future builds may require revalidation.

## Important warning

A clean installation can destroy data irreversibly. Before you start:

- make a full backup of your data and verify that the backup is readable;
- review the answer file before using it; you are responsible for what it
  applies to your machine;
- this profile does NOT select or erase disks: you choose the target disk and
  partitions manually during Windows Setup, so double-check the disk you are
  about to modify;
- if you can, test the whole procedure on a disposable machine or virtual
  machine first.

There is no automatic rollback. If something fails, recovery depends on your
backup, the installation media and the Windows recovery tools.

## Download and versions

The latest published version is **v0.3.0**. Download its four assets from the
[historical v0.3.0 release](https://github.com/Alvaro-TMPC/TMPC-Windows-11-Optimization/releases/tag/v0.3.0)
or [GitHub Releases](https://github.com/Alvaro-TMPC/TMPC-Windows-11-Optimization/releases):
`autounattend.xml`, `ventoy.json`, `Apply-TMPCOptimizations.ps1` and
`SHA256SUMS.txt`. Published assets are immutable and keep their historical
hashes.

The files in this repository with the R1/R1.1/R2 blocks are a **local candidate
after v0.3.0**, not a published release. Do not attribute their hashes to
v0.3.0. A direct release download lets you verify the complete set with
`SHA256SUMS.txt`.

This project does not provide an executable installer or a remote command such
as `irm ... | iex`. If you see instructions like that attributed to TMPC, do
not run them.

## Before you start

Prepare at least:

1. Backups and verification.
   - Back up Desktop, Documents, Downloads, Pictures, Videos, Music, projects
     and repositories, and any data stored outside the standard folders.
   - Open a sample of files directly from the backup destination to verify it.
   - Make sure the backup drive is not one of the drives you are going to
     format.
2. Projects and development data.
   - Review local repositories, uncommitted changes, local branches, SSH/GPG
     keys and certificates. Publish or back up anything that only exists on
     this machine. Never store secrets in a repository.
3. Saved games and non-reproducible content.
   - Check saved games, mods, launcher profiles and captures game by game;
     cloud sync is not guaranteed for every title.
4. Cloud files (OneDrive and similar).
   - Verify that important files are really available locally or backed up
     elsewhere; online-only placeholders are not local copies.
5. BitLocker / encryption.
   - If any drive is encrypted, make sure the recovery keys are available
     outside the machine that will be formatted.
6. Drivers.
   - This profile excludes drivers delivered through Windows Update. Download
     in advance, from your hardware vendor: Ethernet, Wi-Fi (if the machine
     depends on it), chipset, audio and GPU drivers. Keep them on a drive you
     can reach during and after installation.
7. Software.
   - Keep installers for the apps you will need right after installing
     (browser, development tools, game launchers). This repository does not
     install third-party software automatically.
8. Installation media.
   - Use a genuine Windows 11 x64 / amd64 ISO from a trusted source and a USB
     drive you can erase; installing Ventoy repartitions and formats the USB
     drive.

The expanded preparation checklist, with a prior inventory and final checks, is
in [Pre-installation preparation](pre-installation-preparation.md).

## Create the Ventoy USB

The installation media is built with [Ventoy](https://www.ventoy.net/), an
open-source tool that boots ISO files directly from a USB drive.

1. Download Ventoy from its official source (<https://www.ventoy.net/>). Use
   the latest stable release; this repository does not pin a specific version.

2. Install Ventoy on the USB drive.

   Warning: installing Ventoy on a drive erases and repartitions that drive.
   Make sure you select the correct USB device and that it contains nothing you
   want to keep.

3. Copy the repository files to the USB drive using exactly the structure
   expected by `ventoy.json`:

   ```text
   <USB drive root>
   ├── Windows11_Client_x64_es-es_26300_9457.iso
   └── ventoy/
       ├── ventoy.json
       └── script/
           └── autounattend.xml
   ```

   - `ventoy.json` goes to `\ventoy\ventoy.json` on the Ventoy partition.
   - `autounattend.xml` goes to `\ventoy\script\autounattend.xml`; this is the
     path declared as `template` in `ventoy.json`.
   - The Windows ISO goes to the root of the USB drive with the exact file name
     declared as `image` in `ventoy.json`, currently
     `Windows11_Client_x64_es-es_26300_9457.iso`.

4. The ISO file name and path must match the `image` value in `ventoy.json`.
   If you use a different ISO, rename your file to match or edit `ventoy.json`
   coherently (the same applies to any other path). Do not use modified or
   unverified ISOs.

5. Eject the USB drive safely before removing it.

When you boot the ISO, Ventoy shows a boot menu for that image with two
options:

- `Boot without auto installation template`: boots the plain Windows ISO with
  no answer file.
- `Boot with /ventoy/script/autounattend.xml`: boots the ISO applying the
  `autounattend.xml` declared as `template` in `ventoy.json` as the answer file
  for that image.

To install TMPC Windows 11 Optimization, choose
`Boot with /ventoy/script/autounattend.xml`.

## Boot from the USB

1. Connect the USB drive and power on (or restart) the target machine.
2. Open the UEFI/BIOS boot menu of your machine. The key varies by
   motherboard/device (commonly F12, F10, F2, Esc or Del, but there is no
   universal key); consult your machine documentation if needed.
3. Select the USB drive entry. Prefer the UEFI entry; this profile targets the
   amd64/UEFI path.
4. Ventoy starts and lists the ISO files found on the drive. Select
   `Windows11_Client_x64_es-es_26300_9457.iso`. Ventoy then shows the boot menu
   for that image: choose `Boot with /ventoy/script/autounattend.xml` to install
   with the profile, or `Boot without auto installation template` to boot the
   plain ISO without applying `autounattend.xml`.
5. Windows Setup starts.

## Windows Setup

- The profile does not automate disk selection or disk erasure. Select the
  target disk and partitions yourself and verify very carefully which disk you
  are about to modify. If the disk already contains an old installation you
  want to remove, delete its partitions in Setup or use the manual DiskPart
  procedure described below; make sure you are working on the right drive.
- The answer file bypasses the Windows 11 hardware requirement checks (TPM,
  Secure Boot, CPU, RAM, storage and disk) during Setup. Installing on
  unsupported hardware is still your responsibility.
- A product key screen may appear: the answer file contains a placeholder key,
  not a real license. Use your own key if you have one.
- Setup continues automatically from the answer file; do not interrupt it.
- OOBE is designed to allow creating a local account. During OOBE the network
  adapters may appear disabled; this is intentional and is not an error: the
  adapters are re-enabled automatically at first logon.
- Complete OOBE by creating your local user account and reaching the desktop.

### Preparing the disk manually with DiskPart

The answer file does not select or erase any disk; you are responsible for
choosing the correct target disk. This procedure is destructive and is the
documented manual procedure for a clean installation in which you prepare the
disk explicitly; it is not mandatory for every scenario. If you can,
disconnect any other disk that does not take part in the installation.

1. In Windows Setup, press `Shift + F10` to open a command console.
2. Run DiskPart and identify the target disk.

   > **Warning:** `clean` irreversibly removes the partition structure of the
   > selected disk. Confirm the disk number with `list disk` and `detail disk`
   > before running it.

   ```text
   diskpart
   list disk
   select disk X
   detail disk
   clean
   convert gpt
   exit
   ```

   - Replace `X` with the number of the correct target disk.
   - `list disk` shows the available disks.
   - `detail disk` is the final check before erasing: confirm that the selected
     disk is the correct one.
   - `clean` removes the partition structure of the selected disk and must be
     treated as a destructive operation.
   - `convert gpt` explicitly prepares the disk as GPT for the UEFI flow.
   - Do not use `clean all`: it is not required for this procedure.
3. Close the console, return to Windows Setup, select Refresh and choose the
   unallocated space so that Windows creates the required partitions.

## First logon and automatic restart

This part is important. The behavior of the validated baseline is:

1. Windows reaches the desktop for the first time.
2. User-specific settings are applied by a one-time task started at logon.
3. When the flow finishes, the machine schedules an automatic restart (about
   20 seconds of notice are shown).
4. Do not shut down, reset or interrupt the machine while this is happening.
5. After that restart you reach the final desktop; temporary setup files are
   removed automatically at startup.

Consider the installation finished once you reach the final desktop after the
automatic restart.

### First-boot robustness (R2 blocks)

- **Network:** `NetworkGuard.ps1` persists each adapter GUID and its prior state
  before changing anything. It disables only adapters that were enabled and
  restores only the adapters that TMPC disabled, after OOBE has completed. It
  never runs an indiscriminate `Get-NetAdapter | Enable-NetAdapter`. If a present
  adapter remains disabled, it registers a bounded **AtLogOn** recovery task; it
  does not create an unconditional AtStartup task. Manual recovery means
  enabling the adapter in `ncpa.cpl` or Device Manager and removing the
  `TMPCNetworkRestoreRecovery` task if it is still present. Adapters that were
  already disabled before TMPC stay disabled. Before copying the script and
  registering the recovery task, the gate verifies owner, effective ACL and the
  absence of reparse points on the source, ancestors and destination; if no
  safe, verifiable location exists, the task is not registered and documented
  manual recovery remains.
- **HKCU preferences:** the one-shot task keeps the verified identity, records
  each completed operation and does not rewrite it on a retry. Automatic retries
  are limited to three; transient, permanent, deferred and not-applicable
  outcomes are distinguished and reflected in `SetupSummary.json`. A permanent
  failure or the retry limit removes the task: TMPC is not left as a resident
  application and the failure is not hidden. The Quiet Hours and Downloads
  `GroupBy` guards remain in place, and completed user preferences are not
  overwritten.
- **.NET Framework 3.5:** `NetFx3.ps1` queries the feature first, validates that
  `sources\sxs` contains the NetFx3 payload, runs DISM with
  `/LimitAccess /NoRestart`, checks the exit code and re-reads the final state.
  It distinguishes already enabled, source unavailable, pending reboot and a
  real failure. It never downloads or restarts. The standalone keeps
  `-NetFx3Source` and applies the same checks.
- **Identity and scopes:** the SYSTEM phase never writes HKCU. The HKCU phase
  runs in the interactive user's session with a verified SID and token; an
  ambiguous or mismatched identity is deferred without falling back to the first
  account or profile path. OneDrive keeps independent machine and user evidence:
  a user success never authorizes machine cleanup, and `UNKNOWN` is never read
  as absence.
- **Diagnostics and cleanup:** the verifiable summary lives in
  `C:\ProgramData\TMPC-Windows-11-Optimization\Logs`, with directory, file and
  parent-directory ACLs checked through numeric rights masks. Cleanup deletes
  only `C:\ProgramData\Autounattend` and `HKLM\SOFTWARE\Autounattend` with an
  intact summary and global `SUCCESS`; in any other state it keeps the evidence
  and logs for diagnosis.

These paths are implemented and covered by isolated tests, but they were not
executed in a real clean installation in this block:
`RUNTIME_VALIDATION = NOT_TESTED`.

## After installation

After the final desktop:

- Check network connectivity. If the adapters were not re-enabled
  automatically, enable them from Windows Settings or Device Manager.
- Install the OEM drivers you prepared in advance: chipset, network/Wi-Fi,
  audio and GPU. Remember that driver updates through Windows Update are
  excluded by this profile.
- Run Windows Update normally to install quality and security updates.
- Check Device Manager for devices with missing drivers.
- Restore your data and reinstall your applications.
- Reconfigure accounts, services and development environments as needed.
- Verify that Microsoft Defender is active and that Windows Security reports no
  critical warnings.

This repository does not install third-party software, browsers or utilities;
that remains a user decision.

For a more complete hardware and post-installation validation checklist,
including PCIe/GPU-Z, display, RAM, storage and peripherals, see
[Post-installation checks](post-installation-checks.md).

## Quick verification

A quick, user-level checklist for a successful installation:

- [ ] The final desktop is reached after one automatic restart.
- [ ] Network connectivity works.
- [ ] Microsoft Defender is active.
- [ ] Windows Update is available (quality/security updates; no driver
      updates).
- [ ] Microsoft Store opens.
- [ ] OneDrive is not installed.
- [ ] Game Mode is enabled and Game DVR is disabled.
- [ ] File Explorer shows file extensions and hidden files (protected system
      files stay hidden), with compact view enabled.
- [ ] Downloads opens without grouping by date, and the state persists after
      closing and reopening File Explorer.
- [ ] Do Not Disturb is off.
- [ ] Transparency effects are disabled and the default theme is dark.

This checklist reflects tested behavior; it does not replace the static
validation described below or a controlled runtime test.

## Apply the optimizations to an existing Windows installation

`autounattend.xml` remains the clean-install method. The self-contained
[`Apply-TMPCOptimizations.ps1`](../Apply-TMPCOptimizations.ps1), standalone version
0.2.2, provides a post-install method **without formatting**, derived directly
from the answer file (v0.1.5 plus the 26H2 blocks: Start pins policy, cloud
optimized content and All apps view). It needs no other repository files,
external dependencies or downloads. Registry work is idempotent and verified:
every value is read first, written only when it differs and re-read to confirm
the result, so an already compliant PC is not rewritten.

**Compatibility (TESTED_ON / SUPPORTED_BY_DESIGN / NOT_RUNTIME_TESTED).** The
tested reference is Windows 11 Pro 26H2 (build base 26300; the OS revision is
not fixed). By design it accepts Windows 11 client editions (build 22000 or
later) in native AMD64 Windows PowerShell 5.1, from a real user account; Full
mode requires an elevated console. Any other Windows 11 build inside that
envelope is accepted and reported as `NOT_RUNTIME_TESTED`: per-operation guards
apply, degradations are reported, an accumulated revision (UBR) update never
forces a rejection and full compatibility is not claimed. Windows Server,
Windows 10 or older families (`UNSUPPORTED`) and non-AMD64 or 32-bit hosts
(`INCOMPATIBLE`) are rejected before any change. The published clean-install
baseline (v0.1.5) has runtime evidence on the historical Windows 11 Pro 25H2
reference; this standalone has static validation plus an isolated automated test
suite and has **not** been tested on host hardware. This is not a claim of
identical end state on an already customized PC.

Before running it, make and verify a backup, **review the script**, save your
work and close the applications affected by debloat. Quit OneDrive after
checking your local/cloud files. Full mode modifies system settings and removes
the profile's curated built-in apps for all users, including provisioned copies
for future users. App removal can remove the apps' settings/state. Defender,
Store, Edge/WebView2, Photos, Paint and Notepad retain the baseline decisions.
No disks, partitions, accounts or Windows license are changed.

Full mode removes and blocks OneDrive, but **preserves all existing content in
`%USERPROFILE%\OneDrive`**. Online-only placeholders are not backed-up local
copies. Software-remnant deletion is allowlisted and refuses linked/junction
paths. Running OneDrive, an unrecognized uninstall command or unsafe remnants
are reported and deferred; verify warnings/errors before considering removal
done. Windows' own OneDrive setup binaries are preserved.

Download/save `Apply-TMPCOptimizations.ps1` from this repository using the file's
**Raw / Download raw file** action. Open **Windows PowerShell as administrator**
for Full mode, navigate to the folder where you saved the file, then run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Apply-TMPCOptimizations.ps1
```

Full mode does not auto-elevate: elevation is required only for its system phase.
HKCU preferences are applied afterwards only if the executing SID matches the
Explorer desktop in the same session. If alternate administrator credentials
were used or the desktop cannot be verified, HKCU is skipped with exit code 3:
run `-UserOnly` from the intended account. User-context OneDrive cleanup is also
deferred in that situation; `-UserOnly` does not perform that uninstall.

For **a new account created later**, another local user, or to reapply personal
preferences, sign in to that account and open **ordinary, non-elevated Windows
PowerShell**:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Apply-TMPCOptimizations.ps1 -UserOnly
```

`-UserOnly` is the recommended method for later accounts. It applies the entire
HKCU preference inventory of the answer file's user phase: gaming/Game DVR,
visual effects and shortcuts, notifications/Do Not Disturb, privacy/AI, sound,
Update/Store user preferences, Explorer/Downloads, Start/Taskbar and dark theme
with the baseline wallpaper. It changes only the executing account, reads HKLM
only for checks/Downloads source, performs no global debloat/OneDrive cleanup
and does not require elevation. It can be rerun without deleting any marker.

There is **no automatic restart by default**. Some changes require signing out
and back in or restarting. For a conscious restart request in Full mode, save
all work first, then use:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Apply-TMPCOptimizations.ps1 -Restart
```

Restart is requested only on exit code 0, with 60 seconds notice (Windows may
close applications at the deadline); cancel with `shutdown.exe /a` if needed.
`-UserOnly` does not accept `-Restart`; restart manually from Windows instead.

### Parameters

| Parameter | Mode | Effect |
| --- | --- | --- |
| `-UserOnly` | User | Applies only the HKCU preferences of the executing account, without elevation or global changes. It does not accept `-Restart` or `-NetFx3Source`. |
| `-Restart` | Full | Requests a restart with 60 seconds notice only when the run ends with exit code 0. |
| `-NetFx3Source` | Full | Local path to a `sources\sxs` directory from matching Windows media. Without a source, .NET Framework 3.5 is not enabled and Windows Update is not used as a fallback. |

Example for .NET Framework 3.5 with local media:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Apply-TMPCOptimizations.ps1 -NetFx3Source "D:\sources\sxs"
```

Replace `D:` with your mounted media drive. Full logs are written to
`%ProgramData%\TMPC-Windows-11-Optimization\Logs\`; `-UserOnly` logs go to
`%LOCALAPPDATA%\TMPC-Windows-11-Optimization\Logs\`. The final summary shows
mode, completed operations, warnings, errors, restart advice, log path and exit
code: 0 = completed (review warnings for limitations), 1 = operation/log
failure, 2 = preflight rejection, 3 = system phase finished but target-user
preferences deferred. There is no automatic rollback.

### Coverage and post-install differences

| Baseline block | Post-install behavior |
| --- | --- |
| System registry/policies | Same HKLM names, types and values: privacy, Update/driver exclusion, Defender notifications, gaming, power, AI, Explorer, Start/Taskbar, cloud optimized content suppression and sound. HKCR deletions resolve to machine Classes, matching the original SYSTEM phase. |
| User registry/personalization | Same complete HKCU inventory and binary masks; Quiet Hours uses the source's native COM ABI and recognized CloudStore fallback. Downloads copies HKLM to HKCU without resetting saved views. |
| Debloat | Same 40 AppX targets, 4 capability targets and Recall; sequential checked removal. The source's OneNote **desktop** special uninstaller is deferred because arbitrary uninstall strings may affect an existing Office suite; its AppX package remains targeted. |
| OneDrive | Same removal/blocking intent and default-profile auto-install prevention, adapted to verified identity and guarded software paths. No forced process termination, recursive ACL takeover or deferred file deletions. |
| .NET Framework 3.5 | If not enabled, requires matching local media; no Windows Update fallback. Supply `-NetFx3Source "D:\sources\sxs"` in Full mode (replace `D:` with your mounted media drive). Without a source it is left unchanged and reported. |
| Start pins / encryption | ADMX-exact machine policy pair `ConfigureStartPins` (DWord 1) + `ConfigureStartPinsJSON` (REG_EXPAND_SZ path) pointing to a persistent `LayoutModification.json` with `applyOnce`; the pair was validated manually on 26H2, while the integrated clean-install test is pending. `PreventDeviceEncryption` does not decrypt existing BitLocker encryption. |
| Cloud optimized content | Machine policy `DisableCloudOptimizedContent` (DWord 1) suppresses cloud optimized content to prevent promotional taskbar pins, such as the Outlook for Windows placeholder, for new profiles. It does not remove pins that already exist, affects personalized cloud content globally (Windows Spotlight wallpapers become unavailable), is listed for Enterprise/Education editions in the CSP reference (no documented Pro support) and was only visually checked with a new user on Windows 11 Pro 26H2; integrated clean-install validation is pending. |
| Start menu All apps view | Initial `AllAppsViewMode` (DWord 2 = List) written once in HKCU only when the value is absent; an existing user choice (List, Grid or Category) is preserved. It is a normal user preference, not a policy: no recurring policy or task is created and the view can be changed later. |
| Setup/OOBE | Not reproduced: hardware bypasses, ProductKey/EULA, BypassNRO/OOBE screens, network disabling/re-enabling, installation and account creation. |
| One-shot / cleanup | No Setup tasks, tokens, completion markers or Setup-folder cleanup are created. Logs are retained; restart is optional. |

Previously saved Downloads grouping can remain because `Bags`/`BagMRU` are
preserved. Existing HKCU context-menu entries can also override the machine
Classes view. Policy effectiveness can depend on Windows edition or management
policy; the internal Quiet Hours interface and Paint AI UI limitations still
apply. Review the complete source-line coverage matrix in the script header.

Setup originally runs the system phase as SYSTEM; this standalone uses an
administrator. Protected existing registry keys or in-use AppX packages can
fail and produce exit code 1; no ACL takeover is added to force those changes.

## File integrity (SHA-256)

Hashes of the current documented baseline:

```text
autounattend.xml
0F48BE9ED9AF00039C5581687F1144EF084872FD7C5AF97C6749A8DEDE605F68

ventoy.json
058F0FB83D2BD9EBBB471E518040E04C0CD9D1A752CBBCEC5904166B9EB5908B
```

Verify them on your copy:

```powershell
Get-FileHash -Algorithm SHA256 .\autounattend.xml, .\ventoy.json
```

If the hashes match, you are using the documented baseline. If they differ,
review the files before using them.

Releases publish `SHA256SUMS.txt` to verify the downloaded set. The standalone
hash is documented in the validation section because it changes with each
script revision and is not part of the XML/Ventoy baseline pair.

## Known limitations

- The published v0.1.5 baseline was validated specifically on Windows 11 Pro
  25H2 (historical reference); the current reference is Windows 11 Pro 26H2
  (build base 26300). The integrated answer file still lacks a clean-install
  revalidation of the latest changes and the standalone has no host runtime
  test (static validation plus the isolated test suite only). Other Windows 11
  client builds inside the supported envelope are accepted as
  `NOT_RUNTIME_TESTED` and may require revalidation.
- No hardware-specific drivers are included. Prepare chipset, network, audio
  and GPU drivers yourself.
- .NET Framework 3.5 is enabled only when Windows has it disabled and a local
  `sources\sxs` source with the NetFx3 payload is available on the installation
  media or through `-NetFx3Source`. If no source is available, TMPC downloads
  nothing and records the outcome; enable it later from local media or leave the
  feature disabled.
- Some operations are not reversible: the selected disk is formatted, OneDrive
  is removed/blocked and machine policies are applied. There is no automatic
  rollback; recovery depends on your backup and installation media. Review the
  profile before using it.
- No third-party software is installed by the profile.
- `IQuietHoursSettings`, used to switch Do Not Disturb off, is an internal,
  undocumented COM interface; it may change in future Windows builds.
- Do Not Disturb is left OFF as a checked state at apply time, not as a
  permanent guarantee. Windows 11 can turn Do Not Disturb on again through
  automatic activation (rules available in Settings > System > Notifications:
  during certain times of the day, when duplicating the display, when playing
  a game, when using an app in full-screen mode and for the first hour after a
  Windows feature update; a Focus session also turns it on automatically).
  TMPC does not modify, disable or override those Windows rules, so a
  reactivation of Do Not Disturb does not by itself indicate a TMPC failure.
  The exact cause observed on a real PC is not demonstrated. For the current
  conditions and defaults, see Microsoft Support: "Notifications and Do Not
  Disturb in Windows"
  (https://support.microsoft.com/en-us/windows/experience/notifications-and-do-not-disturb-in-windows).
- The per-user override for the Downloads folder view depends on the current
  Windows behavior and is not a public API; a major update may remove it and
  the one-time task does not re-apply it automatically. Before copying the
  folder type, the profile verifies the installed default
  (`GroupBy = System.DateModified`); that value was verified on the historical
  25H2 reference and has not been re-verified on 26H2. If it differs, the
  override is skipped and the mismatch is recorded as an error instead of
  writing an unverified view.
- Paint may still show some AI-related elements or messages even though its AI
  policies are applied; a fully clean Paint AI UI was not achieved. In the test
  installation, Notepad showed no visible AI features.
- A historical first-logon visual anomaly (light taskbar and wallpaper until a
  logoff/logon) did not reproduce on the current baseline; its root cause is
  still unconfirmed.
- The Start pins policy pair in the current answer file (persistent empty
  layout with `applyOnce`, applied at the next sign-in) was validated manually
  on Windows 11 26H2; the integrated answer file still requires a clean-install
  sign-in validation, and staging the policy does not by itself prove an empty
  Start menu. Taskbar icons are independent of Start pins.
- The `DisableCloudOptimizedContent` machine policy (added to suppress
  promotional taskbar pins such as the Outlook for Windows placeholder on new
  profiles) turns off cloud optimized content globally: personalized cloud
  content and Windows Spotlight wallpapers become unavailable, while static
  wallpapers still work. It does not remove pins that already exist. The CSP
  reference lists the setting for Enterprise/Education editions: it is not
  documented official support for Pro. It was visually checked with a
  genuinely new local user on Windows 11 Pro 26H2 (Outlook not pinned; Edge,
  File Explorer and Microsoft Store kept; empty Pinned section). Integrated
  clean-install validation and side-effect coverage are still pending; the
  historical 25H2 baseline did not include this policy, and the Start pins ADMX
  pair keeps its previous manual 26H2 validation.
- The initial List view for All apps is an `AllAppsViewMode` (DWord 2) user
  preference written during the first-logon user customization phase only when
  the value is absent; an existing preference is never overwritten and the
  setting can be changed later to Grid or Category. On an existing Windows 11
  Pro 26H2 profile, changing the value manually and signing out and back in
  showed the List view (`RUNTIME_EXISTING_PROFILE = PASS`), with Category and
  Grid still available. Automatic application by a clean installation
  (`CLEAN_INSTALL_AUTOMATIC_LIST = NOT_TESTED`) and the standalone runtime
  (`STANDALONE_RUNTIME = NOT_TESTED`) have not been tested; behavior on other
  builds, including the historical 25H2 reference, is also untested.
  `AllAppsViewMode` is an observed registry behavior, not a documented
  Microsoft-supported interface.

## Local static validation

The repository includes a read-only static validator:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-baseline.ps1
```

It checks the repository structure, the XML well-formedness and architecture,
the syntax of the embedded PowerShell, `ventoy.json`, documented hashes, line
endings and documentation links and anchors. It also parses the standalone and
checks its source binding, profile inventories, idempotent registry engine,
layered compatibility preflight and critical static guards. It never executes
either optimizer and does not replace a controlled runtime test.

The isolated automated tests run the same logic against in-memory doubles and
never touch the host registry, filesystem or processes:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\tests\Invoke-TMPCTests.ps1
```

Technical status of the current baseline:

- The answer file targets Windows 11 Pro 26H2 (build base 26300) and stages the
  Start pins policy as the ADMX-exact machine policy pair (`ConfigureStartPins`
  = DWord 1 and `ConfigureStartPinsJSON` = REG_EXPAND_SZ path) pointing to a
  persistent empty layout with `applyOnce`. That pair was validated manually on
  Windows 11 26H2 (empty Pinned section, later user pins preserved), but the
  integrated answer file still requires a clean-install sign-in test before its
  Start result is considered validated.
- The answer file adds the `DisableCloudOptimizedContent` (DWord 1) machine
  policy to suppress cloud optimized promotional taskbar pins for new profiles;
  it does not remove existing pins, and the integrated clean-install result is
  still pending.
- The answer file initializes the All apps view as List (`AllAppsViewMode` =
  DWord 2) in the one-time user phase, only when the value is absent:
  `RUNTIME_EXISTING_PROFILE = PASS` (manual registry change on an existing
  Windows 11 Pro 26H2 profile, List visible after signing out and back in, with
  Category and Grid still available),
  `CLEAN_INSTALL_AUTOMATIC_LIST = NOT_TESTED` and
  `STANDALONE_RUNTIME = NOT_TESTED`.
- The rest of the profile keeps the runtime evidence of the published v0.1.5
  baseline, which was validated on the historical Windows 11 Pro 25H2
  reference.
- The answer file introduces the idempotent verified registry engine (read
  first, write only when a value differs, re-read to verify) and the hardened
  OneNote/OneDrive blocks (no arbitrary uninstall strings, no forced process
  termination, no ownership or ACL changes, no deferred deletions).
- An isolated test suite (`scripts/tests`) exercises the engine and the
  hardening against in-memory doubles.
- The R1 corrections ensure that the unnamed default registry value is read and
  written through the empty value name returned by `GetValueNames()`, that
  `REG_BINARY` writes receive a `byte[]` and are verified byte by byte, that XML
  machine-scope uninstall entries require the explicit `/allusers` argument,
  and that standalone OneDrive machine and user cleanup require independent
  evidence: a user-scope uninstall or a denied registry read never authorizes
  machine-scope cleanup.
- These changes are statically validated and covered by the isolated suite; they
  have not been exercised on a clean installation, and the new XML hash is not
  equivalent to any previously tested hash.
- The local post-v0.3.0 R1 block (an unpublished candidate) fixes H02, H03, H05
  and H06: interactive identity from the Explorer SID and `ProfileList` by SID,
  with selected and linked-elevated token verification; a verifiable SYSTEM/HKCU
  phase summary and cleanup gated on global success; OneDrive
  `PRESENT`/`ABSENT_VERIFIED`/`UNKNOWN` states with independent scopes and
  incomplete-protection deferral; and verified Default hive unload before the
  `R1`-schema marker. It is covered by isolated tests;
  `RUNTIME_VALIDATION = NOT_TESTED` and `N4_RUNTIME_VALIDATION = PENDING`.
- The local R1.1 micro-build consolidates H03: owner/effective ACL checks for
  the diagnostic directory and final file, an execution identity in HKLM,
  schema/revision validation and `OverallStatus` recalculation, read-back
  verification, and `PRESENT`/`ABSENT_VERIFIED`/`UNKNOWN` one-shot task states.
  Cleanup deletes only with `ABSENT_VERIFIED` and every check passing; `UNKNOWN`
  is retried with a bounded limit. It is not a published release and runtime
  validation remains pending.
- The local R2 block adds H01, H04 and H07: GUID-based network restoration
  gated on OOBE, bounded HKCU retries with completed operations preserved, and
  NetFx3 with a validated local source, DISM exit code and final state. Summary
  ACLs use numeric rights masks and the parent directory is checked. Actual
  result: isolated suite **73 OK / 0 FAIL**; static validator
  **416 OK / 0 FAIL / 1 WARN** (expected dirty tree). The local candidate is not
  published and `RUNTIME_VALIDATION = NOT_TESTED`.

Reference code hash:

```text
Apply-TMPCOptimizations.ps1
41528EF61D872AC5AA106E456C4A1F5933C988E5743A1FAAD3B12A0989AD774F
```

## Repository layout

```text
README.md
README.en.md
README.es.md
LICENSE
THIRD_PARTY_NOTICES.md
autounattend.xml
Apply-TMPCOptimizations.ps1
ventoy.json
.gitattributes
docs/
  guia-completa.md
  full-guide.md
  preparacion-previa-instalacion.md
  pre-installation-preparation.md
  configuracion-pruebas-limitaciones-fuentes.md
  configuration-testing-limitations-sources.md
  comprobaciones-posteriores-instalacion.md
  post-installation-checks.md
scripts/
  validate-baseline.ps1
  tests/
    TMPC.Tests.Helpers.ps1
    Invoke-TMPCTests.ps1
```

`README.es.md` is kept as a compatibility page for existing links and does not
replace the main README.

Main files:

- `autounattend.xml`: installation automation and customization profile.
- `Apply-TMPCOptimizations.ps1`: independent Full / UserOnly post-install method.
- `ventoy.json`: Ventoy configuration that binds the ISO to the answer file.
- `.gitattributes`: repository line-ending policy.
- `LICENSE`: project license (MIT).
- `THIRD_PARTY_NOTICES.md`: copyright and license notices for third-party
  portions.
- `scripts/validate-baseline.ps1`: local, read-only static validator.
- `scripts/tests/`: isolated automated tests driven by in-memory doubles; they
  never touch the host registry, filesystem or processes.

## Technical documentation

Advanced reference documents (in English):

- [`pre-installation-preparation.md`](pre-installation-preparation.md):
  pre-installation preparation, backups and driver checklist.
- [`configuration-testing-limitations-sources.md`](configuration-testing-limitations-sources.md):
  applied configuration, validation status, limitations and sources.
- [`post-installation-checks.md`](post-installation-checks.md): detailed
  post-installation hardware and system validation.

Equivalent documents in Spanish:

- [`guia-completa.md`](guia-completa.md): complete guide in Spanish.
- [`preparacion-previa-instalacion.md`](preparacion-previa-instalacion.md):
  pre-installation preparation.
- [`configuracion-pruebas-limitaciones-fuentes.md`](configuracion-pruebas-limitaciones-fuentes.md):
  configuration, testing, limitations and sources.
- [`comprobaciones-posteriores-instalacion.md`](comprobaciones-posteriores-instalacion.md):
  post-installation checks.

This document and the six technical documents are complementary: the guide
explains the complete procedure and the technical documents expand on
preparation, validation status and hardware checks.

## Sources and licensing

- TMPC Windows 11 Optimization is licensed under the MIT License.
  Copyright (c) 2026 Alvaro-TMPC. See [LICENSE](../LICENSE).
- Third-party portions retain their own copyright and license notices; see
  [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).
- Portions of `autounattend.xml` are derived from or based on code distributed
  in [memstechtips/UnattendedWinstall](https://github.com/memstechtips/UnattendedWinstall)
  (reference revision `cca752363772a845eb0fed9d3a5b89b5d0a10d20`, MIT License,
  Copyright (c) 2025 Marco du Plessis). This includes `BloatRemoval.ps1`
  (version 2.3), `OneDriveRemoval.ps1` (version 1.2, locally hardened on the
  TMPC profile) and related helper/automation logic. The local profile has been
  modified and extended for this project.
- The answer file keeps the historical attribution
  <https://github.com/memstechtips/Autounattend> present in those scripts; the
  canonical upstream reference used for licensing and traceability of this
  release is <https://github.com/memstechtips/UnattendedWinstall>.
