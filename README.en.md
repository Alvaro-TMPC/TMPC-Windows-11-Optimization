# TMPC Windows 11 Optimization

[Español](README.md) | **English**

A reproducible profile to install Windows 11 from scratch or optimize an
existing installation. It conservatively reduces bloatware, strengthens
privacy and keeps the system ready for gaming, programming and everyday use. It
has no graphical interface, does not install third-party software and does not
use remote installation commands.

## Key features

- **Privacy:** minimal telemetry, advertising ID and tailored experiences
  disabled; cloud activity, cross-device clipboard and location access blocked;
  Copilot and on-device AI model access disabled.
- **Conservative debloat:** removes consumer apps and legacy components while
  keeping Microsoft Defender, Microsoft Store, Edge/WebView2, Photos, Paint and
  Notepad.
- **Working Windows:** Windows Update and Defender stay active, Windows Update
  drivers are excluded, Store remains available and OneDrive is removed without
  deleting existing data in `%USERPROFILE%\OneDrive`.
- **Gaming and power:** Game Mode enabled, Game DVR and Xbox Live services
  disabled, Balanced power plan, hibernation and Fast Startup disabled.
- **Interface:** dark theme, transparency disabled, Explorer with file
  extensions and hidden files visible, classic context menu, Downloads without
  date grouping and a Start menu without promotional pins on new profiles.
- **No risky tweaks:** CPU, GPU, scheduler and network settings are not changed
  without a demonstrated need.

## Requirements and compatibility

- Target platform: Windows 11 Pro 26H2, x64 / amd64 (build base 26300; the OS
  revision/UBR is not fixed).
- UEFI/amd64 installation with a genuine Windows 11 x64 ISO and a USB drive you
  can erase.
- The published v0.1.5 baseline was validated on Windows 11 Pro 25H2 as a
  historical reference; that evidence is not attributed to 26H2.
- The post-install optimizer requires Windows 11 client (build 22000 or later),
  native AMD64 Windows PowerShell 5.1 and a real user account. Full mode
  requires an elevated console.
- Windows Server, Windows 10 or older families and non-AMD64/32-bit hosts are
  not supported.
- No drivers or third-party software are included: prepare them before
  formatting.

## Two ways to use it

### Clean installation with Ventoy

1. Prepare verified backups, drivers and a genuine Windows 11 ISO.
2. Create the USB drive with [Ventoy](https://www.ventoy.net/) and copy
   `ventoy.json` to `\ventoy\ventoy.json` and `autounattend.xml` to
   `\ventoy\script\autounattend.xml`.
3. Boot the USB drive, select the ISO and choose
   `Boot with /ventoy/script/autounattend.xml`.
4. Install Windows and select the target disk manually. The profile does not
   select or erase disks.

The complete procedure, USB layout, Windows Setup, DiskPart, first logon and
automatic restart are in the
**[full guide in English](docs/full-guide.md)**.

### Post-install optimization

For an existing Windows 11 installation, use the self-contained
[`Apply-TMPCOptimizations.ps1`](Apply-TMPCOptimizations.ps1) script. It does not
format or change disks, accounts or licenses.

```powershell
# Full mode, from Windows PowerShell as administrator
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Apply-TMPCOptimizations.ps1
```

```powershell
# Current-user preferences only, no elevation
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Apply-TMPCOptimizations.ps1 -UserOnly
```

Review the script and make a backup before running it. Parameters, coverage
matrix, logs and exit codes are in the
**[full guide](docs/full-guide.md#apply-the-optimizations-to-an-existing-windows-installation)**.

## Download

The latest stable version is **v0.3.0**, available from the
[v0.3.0 stable release](https://github.com/Alvaro-TMPC/TMPC-Windows-11-Optimization/releases/tag/v0.3.0).
The **v0.4.0-rc.1** prerelease, published on 27 November 2026, is available
from the
[v0.4.0-rc.1 release](https://github.com/Alvaro-TMPC/TMPC-Windows-11-Optimization/releases/tag/v0.4.0-rc.1).

Both releases publish four downloadable assets with the same names:
`autounattend.xml`, `ventoy.json`, `Apply-TMPCOptimizations.ps1` and
`SHA256SUMS.txt`. The `v0.3.0` assets are immutable and keep their historical
hashes; the `v0.4.0-rc.1` assets have their own hashes. Verify each download
with `SHA256SUMS.txt`; there is no executable installer or remote command such
as `irm ... | iex`.

## Essential warning

- **Make a full backup and verify it is readable.** A clean installation can
  destroy data irreversibly and there is no automatic rollback.
- **You choose the disk.** The profile does not select or erase disks; confirm
  the disk and partitions before continuing.
- **Review the answer file** before using it. You are responsible for what it
  applies to your machine.
- **Test on a virtual or disposable machine first** if you can.
- OneDrive is removed, but existing content in `%USERPROFILE%\OneDrive` is
  preserved. Online-only files are not backed-up local copies.

## Validation status

- Published BUILD of `v0.4.0-rc.1` (commit `ca3ba37`): **73 isolated tests
  OK / 0 FAIL** and **416 static checks OK / 0 FAIL**.
- Runtime of the exact `v0.4.0-rc.1` candidate: **NOT_TESTED**. No clean
  installation or optimizer run on the host has been performed.
- Historical runtime evidence: v0.1.5 baseline on Windows 11 Pro 25H2.
- The static validator and isolated tests are not equivalent to a real run;
  `RUNTIME_PASS` is not claimed for `v0.3.0` or `v0.4.0-rc.1`.
- N4 runtime validation is deferred by the user's decision
  (`N4_RUNTIME_VALIDATION = DEFERRED_BY_USER`).

## Complete documentation

- **[Full guide in English](docs/full-guide.md)** and
  **[guía completa en español](docs/guia-completa.md)**: installation, modes,
  coverage matrix, hashes, limitations and sources.
- [Pre-installation preparation](docs/pre-installation-preparation.md) and
  [Preparación previa a la instalación](docs/preparacion-previa-instalacion.md).
- [Configuration, testing, limitations and sources](docs/configuration-testing-limitations-sources.md)
  and [Configuración, pruebas, limitaciones y fuentes](docs/configuracion-pruebas-limitaciones-fuentes.md).
- [Post-installation checks](docs/post-installation-checks.md) and
  [Comprobaciones posteriores a la instalación](docs/comprobaciones-posteriores-instalacion.md).
- [README.es.md](README.es.md): compatibility page for old links. GitHub does
  not automatically redirect links or anchors.

## MIT License

TMPC Windows 11 Optimization is distributed under the MIT License.
Copyright (c) 2026 Alvaro-TMPC. See [LICENSE](LICENSE) and the third-party
notices in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
