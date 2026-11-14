# sdv_media_rpi5: plan and decisions

Goal: on a Raspberry Pi 5 the same system as on the RB3 (`device/rb3/sdv_media_db845c`): SDV
core without the Java framework, the house's service bundles (weather, news, Wi-Fi, Matter,
system, dashboard), the panel from its vendor APEX (`com.everyware.smarthome`) with Wayland
zones, the browser (Cog, experimental, off by default) in a Debian root, Wi-Fi with DHCP, settings in `user_preferences`.

"The latest version" is taken as the Raspberry Pi 5 (BCM2712). The same image boots a Pi 500
and a CM5 (their device trees are on the boot partition); see "Other boards".

## The reference: how others run Android on a Pi 5

I followed raspberry-vanilla (KonstaT), the AOSP port for the Pi 4 and Pi 5. Its newest branch
is `android-17.0` (android-17.0.0_r1, the tag of this tree).

| What | Reference | Where |
|---|---|---|
| Manifest | AOSP + 23 projects, replaces `build/make`, `build/soong`, `external/minigbm`, `external/drm_hwcomposer` and others | github.com/raspberry-vanilla/android_local_manifest, `manifest_brcm_rpi.xml` |
| Device | `device/brcm/rpi5`: full Android (tablet, TV, car), HALs as vendor APEXes | github.com/raspberry-vanilla/android_device_brcm_rpi5 |
| Kernel | prebuilt `Image` (6.18.38, 16 KiB pages, drivers built in, Wi-Fi/BT firmware built in), device trees, overlays | github.com/raspberry-vanilla/android_device_brcm_rpi5-kernel |
| Boot | the board's firmware loads `Image` and `ramdisk.img` from a FAT `boot.img` (`mkbootimg.mk`, needs their `BOARD_CUSTOM_BOOTIMG_MK` patch in build/make and a tool list patch in build/soong) | `device/brcm/rpi5/mkbootimg.mk`, `boot/config.txt` |
| Card | MBR: p1 boot (FAT), p2 extended (p5 system, p6 vendor, p7 metadata), p3 userdata; ext4, no super, no encryption | `mkimg.sh`, `wrimg.sh`, `ramdisk/fstab.rpi5` |
| GPU | Mesa 26.3 (v3d, vc4, kmsro) with an Android.bp made by ninja-to-soong, EGL and Vulkan as vendor APEXes | github.com/raspberry-vanilla/android_external_mesa3d-rpi |
| Buffers, display | minigbm fork with a `gbm_mesa` backend (gralloc), drm_hwcomposer fork | android_external_minigbm, android_external_drm_hwcomposer |
| SELinux | permissive | `BoardConfig.mk` |

What changes for this tree and its SDV core: SDV needs dynamic partitions
(`sdv_core_base.mk`: `PRODUCT_USE_DYNAMIC_PARTITIONS`), runs `update_verifier` at every boot
(`init.sdv_core_base.rc:413`, it reboots when there is no boot HAL), has no SurfaceFlinger and no
gralloc user, and the panel drives KMS itself through minigbm's `libgbm`.

## Decisions

| # | Decision | Chosen | Alternatives | Why |
|---|---|---|---|---|
| D1 | Board | Raspberry Pi 5 | Pi 4 (the reference supports it too) | "latest version"; 16 KiB-page kernel and the same chip as Pi 500 and CM5 |
| D2 | Folder and name | `device/rpi5/sdv_media_rpi5`, product `sdv_media_rpi5` | `device/brcm/sdv_media_rpi5` | like `device/rb3/sdv_media_db845c`; `device/brcm` stays the reference's folder (its kernel lives there at the reference's path) |
| D3 | Board layer | own files here, values taken from the reference | inherit `device/brcm/rpi5/device.mk`, as the RB3 inherits Linaro's | the reference's device.mk is a full Android (framework, overlays, camera, codecs) and needs its forks of build/make, build/soong, minigbm and drm_hwcomposer |
| D4 | Kernel | the reference's prebuilt, as it is | build android_kernel_brcm_rpi (a 4 GB repository) | everything the product needs is built in (below); no module partitions |
| D5 | Boot | firmware loads `Image` + `ramdisk.img`; the `androidboot.*` keys of the RB3's bootconfig go to `cmdline.txt` | U-Boot or EFI with boot.img and vendor_boot | the reference's way; the kernel has no bootconfig (`CONFIG_BOOT_CONFIG` off); init reads the keys from the command line the same way |
| D6 | Making the FAT partition | the build puts the files into `$OUT/rpiboot` (`build/tasks/rpiboot.mk`), `tools/mkimg.sh` makes the FAT and the card image | the reference's `BOARD_CUSTOM_BOOTIMG_MK` | no change in build/make or build/soong, which other products of the tree use |
| D7 | Card layout | MBR as the reference: p1 boot, p5 super, p6 metadata, p7 misc, p3 userdata; named by `androidboot.partition_map` with `androidboot.boot_devices=soc@107c000000/1000fff000.mmc` | GPT with partition names; the reference's plain system/vendor partitions | super is what the SDV core and the RB3 use; the firmware boots MBR for sure; Android 17's init names MBR partitions with `partition_map` (`system/core/init/devices.cpp`) |
| D8 | Slots | Virtual A/B, slot `_a` always, AOSP boot HAL (`com.android.hardware.boot`) on misc | no A/B | as the RB3; `update_verifier` waits for the boot HAL, and the boot HAL needs `ro.boot.slot_suffix` and misc |
| D9 | File systems | erofs (16 KiB blocks) in super; userdata f2fs with file and metadata encryption, formatted by init on the first boot | the reference's ext4 without encryption | as the RB3; the kernel has dm-default-key and the inline crypto fallback |
| D10 | GPU | the reference's Mesa, built from source in its own Soong namespace, installed in `/vendor/lib64/egl` with `ro.hardware.egl=mesa` | the reference's EGL APEX; AOSP's `external/mesa3d` (gfxstream only) | as the RB3 (plain vendor libraries); the namespace keeps its module names away from the other products of the tree |
| D11 | Display path | no gralloc HAL, no drm_hwcomposer, no Vulkan | the reference's minigbm `gbm_mesa` gralloc and drm_hwcomposer | no SurfaceFlinger here; the panel allocates through `libgbm` and drives KMS; Mesa's fallback gralloc is enough for EGL |
| D12 | Wi-Fi | brcmfmac (built in, firmware in the kernel image), `wpa_supplicant` + `net/net_bringup.sh` + `dhcpclient` as on the RB3; `BOARD_WLAN_DEVICE` unset | the reference's supplicant APEX and wificond; `BOARD_WLAN_DEVICE := bcmdhd` | wificond is framework; the mainline driver needs no vendor driver library |
| D13 | adb and console | adb over the USB-C port (dwc2 device mode); root console on the debug UART (`ttyAMA10`) | adb over Ethernet (TCP) | as the reference; TCP adb on a userdebug image is open to the network |
| D14 | SELinux | permissive | enforcing | as the RB3 and the reference while the board's denials are collected |
| D15 | Out directory | `raspberry_out`, a symlink to the second disk (`RPI5_OUT_DISK`) | in the tree on the 4 TB disk | a full out directory is about 55 GB (`out_rb3` 54 GB); the 4 TB disk had 46 GB free and keeps 25 GB |
| D16 | Copies from the RB3 | copied, self-contained (sepolicy, net and ethernet scripts, root init, VINTF matrix) | point at `device/rb3/...` | asked for a self-contained product; the copies are listed below, so a shared layer later is mechanical |

What I left out of the RB3's list, and why: the Qualcomm parts (rmtfs, qrtr, pd-mapper,
tqftpserv, dlkm_loader, bdaddr and ethaddr scripts), Linaro's debugfs and world-writable
`sw_sync` block (nothing here uses it), the example power and thermal HALs, the AIDL audio HAL
and the gralloc allocator (no client without the framework; harry plays through tinyalsa).

The kernel's options I checked (`IKCONFIG` of the image): 16 KiB pages, binder, erofs, f2fs
with compression, fscrypt with the inline crypto fallback, dm-default-key, dm-verity, dm-user,
loop, overlayfs, network namespaces, IPv6, vc4 and v3d, brcmfmac and its firmware
(`CONFIG_EXTRA_FIRMWARE`), the Bluetooth UART, rpi-rtc, dwc2, HID multitouch, KVM. Off: user
namespaces, bootconfig, `MODULE_SIG_FORCE`.

## What comes from where

| Part | From |
|---|---|
| SDV core, identity, service discovery on one device | `device/google/sdv`, as in `sdv_media_db845c.mk` |
| House's bundles, browser service (experimental, with the flag), dnsproxyd, chrony | `vendor/sdv-everyware`, inherited as on the RB3 |
| The panel | `com.everyware.smarthome` from `packages/services/display_safety/utils/smarthome-app` |
| Copied from `device/rb3/sdv_media_db845c` | `sepolicy/system_ext/*` (same), `sepolicy/vendor/*.te` and `property_contexts` (same), `vintf/`, `ethernet/`, `net/net_bringup.sh` (without the modem start), `init.sdv_media.rc` (board imports changed), `init.sdv_media_rpi5.rc`, the cmdline keys |
| From the reference | kernel, device trees, overlays (`device/brcm/rpi5-kernel`), Mesa (`external/mesa3d-rpi`), `boot/config.txt`, the USB gadget and device node rules, the MBR layout |
| New | `BoardConfig.mk`, `fstab.rpi5`, `init.sdv_rpi5.rc`, `build/tasks/rpiboot.mk`, `tools/` |

## Downloads

All shallow (`--depth 1`), branch `android-17.0`, into new folders; nothing existing was
overwritten. Measured on 2026-11-14.

| Path in the tree | Source | Revision | Size on disk |
|---|---|---|---|
| `device/brcm/rpi5-kernel` | github.com/raspberry-vanilla/android_device_brcm_rpi5-kernel | d085cd393c45f3fc1493a42ec7673fe61f9ed62b (2026-10-30) | 94 MB (28 MB .git) |
| `external/mesa3d-rpi` | github.com/raspberry-vanilla/android_external_mesa3d-rpi | b3a45716baeee3237350d9209a00717cd10a4d6c (2026-11-10, Mesa 26.3.0) | 629 MB (135 MB .git) |
| (removed) `vendor/brcm` | github.com/raspberry-vanilla/proprietary_vendor_brcm | d233de997b7115a42a164f5a59fc3c3ebf3f9bf4 | 11 MB; the kernel image holds the same files byte for byte, so not needed |

Changes on top of the downloads: `external/mesa3d-rpi`, branch `feature/rpi5`, two commits:
a `soong_namespace`, `soc_specific: true` and the Android header libraries (liblog, cutils,
hardware, system, nativebase, drm) in the defaults of `Android.bp`; the two APEX folders'
`Android.bp` renamed to `Android.bp.disabled`. Without the namespace every other product of
the tree failed in Soong (the static libraries had no vendor variant); without the header
libraries the vendor variant did not compile (`android/log.h` not found).

Read only, outside the tree: the reference's device repository and minigbm fork, its manifests.

## Not working yet (needs a change outside this folder)

1. The panel opens `/dev/dri/card0`: the default of harry's Android platform
   (`reference/platforms/har-platform-android/src/looper/android.rs:525`) when the app passes no
   `path`. On the Pi 5, card0 is v3d (render only) and the display is vc4 on card1. The app
   (`utils/smarthome-app/src/config.rs`) has to pass the card.
2. `libgbm` of `external/minigbm` (the panel's allocator) has no backend for the driver name
   `vc4` unless `DRV_VC4` is set, and that backend uses VC4 ioctls the BCM2712 does not have.
   The fix is minigbm's own pattern for rockchip and mediatek: the dumb backend for `vc4` when
   `DRV_VC4` is not set (`dumb_driver.c`, `drv.c`).

Until both are in, the image boots to the SDV core, the bundles and Wi-Fi, and the panel
restarts in a loop without a picture.

## Other boards

| Board | What changes |
|---|---|
| Pi 500 | nothing in the image (`bcm2712-rpi-500.dtb` is on the card); its USB-C port is power only, so adb only over the network or not at all |
| CM5 with eMMC | the eMMC sits on the same controller as the SD card (mmcblk0); the image is written with `rpiboot` (usbboot) instead of a card reader; `config.txt` already switches dwc2 to OTG |
| CM5 Lite, or a Pi 5 booting from USB or NVMe | `androidboot.boot_devices` and `partition_map` name another device; a second `BOARD_KERNEL_CMDLINE` for it |

## State

2026-11-14: built (`m`, `raspberry_out`: 46 GB), card image made with `tools/mkimg.sh`
(6.4 GB, 0.65 GB on disk), checked offline (FAT files and overlays, super metadata with the
`_a` partitions, empty metadata, misc and userdata). Not booted on a board yet.

## Next steps

1. Build (`m`), make the card (`tools/mkimg.sh`), first boot on the UART console.
2. The two changes above, then the panel and the browser on the board.
3. A shared layer for what the RB3 and the Pi have in common.
