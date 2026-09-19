# Post-installation checks

This guide is also available in Spanish:
[Comprobaciones posteriores a la
instalación](comprobaciones-posteriores-instalacion.md).

This guide collects the checks you can run after installing TMPC Windows 11
Optimization: from the final desktop to a short stability test. It covers
Windows, drivers, the GPU and its PCIe link, the monitor, RAM, storage, the
behavior promised by the TMPC baseline and the main peripherals.

It assumes that the installation is complete: you have reached the final
desktop, the automatic restart scheduled by the profile has happened and the
normal cleanup has finished. Installing the profile itself is documented in
the [README](../README.md).

Keep in mind:

- not every check applies to every machine. Skip the ones that do not match
  your hardware or your use case;
- a result that differs from an example in this guide is not automatically a
  failure. Compare every result with the real specifications of your GPU,
  CPU, motherboard, RAM, storage and monitor;
- this guide only explains how to check the system. The profile does not
  configure the firmware or hardware settings mentioned here: PCIe lanes,
  Resizable BAR, refresh rate, XMP/EXPO, Secure Boot, drivers or firmware.

## Priority labels

- **Essential**: basic installation or usability requirement.
- **Recommended**: reduces risk or avoids rework; it can be skipped with a
  conscious justification.
- **Optional**: useful only on some systems or for some users.
- **Only if there is a problem**: diagnostic steps that are not part of the
  normal checklist and should only be used when there is a symptom.

## 1. Starting point

Run these checks after:

- reaching the final desktop;
- the automatic restart scheduled by the profile (the system shows about
  20 seconds of notice);
- the normal cleanup of the profile has finished. The temporary setup files
  and the one-time tasks are removed automatically; the README describes the
  expected flow.

An example result in this guide is illustrative, not a universal target.
Hardware differences (GPU model, PCIe generation, lane count, memory kit,
monitor, network infrastructure) can produce different, still correct
results.

## 2. Windows, network and drivers

- [ ] **Essential**: check that Ethernet and/or Wi-Fi connectivity works. If
      the adapters are disabled after installation, enable them from Windows
      Settings or Device Manager.
- [ ] **Essential**: open Device Manager and check that there are no unknown
      devices and no warning icons. A device can still show a warning until
      its OEM driver is installed; recheck after installing the drivers.
- [ ] **Essential**: install the OEM/official drivers you prepared before the
      installation: chipset, Ethernet, Wi-Fi, audio, GPU and Bluetooth, plus
      any other device specific to your machine, when applicable.
- [ ] **Essential**: run Windows Update normally to install quality and
      security updates. Remember that this profile excludes drivers
      distributed through Windows Update; hardware drivers are installed
      separately.
- [ ] **Optional**: if you plan to activate Windows, check Settings > System
      > Activation. The product key in the answer file is a placeholder, not
      a license.

Install drivers from the manufacturer of your hardware or computer. This
project does not recommend third-party automatic driver updater tools.

## 3. GPU and PCIe link (GPU-Z)

**Optional, third-party utility.** GPU-Z is a free utility published by
TechPowerUp that reports detailed information about the graphics card and
its PCIe link. This project is not affiliated with TechPowerUp, does not
redistribute GPU-Z and does not include it as a dependency. If you want to
use it, download it from its official site:
<https://www.techpowerup.com/gpuz/>.

### Bus Interface: maximum capability and current link

The `Bus Interface` field reports two different things:

- the maximum link the card supports, for example `PCIe x16 4.0`;
- the link currently negotiated, shown after the `@`, for example
  `@ x16 3.0`.

A GPU does NOT have to run at PCIe x16 in every system. The effective width
and generation depend on:

- the design of the GPU itself: some models use x8 by design, others use x16;
- the CPU, the motherboard and the specific slot in use (a physically long
  slot can be electrically x8 or x4);
- the platform: some motherboards share lanes between the main PCIe slot and
  M.2 slots or other devices.

Power saving features can reduce the negotiated speed or generation of the
PCIe link while the GPU is idle. The number of lanes (x16, x8 or x4) depends
on the design of the GPU, the CPU, the motherboard, the slot in use and the
lane distribution of the platform; a reduced lane count is not normal power
saving behavior. Always check the link under load before diagnosing a
problem:

1. open GPU-Z;
2. start the render test tied to the `Bus Interface` field;
3. watch the negotiated link while the test runs.

Example (illustrative only, **not a universal target**):

```text
Idle:       PCIe x16 4.0 @ x16 1.1
Under load: PCIe x16 4.0 @ x16 4.0
```

Those values are NOT a requirement. A PCIe 4.0 x8 card working at x8 can be
perfectly correct; do not treat the absence of x16 as a failure by itself.
Compare the result with the specifications of your GPU, CPU and motherboard
and with the slot you are really using.

### Resizable BAR

- [ ] **Optional**: check Resizable BAR if your GPU and platform support it.
      GPU-Z shows whether it is enabled and additional details. It is not a
      universal requirement: support and behavior depend on the GPU, the
      motherboard and the firmware.

Do not change BIOS/UEFI settings automatically because a value does not
match an example. First consult the documentation of your GPU, CPU and
motherboard.

## 4. Display

- [ ] **Essential**: set the native resolution of the monitor.
- [ ] **Essential**: set a refresh rate the monitor supports (Settings >
      System > Display > Advanced display). A common mistake after a clean
      installation is staying accidentally at 60 Hz on a monitor that
      supports more.
- [ ] **Recommended**: use a reasonable display scale (100 %, 125 %,
      150 %...) so that text and windows are comfortable at the chosen
      resolution.
- [ ] **Optional**: enable HDR only if your monitor and your use case
      benefit from it.
- [ ] **Optional**: enable VRR / FreeSync / G-SYNC when your monitor and GPU
      support it.
- [ ] **Recommended**: check that the monitor is connected to the GPU you
      intend to use. On a conventional desktop PC oriented to gaming with a
      dedicated GPU, the dedicated GPU outputs are normally used. Laptops,
      hybrid/muxless systems and multi-GPU configurations can work
      differently, so a motherboard video output is not universally wrong.

The profile does not configure any of these settings; this guide only shows
how to check and adjust them. There is no single correct combination: HDR,
VRR and a specific refresh rate depend on your hardware and your preferences.

## 5. RAM

- [ ] **Essential**: check that Windows recognizes the total installed
      memory (Task Manager > Performance > Memory).
- [ ] **Recommended**: check the installed modules and slots, and the total
      capacity.
- [ ] **Recommended**: check the configured memory speed/data rate. Task
      Manager and `Get-CimInstance Win32_PhysicalMemory` show the speed
      Windows is using.
- [ ] **Optional**: check the channel mode (single/dual/quad) only when the
      firmware or a suitable platform tool reports it.
- [ ] **Optional**: check XMP/EXPO only if you expected to use it. XMP/EXPO
      is a firmware (BIOS/UEFI) profile of the motherboard; it is not a TMPC
      setting.

Read-only check:

```powershell
Get-CimInstance Win32_PhysicalMemory |
  Select-Object BankLabel, DeviceLocator, Capacity, Speed, ConfiguredClockSpeed
```

`Get-CimInstance Win32_PhysicalMemory` is useful to inventory the installed
modules and to read `Speed` and `ConfiguredClockSpeed`, but it is not a
reliable test for single, dual or quad channel mode; the channel mode is
reported by the firmware or by a suitable tool for your platform.

There is no universally correct memory frequency: compare the configured
memory speed/data rate with the specifications of your CPU, motherboard and
memory kit. DDR memory data rates are usually expressed in MT/s even when a
tool labels them as MHz; do not confuse the real clock frequency with the DDR
data rate. If the memory runs below its rated speed and you expected to use
XMP/EXPO, review that setting in the firmware. Do not apply manual
overclocking.

## 6. Storage and boot

- [ ] **Essential**: check that all expected SSD/HDD drives appear, with
      their approximate capacity (Task Manager > Performance, or Disk
      Management).
- [ ] **Recommended**: check the health status of the drives when the system
      can report it.
- [ ] **Essential**: confirm that the target installation follows the
      documented UEFI/GPT flow. In Windows, `msinfo32` shows `BIOS Mode` in
      its System Summary and Disk Management shows the partition style (GPT
      for the documented flow).
- [ ] **Recommended**: check that TRIM is enabled on SSDs.

Read-only checks from PowerShell:

```powershell
Get-PhysicalDisk |
  Select-Object FriendlyName, MediaType, HealthStatus, OperationalStatus
Get-Disk |
  Select-Object Number, FriendlyName, PartitionStyle, BusType
Get-Volume |
  Select-Object DriveLetter, FileSystem, HealthStatus, Size, SizeRemaining
```

TRIM check:

```text
fsutil behavior query DisableDeleteNotify
```

For NTFS, `DisableDeleteNotify = 0` means the delete-notification (TRIM)
behavior is enabled; a value of 1 means it is disabled. This reports the
Windows setting, not the physical state of the drive: it is not an absolute
proof of SSD health. For more detail, use the health status reported by the
drive and, if needed, the tool from its manufacturer.

Do not use destructive benchmarks or intensive writes as an obligatory step;
they are not necessary to validate a normal installation.

## 7. TMPC baseline checklist

This checklist verifies the behavior promised by the profile. It is a
detailed version of the quick checklist in the README.

Security and updates:

- [ ] Microsoft Defender is active.
- [ ] Windows Security reports no critical warnings.
- [ ] Windows Update is available for quality and security updates. Driver
      updates distributed through Windows Update stay excluded.

Kept components:

- [ ] Microsoft Store opens.
- [ ] Edge and WebView2 are present.
- [ ] Microsoft Photos is present.
- [ ] Paint is present.
- [ ] Notepad is present.

Removed components:

- [ ] OneDrive is not installed.

Gaming and power:

- [ ] Game Mode is enabled (Settings > Gaming > Game Mode).
- [ ] Game DVR is disabled (Settings > Gaming > Captures).
- [ ] The active power plan is Balanced.
- [ ] Hibernation is disabled.
- [ ] Fast Startup is disabled.

Interface:

- [ ] Do Not Disturb is off.
- [ ] Transparency effects are disabled.
- [ ] The default theme is dark.

File Explorer:

- [ ] Compact view is enabled.
- [ ] File name extensions are visible.
- [ ] Hidden files are visible.
- [ ] Protected operating system files stay hidden ("Hide protected
      operating system files" remains enabled in Folder Options).
- [ ] Item check boxes are disabled.

Downloads:

- [ ] Downloads opens with Group by = None (no grouping by date).
- [ ] Close and reopen Downloads (or File Explorer): the view without
      grouping persists.

Paint limitation: the profile applies the Paint AI policies, but Paint can
still show certain AI-related options or messages. A completely clean Paint
AI interface was not achieved, so do not expect Paint to be free of those
elements.

## 8. Connectivity and peripherals

Check, as they apply to your machine:

- [ ] **Essential**: Ethernet works.
- [ ] **Recommended**: if the Ethernet adapter is 2.5/5/10 GbE, check the
      negotiated link speed. It should match the infrastructure you have
      available. Do not expect the maximum theoretical speed if the switch,
      the cabling or the other end do not support it.
- [ ] **Essential if you use Wi-Fi**: Wi-Fi works with the expected band and
      performance in your environment.
- [ ] **Recommended if you use it**: Bluetooth pairs and works with your
      devices.
- [ ] **Essential**: audio output works (speakers, headphones, monitor
      speakers).
- [ ] **Recommended**: microphone input works.
- [ ] **Recommended**: webcam works.
- [ ] **Recommended**: the USB ports you use enumerate their devices.
- [ ] **Optional**: game controllers work.
- [ ] **Optional**: printers and scanners work.
- [ ] **Optional**: special peripherals (capture cards, audio interfaces,
      drawing tablets, steering wheels...) work with their vendor drivers.

## 9. Security and firmware

- [ ] **Essential**: Microsoft Defender is active and Windows Security shows
      no critical alerts.
- [ ] **Essential**: Windows Firewall is enabled for the active networks.
- [ ] **Only if it applies**: check the TPM and Secure Boot state if your
      hardware and your policy use them. `msinfo32` (System Summary) and
      `tpm.msc` show their state in read-only mode.

Note: the answer file skips the TPM and Secure Boot requirement checks during
Setup. That does NOT mean that the profile disables TPM or Secure Boot: those
checks are bypassed for installation and the profile does not change the
firmware state. Do not change firmware settings that you do not need.

## 10. Stability smoke test

A short, reasonable test is enough to gain confidence:

- [ ] **Recommended**: open your usual applications and use them for a few
      minutes.
- [ ] **Recommended**: play audio and video.
- [ ] **Recommended on a gaming PC**: run a game or a 3D workload for a
      short session.
- [ ] **Recommended**: watch for obvious crashes, freezes, driver errors or
      unexpected restarts.
- [ ] **Optional**: watch temperatures with the monitoring tool you prefer.
      Reasonable limits depend on the exact hardware, its cooling and its
      design; there are no universal thresholds.

This is a smoke test, not a certification. It does not require hours of
stress, specific benchmark scores, universal temperature values,
overclocking or undervolting.

## 11. Diagnose only if there is a problem

This section is separate from the normal checklist. Use it only when a real
symptom appears: crashes, freezes, errors or abnormal performance.

- Event Viewer (`eventvwr.msc`) to locate errors around the moment of the
  symptom.
- Reliability Monitor (`perfmon /rel`) for a timeline of failures.
- `sfc /scannow` and `DISM /Online /Cleanup-Image /RestoreHealth` to check
  system files, from an elevated console.
- Windows Memory Diagnostic (`mdsched.exe`) if you suspect memory errors.
- Specific CPU, GPU, disk or network diagnostics if you need to reproduce
  and isolate the problem.
- Diagnostics from the vendor of the specific hardware.

Do NOT run `sfc /scannow` or DISM as a mandatory ritual after every
installation when there is no symptom. They are diagnostic tools; they are
not part of the normal post-installation checklist.

## See also

- [README](../README.md): project overview, installation and baseline
  summary.
- [Pre-installation preparation](pre-installation-preparation.md):
  backups, drivers and installation media before formatting.
- [Applied configuration, tests and
  limitations](configuration-testing-limitations-sources.md):
  technical state of the baseline.
