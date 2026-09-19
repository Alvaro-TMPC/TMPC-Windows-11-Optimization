# Pre-installation preparation

This document is a checklist to run **before** booting the Windows installer for
a clean installation. It is oriented to the profile of this project:

- Windows 11 25H2 x64 / amd64;
- use for gaming and programming;
- privacy priority;
- clean installation from the repository automation.

It is not a Windows installation tutorial or a partitioning guide. The
installation phase itself and the later validation are documented separately.

## Conventions

- **Essential**: must not be skipped before formatting.
- **Recommended**: reduces risk or later rework; it can be skipped with a
  conscious justification.
- **Only if needed** (or **only if applicable**): depends on whether the
  machine or the user uses that feature or stores that kind of data.

Check boxes are marked when the item has been reviewed and, where applicable,
verified. A verification task is not considered complete just because data was
copied: you must check that the destination is readable.

## 1. Data backup

Review and back up, as applicable to this machine:

- [ ] **Essential**: Desktop.
- [ ] **Essential**: Documents.
- [ ] **Essential**: Downloads you want to keep.
- [ ] **Essential**: Pictures.
- [ ] **Essential**: Videos.
- [ ] **Essential**: Music.
- [ ] **Essential**: projects and local repositories.
- [ ] **Recommended**: files outside the standard user folders: other drives,
      folders created at the drive root, custom working paths or application
      directories.
- [ ] **Only if applicable**: virtual machines and their disks.
- [ ] **Only if applicable**: local databases.
- [ ] **Essential**: work-in-progress files.
- [ ] **Recommended**: important application settings that cannot be easily
      rebuilt.

Copying only the standard user folders is not enough if data is stored in
other paths. Before formatting, review the full tree of the drives you are
going to erase and locate any data that lives outside the usual locations.

Backup verification:

- [ ] Open a representative sample of files directly from the backup
      destination, not only from the source.
- [ ] Check that the folder structure and file names are preserved.
- [ ] Confirm that the backup destination is not on a drive that is going to
      be formatted.

## 2. Development and programming

Before formatting:

- [ ] Review every local Git repository.
- [ ] Review uncommitted changes and decide for each one whether to keep it,
      consciously discard it or move it.
- [ ] Publish or back up commits that are not yet on a remote.
- [ ] Identify the relevant local branches and check that they are backed up.
- [ ] Review untracked files that must be kept.
- [ ] Back up local tool configurations.
- [ ] Back up your own snippets and templates.
- [ ] Back up your editor configuration and its extensions or plugins.
- [ ] Back up development databases if they contain data that cannot be
      regenerated.
- [ ] Back up containers or volumes with data that cannot be regenerated.
- [ ] Back up development virtual machines.
- [ ] Back up SSH keys.
- [ ] Back up GPG keys if you use them.
- [ ] Back up personal certificates if you use them.

Security rules:

- Private keys, tokens, `.env` files, certificates and any credentials must be
  backed up using a private, secure method, never by uploading them to a
  repository.
- Do not move secrets into Git, documentation, screenshots or external
  services not intended for that purpose.
- Do not state or record any real key, token or password value in this
  document or in the repository.

## 3. Browsers, accounts and authentication

Check before formatting:

- [ ] Browser sync, if you use it.
- [ ] Bookmarks that are not covered by sync.
- [ ] Saved passwords that are not synced or exportable.
- [ ] Important extensions and their configuration.
- [ ] Separate browser profiles.
- [ ] Recovery codes and 2FA methods where applicable.

Recovery codes, tokens and passwords must not be stored in this repository or
in public documentation. If they are stored, it must be on a private, secure
medium.

## 4. Games and non-regenerable content

Review individually:

- [ ] Local save games.
- [ ] Games or profiles that do not use cloud saves.
- [ ] Mods and their configuration.
- [ ] Custom settings, controls and profiles.
- [ ] Screenshots and recordings you want to keep.
- [ ] Launcher and platform profiles.
- [ ] Downloaded content that cannot be regenerated or is expensive to
      recover.

Do not take Steam Cloud, Xbox Cloud and other sync systems for granted: check
your important titles game by game. Not every game supports cloud saves, and
some only support them partially.

## 5. OneDrive and cloud files

This project's profile removes and blocks OneDrive in the new installation,
while preserving user data. Before formatting the previous installation:

- [ ] Check that the files you need are really downloaded locally or backed up
      on another medium.
- [ ] Do not assume that a OneDrive placeholder (online-only file) is a
      complete local copy: verify the state of each important folder.
- [ ] Review important content before deleting or abandoning the previous
      installation.

This guide does not modify or uninstall OneDrive; it only covers the prior data
check.

## 6. BitLocker and encryption

Warning:

- Before formatting or handling encrypted drives, check whether BitLocker or
  another encryption system is active and make sure you have the necessary
  recovery keys.
- Without the recovery key, an encrypted volume can become permanently
  inaccessible when the machine, the firmware or the installation changes.
- Recovery keys must not be pasted into the terminal, Git, documentation,
  screenshots or chats as a backup method.
- They must not be stored inside this repository.

Steps:

- [ ] **Only if applicable**: check whether any drive is encrypted with
      BitLocker or another system.
- [ ] **Only if applicable**: confirm that the recovery keys are available
      outside the machine that is going to be formatted.
- [ ] **Only if applicable**: verify that an available recovery key can be
      read and does not depend only on the system that is going to be erased.

Effective encryption management happens outside this guide and is not
automated here. The repository profile applies a policy intended to prevent
automatic device encryption on the new installation, but that does not replace
checking and managing existing encryption.

## 7. Drivers and software to prepare

This project's profile excludes drivers distributed through Windows Update, so
this section matters. Prepare in advance, according to the real hardware of the
machine:

Drivers:

- [ ] **Essential**: Ethernet.
- [ ] **Essential if the machine depends on Wi-Fi**: Wi-Fi.
- [ ] **Recommended**: chipset.
- [ ] **Recommended**: audio.
- [ ] **Recommended**: GPU (Intel, AMD or NVIDIA, as applicable to the
      machine).
- [ ] **Only if needed**: storage and controllers, when the installer or boot
      does not recognize the hardware or its mode.
- [ ] **Only if needed**: Bluetooth and other vendor-specific devices, if you
      use them.

Recommendations:

- Obtain drivers preferably from official sources of the hardware or machine
  manufacturer.
- No specific driver models, versions or links are recommended: the selection
  depends on the exact hardware and must be verified before installation. If
  the hardware is not confirmed, treat its drivers as not yet applicable.
- Do not assume every device needs manual driver installation: some may work
  or be completed in another way after installation. Prepare at least the
  critical ones.
- Have the drivers on a medium accessible during installation, not only on the
  machine that is going to be formatted.

Software:

- [ ] **Recommended**: have the installers ready for the software you will use
      immediately after installing (browser, development tools, game
      launchers, usual utilities). This repository does not install
      third-party software automatically.

### Optional third-party recommendation: Visual C++ Redistributable

As an optional convenience, you may prepare the "Visual C++ Redistributable
Runtime Package All-in-One" package published by TechPowerUp:

- Source: <https://www.techpowerup.com/download/visual-c-redistributable-runtime-package-all-in-one/>
- It is not an official Microsoft package: it is a third-party collection.
- It is an optional recommendation; using it is not a requirement of
  `autounattend.xml` or of this project.
- Before downloading or using it, verify the current source page and its terms
  of use, distribution and license.
- This repository does not assert any specific license for that package
  because it has not verified one.

## 8. Prior inventory

If useful as a reference, keep a minimal inventory of:

- [ ] Important installed applications.
- [ ] Development tools.
- [ ] Game launchers and platforms.
- [ ] Special peripherals and their associated software.
- [ ] Special network configuration.
- [ ] Software with licenses or activations that must be recovered.

The inventory may include application names and configuration notes, but it
must not collect product keys, credentials or real identifiers.

## 9. Installation media

According to the current repository files:

- The target platform is Windows 11 25H2 x64 / amd64.
- The media is prepared with Ventoy and its `ventoy.json` configuration.
- The expected answer file is `autounattend.xml`.
- The Ventoy configuration declares a specific installation entry with that
  file as its template. That entry must match the installation image actually
  present on the media.

Checks:

- [ ] **Essential**: prepare and review the media before booting the target
      machine.
- [ ] **Essential**: confirm that the installation image present on the media
      matches the entry declared in `ventoy.json`.
- [ ] **Recommended**: check that `autounattend.xml` is present at the path
      expected by the Ventoy configuration.
- [ ] **Recommended**: test booting the media on a disposable machine or
      environment before using it on the final machine.

No specific ISO, build or download source is recommended here. The image must
be obtained from a trusted source and match the target platform.

Note: this repository's profile does not automate disk selection or disk
erasure. That decision is made manually in the installer and must be reviewed
carefully at installation time.

## 10. Final check before formatting

Confirm every check box before continuing:

- [ ] Backup done.
- [ ] Backup verified by opening files from the destination.
- [ ] Important projects and repositories safe.
- [ ] Secrets and private keys backed up securely and outside Git.
- [ ] Important game saves and content backed up.
- [ ] OneDrive or other cloud service data verified as really local or backed
      up.
- [ ] Encryption recovery keys available, if applicable.
- [ ] Critical drivers prepared and accessible.
- [ ] Installer and installation media prepared and reviewed.
- [ ] External devices that must NOT be touched identified.
- [ ] User aware that a clean installation can erase data irreversibly.

## 11. Out of scope

- This guide does not install Windows or select disks or partitions.
- This guide does not modify, disable or unlock BitLocker or any other
  encryption.
- This guide does not configure drivers, accounts or software on the
  destination system.
- A correct preparation does not by itself prove that the installation will
  work: real validation is done after installing and using the system.
