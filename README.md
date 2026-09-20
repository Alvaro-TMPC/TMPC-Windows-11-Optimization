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
endings and documentation links. It never executes the embedded scripts and it
does not replace a real clean installation.

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
