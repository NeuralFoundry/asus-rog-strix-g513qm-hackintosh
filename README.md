# ASUS ROG Strix G15 G513QM (Ryzen 7 5800H + Vega 8)  macOS Sequoia 15.7.9 OpenCore EFI

OpenCore 1.0.7 EFI and the machine-specific findings needed to run macOS Sequoia 15.7.9 in dual boot
(Windows 11 + macOS) on the ASUS ROG Strix G513QM (2021). Most of it applies to the whole Cezanne family
of ASUS laptops (G513Q*, G713Q*, TUF FA506Q* with Ryzen 5800H/5900HX).

> Disclaimer: Apple's software license only permits macOS on Apple hardware. This repository is shared for
> technical documentation purposes; you are responsible for how you use it.

## Hardware

| Component | Model | Status |
|---|---|---|
| CPU | AMD Ryzen 7 5800H (8C/16T, Cezanne) | Working (AMD_Vanilla patches, all 16 threads) |
| iGPU | Radeon Vega 8 (0x1638) | NootedRed, Metal 3, 4 GB VRAM (UMA size set with Smokeless UMAF) |
| dGPU | NVIDIA RTX 3060 Mobile | Unsupported by macOS; disabled via SSDT |
| Panel | InnoLux N156HRA-EA1, 1080p 144 Hz | Needs a 60 Hz-preferred EDID injection |
| Wi-Fi / BT | Intel AX200 | itlwm + HeliPort / IntelBluetoothFirmware |
| Ethernet | Realtek RTL8168 | RealtekRTL8111 |
| Audio | Realtek ALC285 | AppleALC, `alcid=21` |
| NVMe 1 | SK Hynix BC711 (HFM001TD3JX013N, Windows drive) | **Kernel panics macOS; hidden from it** |
| NVMe 2 | Samsung 970 EVO 500 GB | macOS drive |
| BIOS | G513QM.331 | Secure Boot off, Fast Boot off |

## Four findings specific to this machine

The stock Dortania AMD guide and the ready-made EFIs for similar laptops do not boot here at all. In order:

1. **`Booter → Quirks → ProtectUefiServices = true` is mandatory.** The ASUS firmware overrides OpenCore's
   `ExitBootServices` / `GetMemoryMap` hooks. Without this quirk the kernel dies right after `EXITBS:START`
   without printing a single line, and no other Booter quirk (SetupVirtualMap, DevirtualiseMmio,
   EnableWriteUnprotector, …) has any effect because none of them ever runs.
2. **Hide the SK Hynix BC711 NVMe from macOS.** IONVMeFamily panics on this drive (NVMeFix does not help).
   `EFI/OC/ACPI/SSDT-NVMe-Off.aml` returns `_STA = 0` for `\_SB.PCI0.GPP6.NVME` under Darwin only, and a
   `DeviceProperties` entry on `PciRoot(0x0)/Pci(0x2,0x4)/Pci(0x0,0x0)` sets `class-code = FFFFFFFF` so the
   driver never matches. Windows is unaffected. If your drive sits in the other slot, take the PCI path from
   the OpenCore log (`OCB: Adding fs …`).
3. **Emulated NVRAM (OpenVariableRuntimeDxe).** If installation phase 1 hard-freezes at "About 12 minutes
   remaining", the installer is writing the boot volume to the firmware NVRAM and the ASUS firmware hangs on
   that runtime write. `OpenVariableRuntimeDxe.efi` (LoadEarly) + `OpenRuntime.efi` (LoadEarly) +
   `NVRAM → LegacyOverwrite / LegacySchema / WriteFlash`. OpenCore persists the emulated store itself in an
   `NVRAM/` folder on the EFI partition.
4. **The 144 Hz panel needs a 60 Hz-preferred EDID.** The panel's EDID lists 1080p@144 Hz first; with
   acceleration enabled NootedRed draws into the top-left ~80 % of the screen and Setup Assistant never shows
   up. `docs/edid-N156HRA-EA1-60hz-rgb.bin` (60 Hz DTD moved first, RGB only) is injected as
   `AAPL00,override-no-connect` on `PciRoot(0x0)/Pci(0x8,0x1)/Pci(0x0,0x0)`. Stopgap during installation:
   boot-arg `-NRedNoAccel` (framebuffer only).

Additional notes:

- Armoury Crate's "Eco" GPU mode does not power the dGPU off at firmware level (it still shows up on PCIe in
  macOS). `acpi-sources/SSDT-dGPU-Off.dsl` calls this DSDT's power resource, `\_SB.PCI0.GPP0.M237._OFF`.
  The `PEGP._OFF` method used by the G513IC EFI does not exist in this DSDT.
- The firmware enables Resizable BAR for the RTX 3060 (BAR1 = 8 GB). If you keep the dGPU on, set
  `ResizeAppleGpuBars = 0`.
- The installer's Wi-Fi menu cannot see itlwm. Either use Ethernet or store your SSID/password in itlwm with
  `tools/itlwm-wifi-config.py` so it auto-connects.
- If the recovery "Reinstall" download keeps failing, use a full installer USB. `tools/write-usb-raw-image.ps1`
  writes a raw installer image to a USB stick from Windows; `tools/edit-usb-efi.ps1` mounts the stick's EFI
  partition on Windows and runs an edit script against it.

## VRAM: raising the UMA frame buffer size (512 MB → 4 GB)

The ASUS BIOS hides the AMD CBS menu, so the iGPU only gets the default 512 MB carve-out. With
[Smokeless_UMAF](https://github.com/DavidS95/Smokeless_UMAF) (Universal AMD Form Browser) you can change it:

1. Format a spare USB stick as FAT32 and copy the contents of `UniversalAMDFormBrowser.zip` onto it
   (`EFI/Boot/Bootx64.efi` plus `DisplayEngine.efi`, `SetupBrowser.efi`, `UiApp.efi` in the root).
   `tools/write-umaf-usb.ps1` does this from Windows.
2. Boot the stick (Esc → UEFI: USB). Go to **Device Manager → AMD CBS → NBIO Common Options → GFX Configuration**.
3. Set **iGPU Configuration = UMA_SPECIFIED** and **UMA Frame buffer Size = 4G**. Change nothing else.
4. Leave with Esc, confirm saving, reboot. macOS then reports 4 GB VRAM.

Do not run UMAF as an OpenCore tool: with emulated NVRAM the setup variable might not reach the firmware.

## Not included (add these yourself)

- **NootedRed.kext** and **ForgedInvariant.kext** (ChefKiss). They are intentionally not redistributed here;
  download them from ChefKiss and drop them into `EFI/OC/Kexts/`. The config.plist entries are already present.
- **SMBIOS**: the `PlatformInfo → Generic` fields are blank. Generate serial, MLB and UUID with
  `macserial -m MacBookPro16,2 -g` and put your Ethernet MAC into `ROM`.
- **macOS installer**: from Apple (`softwareupdate --fetch-full-installer`) or an ISO built on a GitHub Actions
  macOS runner.

## Installation outline

1. BIOS: Secure Boot **Disabled**, Fast Boot **Disabled**; turn BitLocker off in Windows.
2. USB: GPT; this `EFI/` folder (+ ChefKiss kexts + your SMBIOS) on the EFI partition, the macOS installer
   (`createinstallmedia`) or `com.apple.recovery.boot` on the second partition.
3. Disk Utility: erase the Samsung as APFS/GUID. The SK Hynix does not appear (hidden; Windows is safe).
4. Install; on every reboot pick "macOS Installer" in the OpenCore picker, later "macOS".
5. First boot with `-NRedNoAccel`; once on the desktop, enable acceleration with the EDID injection.
6. `tools/copy-efi-to-esp.sh` copies the EFI to the internal drive's EFI partition. Put the
   "UEFI OS (Samsung …)" entry first in the BIOS boot menu (with emulated NVRAM OpenCore no longer edits the
   firmware boot order).
7. Booting Windows from the OpenCore picker keeps the real ASUS SMBIOS (`UpdateSMBIOSMode = Custom` +
   `CustomSMBIOSGuid`). Keep BitLocker off.

## Status (2026-09-06, first day after installation; will be updated)

| Component | Status |
|---|---|
| CPU boost, 16 threads | Working |
| iGPU (NootedRed) | Working with acceleration (Metal 3); 4 GB VRAM after raising the UMA size in the hidden BIOS menu |
| Audio (speakers, microphone) | Working |
| Keyboard (PS/2), trackpad (I2C) | Working |
| Ethernet | Working |
| Wi-Fi (itlwm + HeliPort) | Working |
| Bluetooth | Kexts load (IntelBluetoothFirmware, IntelBTPatcher, BlueToolFixup); pairing test pending |
| Battery status | Working |
| USB map (UTBMap, identical to the G513IC map) | Working |
| Sleep | Untested, not expected to work |
| dGPU | SSDT ready, test pending (Eco mode does not disable it in firmware) |

## Tools

| File | Purpose |
|---|---|
| `tools/write-usb-raw-image.ps1` | Write a raw disk image to a USB stick from Windows (run as administrator) |
| `tools/edit-usb-efi.ps1` | Temporarily assign a drive letter to the stick's EFI partition and run an edit script |
| `tools/itlwm-wifi-config.py` | Store SSID/password in itlwm's Info.plist for auto-connect in the installer |
| `tools/edid-tool.py` | Parse an EDID and produce the 60 Hz-preferred, RGB-only variant |
| `tools/copy-efi-to-esp.sh` | On the Mac: copy the EFI folder to the internal drive's EFI partition |
| `tools/write-umaf-usb.ps1` | Prepare a Smokeless UMAF boot stick from Windows (run as administrator) |
| `acpi-sources/*.dsl` | Sources of the two machine-specific SSDTs |
| `docs/edid-*.bin` | Original and patched panel EDID |

## Credits and references

- [andgarriv/EFI_ROG_STRIX_G15_G513](https://github.com/andgarriv/EFI_ROG_STRIX_G15_G513) (G513IC, MIT): base EFI layout, SSDTs, USB map
- [Kingtous/thinkbook14p-Gen2-ACH-hackintosh](https://github.com/Kingtous/thinkbook14p-Gen2-ACH-hackintosh): same-silicon (5800H) reference
- [ryanamay/asus-tuf-a-series](https://github.com/ryanamay/asus-tuf-a-series): the "OEM SSD kernel panic" hint
- InsanelyMac G513QM thread (5900HX, Ventura), the Dortania OpenCore guide, AMD-OSX AMD_Vanilla patches,
  Acidanthera (OpenCore, Lilu, VirtualSMC, AppleALC, WhateverGreen, RestrictEvents, NVMeFix, VoodooPS2),
  OpenIntelWireless (itlwm, HeliPort, IntelBluetoothFirmware), VoodooI2C, ChefKiss (NootedRed, ForgedInvariant).
