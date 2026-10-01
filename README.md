# TMPC Windows 11 Optimization

**English** | [Español](README.es.md)

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
[`Apply-TMPCOptimizations.ps1`](Apply-TMPCOptimizations.ps1) applies the relevant
post-install portion of the same profile; see the section below.

Target platform: Windows 11 25H2, x64 / amd64.

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
  distributed through Windows Update are excluded;
- Microsoft Defender stays enabled; only non-critical Windows Security
  notifications are reduced;
- Microsoft Store stays available for app installation, repair and dependency
  installation;
- OneDrive is removed and blocked, while existing user data in the OneDrive
  folder is preserved;
- Paint and Notepad stay installed with their AI features disabled by policy
  (Cocreator, Generative Fill, Image Creator and Notepad AI);
- Do Not Disturb is configured to OFF;
- Game Mode is enabled; Game DVR and the Xbox Live companion services are
  disabled;
- power plan is the standard Windows Balanced plan; hibernation and Fast Startup
  are disabled (Sleep and Hibernate entries are hidden from the Start power
  menu, Windows locking stays available);
- transparency effects are disabled and the default theme is dark;
- File Explorer: compact view enabled, item check boxes disabled, file name
  extensions visible and hidden files visible (protected operating system files
  stay hidden), classic context menu, cleaned Quick Access;
- Downloads opens without "Group by date" grouping (per-user folder view
  override); normal folders keep the native Windows 11 default;
- No aggressive CPU, GPU, scheduler or network tweaks are applied.

Windows AI features that are disabled by the profile: Recall, Click to Do,
Settings AI agent, Paint Cocreator, Paint Generative Fill, Paint Image Creator,
Notepad AI features and legacy Windows Copilot entry points.

This README summarizes the behavior; it is not a full registry dump. The
answer file remains the authoritative source.

## Tested environment

The baseline has completed real clean installations on Windows 11 Pro 25H2
(x64 / amd64), including:

- Setup, OOBE and first desktop reached without blocking errors;
- local account creation with no mandatory network or Microsoft account prompt;
- user-specific customizations applied with a one-time task;
- automatic restart executed by the profile and final desktop reached;
- final cleanup completed with no leftover setup tasks or temporary files;
- Explorer defaults and the Downloads view override verified.

Other Windows 11 versions, editions or builds are not guaranteed. Future builds
may require revalidation.

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

## Apply the optimizations to an existing Windows installation

`autounattend.xml` remains the clean-install method. The self-contained
[`Apply-TMPCOptimizations.ps1`](Apply-TMPCOptimizations.ps1), standalone version
0.1.0, provides a post-install method **without formatting**, derived directly
from the v0.1.5 answer file. It needs no other repository files, external
dependencies or downloads.

**Reference: Windows 11 Pro 25H2 x64 / amd64.** The script accepts only Windows
11 25H2 (build 26200) in native x64 Windows PowerShell 5.1. The clean-install
baseline has runtime evidence on that reference; this new standalone has only
static validation and has **not** yet been tested on hardware or in a VM.
Other versions/builds are untested and are rejected. This is not a claim of
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
are reported and deferred; verify warnings/errors before considering removal done.
Windows' own OneDrive setup binaries are preserved.

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

### Coverage and post-install differences

| Baseline block | Post-install behavior |
| --- | --- |
| System registry/policies | Same HKLM names, types and values: privacy, Update/driver exclusion, Defender notifications, gaming, power, AI, Explorer, Start/Taskbar and sound. HKCR deletions resolve to machine Classes, matching the original SYSTEM phase. |
| User registry/personalization | Same complete HKCU inventory and binary masks; Quiet Hours uses the source's native COM ABI and recognized CloudStore fallback. Downloads copies HKLM to HKCU without resetting saved views. |
| Debloat | Same 40 AppX targets, 4 capability targets and Recall; sequential checked removal. The source's OneNote **desktop** special uninstaller is deferred because arbitrary uninstall strings may affect an existing Office suite; its AppX package remains targeted. |
| OneDrive | Same removal/blocking intent and default-profile auto-install prevention, adapted to verified identity and guarded software paths. No forced process termination, recursive ACL takeover or deferred file deletions. |
| .NET Framework 3.5 | If not enabled, requires matching local media; no Windows Update fallback. Supply `-NetFx3Source "D:\sources\sxs"` in Full mode (replace `D:` with your mounted media drive). Without a source it is left unchanged and reported. |
| Start pins / encryption | Exact `ConfigureStartPins` JSON with `applyOnce`; previously initialized pins may remain. `PreventDeviceEncryption` does not decrypt existing BitLocker encryption. |
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

Full logs: `%ProgramData%\TMPC-Windows-11-Optimization\Logs\`.
UserOnly logs: `%LOCALAPPDATA%\TMPC-Windows-11-Optimization\Logs\` (no elevated
write needed). The final summary shows mode, completed operations, warnings,
errors, restart advice, log path and exit code: 0 = completed (review warnings
for limitations), 1 = operation/log failure, 2 = preflight rejection, 3 = system
phase finished but target-user preferences deferred. There is no automatic
rollback. The validator checks the source XML SHA-256 binding and exact
registry/removal inventories, so future baseline changes require explicit review.

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
   ├── Win11_25H2_Spanish_x64_v2.iso
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
     `Win11_25H2_Spanish_x64_v2.iso`.

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
   `Win11_25H2_Spanish_x64_v2.iso`. Ventoy then shows the boot menu for that
   image: choose `Boot with /ventoy/script/autounattend.xml` to install with
   the profile, or `Boot without auto installation template` to boot the plain
   ISO without applying `autounattend.xml`.
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
[Post-installation checks](docs/post-installation-checks.md).

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
validation described below.

For detailed hardware checks (PCIe link with GPU-Z, display, RAM, storage and
peripherals), see [Post-installation checks](docs/post-installation-checks.md).

## File integrity (SHA-256)

Hashes of the current documented baseline:

```text
autounattend.xml
70D5DA63FEA8078FDA45F8F20FCA82E4A476060DDB5304EDEB3DA8A21CC95FF6

ventoy.json
2231E01E9B0BA0622888D97EFEDA0F476DBD73A9CB90B11B48656E1F889F2796
```

Verify them on your copy:

```powershell
Get-FileHash -Algorithm SHA256 .\autounattend.xml, .\ventoy.json
```

If the hashes match, you are using the documented baseline. If they differ,
review the files before using them.

## Known limitations

- Validated specifically on Windows 11 25H2. Compatibility with other
  versions, editions or builds is not tested; future builds may require
  revalidation.
- No hardware-specific drivers are included. Prepare chipset, network, audio
  and GPU drivers yourself.
- No third-party software is installed by the profile.
- `IQuietHoursSettings`, used to switch Do Not Disturb off, is an internal,
  undocumented COM interface; it may change in future Windows builds.
- The per-user override for the Downloads folder view depends on the current
  Windows behavior and is not a public API; a major update may remove it and
  the one-time task does not re-apply it automatically.
- Paint may still show some AI-related elements or messages even though its AI
  policies are applied; a fully clean Paint AI UI was not achieved. In the test
  installation, Notepad showed no visible AI features.
- A historical first-logon visual anomaly (light taskbar and wallpaper until a
  logoff/logon) did not reproduce on the current baseline; its root cause is
  still unconfirmed.

## Repository layout

```text
README.md
README.es.md
LICENSE
THIRD_PARTY_NOTICES.md
autounattend.xml
Apply-TMPCOptimizations.ps1
ventoy.json
.gitattributes
docs/
  preparacion-previa-instalacion.md
  pre-installation-preparation.md
  configuracion-pruebas-limitaciones-fuentes.md
  configuration-testing-limitations-sources.md
  comprobaciones-posteriores-instalacion.md
  post-installation-checks.md
scripts/
  validate-baseline.ps1
```

Main files:

- `autounattend.xml`: installation automation and customization profile.
- `Apply-TMPCOptimizations.ps1`: independent Full / UserOnly post-install method.
- `ventoy.json`: Ventoy configuration that binds the ISO to the answer file.
- `.gitattributes`: repository line-ending policy.
- `LICENSE`: project license (MIT).
- `THIRD_PARTY_NOTICES.md`: copyright and license notices for third-party
  portions.
- `scripts/validate-baseline.ps1`: local, read-only static validator.

## Local static validation

The repository includes a read-only static validator:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate-baseline.ps1
```

It checks the repository structure, the XML well-formedness and architecture,
the syntax of the embedded PowerShell, `ventoy.json`, documented hashes, line
endings and documentation links. It also parses the standalone and checks its
source binding, profile inventories and critical static guards. It never
executes either optimizer and does not replace a controlled runtime test.

## Technical documentation

Advanced reference documents (in English):

- [`docs/pre-installation-preparation.md`](docs/pre-installation-preparation.md):
  pre-installation preparation, backups and driver checklist.
- [`docs/configuration-testing-limitations-sources.md`](docs/configuration-testing-limitations-sources.md):
  applied configuration, validation status, limitations and sources.
- [`docs/post-installation-checks.md`](docs/post-installation-checks.md):
  detailed post-installation hardware and system validation.

No step required to install the profile exists only in those documents; this
README is self-sufficient.

## Sources and licensing

- TMPC Windows 11 Optimization is licensed under the MIT License.
  Copyright (c) 2026 Alvaro-TMPC. See [LICENSE](LICENSE).
- Third-party portions retain their own copyright and license notices; see
  [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- Portions of `autounattend.xml` are derived from or based on code distributed
  in [memstechtips/UnattendedWinstall](https://github.com/memstechtips/UnattendedWinstall)
  (reference revision `cca752363772a845eb0fed9d3a5b89b5d0a10d20`, MIT License,
  Copyright (c) 2025 Marco du Plessis). This includes `BloatRemoval.ps1`
  (version 2.3), `OneDriveRemoval.ps1` (version 1.2) and related
  helper/automation logic. The local profile has been modified and extended for
  this project.
- The answer file keeps the historical attribution
  <https://github.com/memstechtips/Autounattend> present in those scripts; the
  canonical upstream reference used for licensing and traceability of this
  release is <https://github.com/memstechtips/UnattendedWinstall>.
