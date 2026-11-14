# The board: Raspberry Pi 5 (BCM2712, four Cortex-A76, VideoCore VII). The board's EEPROM
# bootloader reads the first FAT partition of the card and loads what config.txt names: the
# kernel, the device tree with its overlays and the ramdisk; the kernel's arguments come from
# cmdline.txt. There is no Android bootloader on this board: no boot.img, no vendor_boot, no
# bootconfig, no fastboot. build/tasks/rpiboot.mk puts the FAT partition's files together and
# tools/mkimg.sh writes the card. The board settings follow the reference port for this board
# (raspberry-vanilla, device/brcm/rpi5); the SDV settings follow device/rb3/sdv_media_db845c.
# PLAN.md has the choices.

TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := cortex-a76

TARGET_BOARD_PLATFORM := bcm2712
TARGET_BOOTLOADER_BOARD_NAME := bcm2712
TARGET_NO_BOOTLOADER := true
# the kernel is the reference port's prebuilt (device/brcm/rpi5-kernel); it goes to the FAT
# partition as it is, so the build makes no boot.img
TARGET_NO_KERNEL := true
TARGET_NO_RECOVERY := true
# the kernel runs with 16 KiB pages (CONFIG_ARM64_16K_PAGES)
TARGET_BOOTS_16K := true

# system, system_ext, product and vendor in super, erofs, as on the RB3
BOARD_FLASH_BLOCK_SIZE := 4096
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := erofs
TARGET_COPY_OUT_VENDOR := vendor
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs
TARGET_COPY_OUT_SYSTEM_EXT := system_ext
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := erofs
TARGET_COPY_OUT_PRODUCT := product
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := erofs
# block size = page size, as Linaro's boards do for 16 KiB kernels
BOARD_EROFS_BLOCKSIZE := 16384

BOARD_SUPER_PARTITION_SIZE := 3221225472
BOARD_SUPER_PARTITION_METADATA_DEVICE := super
BOARD_SUPER_PARTITION_GROUPS := rpi5_dynamic_partitions
# the group: super less 4 MiB for the metadata
BOARD_RPI5_DYNAMIC_PARTITIONS_SIZE := 3217031168
BOARD_RPI5_DYNAMIC_PARTITIONS_PARTITION_LIST := system vendor system_ext product
BOARD_BUILD_SUPER_IMAGE_BY_DEFAULT := true

# userdata is f2fs with file encryption and metadata encryption, as on the RB3; the card's
# partition is empty and init formats it on the first boot (f2fs block size = page size)
TARGET_USERIMAGES_USE_F2FS := true
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
BOARD_F2FS_BLOCKSIZE := 16384
BOARD_USERDATAIMAGE_PARTITION_SIZE := 1073741824
BOARD_USES_METADATA_PARTITION := true

# Wi-Fi: the mainline brcmfmac driver; wpa_supplicant needs no vendor driver library
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_HAVE_BLUETOOTH := true

BOARD_SEPOLICY_DIRS += device/google/sdv/sdv_core_base/sepolicy/vendor/

include device/google/sdv/sdv_core_base/sepolicy/samples/board_sepolicy.mk

# HAR's domain vendor_harplatform for the panel's UI process (vendor file types: the vendor
# policy, as device/google/sdv_display_safety/sdv_harry_common.mk wires it). Before the
# product's own folder: that one adds to vendor_harplatform (vendor_harplatform.te).
BOARD_VENDOR_SEPOLICY_DIRS += packages/services/display_safety/service/product/sepolicy

BOARD_VENDOR_SEPOLICY_DIRS += device/rpi5/sdv_media_rpi5/sepolicy/vendor

# The kernel's arguments: build/tasks/rpiboot.mk writes them to cmdline.txt. There is no
# bootconfig on this board, so the androidboot.* keys of the RB3's bootconfig go here; init
# reads them from the kernel command line the same way.
# The Wi-Fi and Bluetooth firmware is built into the kernel (CONFIG_EXTRA_FIRMWARE), so no
# firmware_class.path. The line is about 1 KB; the firmware adds its own arguments, the arm64
# kernel takes 2048 bytes.
BOARD_KERNEL_CMDLINE := console=ttyAMA10,115200 loglevel=4 printk.devkmsg=on
BOARD_KERNEL_CMDLINE += androidboot.hardware=rpi5

# The card (tools/mkimg.sh): MBR, as the reference port and the board's firmware use it. MBR
# partitions have no names: boot_devices is the SD card's controller (soc@107c000000/mmc@fff000
# in bcm2712-rpi-5-b.dtb) and partition_map names the partitions on it.
BOARD_KERNEL_CMDLINE += androidboot.boot_devices=soc@107c000000/1000fff000.mmc
BOARD_KERNEL_CMDLINE += androidboot.partition_map=mmcblk0p1,boot;mmcblk0p5,super;mmcblk0p6,metadata;mmcblk0p7,misc;mmcblk0p3,userdata

# Slot _a always: SDV init runs update_verifier, which waits for the boot HAL, and the boot
# HAL needs a slot. No bootloader here switches slots. Orange: unlocked, adb remount works.
BOARD_KERNEL_CMDLINE += androidboot.slot_suffix=_a
BOARD_KERNEL_CMDLINE += androidboot.verifiedbootstate=orange

# the media profile: telemetry off
BOARD_KERNEL_CMDLINE += androidboot.sdv.telemetry.enabled=0

# the root init: init reads this file and its imports only. Permissive while the denials of
# the board are collected, as on the RB3.
BOARD_KERNEL_CMDLINE += \
    androidboot.init_rc=/system/etc/init/hw/init.sdv_media.rc \
    androidboot.adb.enabled=1 \
    androidboot.selinux=permissive

# identity: instance1 of Google's example mesh (sdv_core_cf/config/config_sdv_dev_mesh_instance1.json)
BOARD_KERNEL_CMDLINE += \
    androidboot.sdv.instance_name=instance1 \
    androidboot.sdv.init_open_dice.sample_file=dice_handover_instance1 \
    androidboot.sdv.boot_mode=locked \
    androidboot.sdv.ignore_avb_state=true \
    androidboot.sdv.preprovisioned_vvmtruststore=etc \
    androidboot.sdv.vvmfactorytrust=c779a73d0595a6814ba0414a419e99ad4026ad0feb603f2ad80ee6a9e4d1adb7 \
    androidboot.sdv.keymint.rpc.hbk=799da7577efd41d5b27810c5952fcec0291cbcfd687e77ac9a6cec8370651b1d \
    androidboot.vbmeta.digest=a0c829a2b0bc8be1114201dcbea3e435edddd9cc50cb65d2cb9aae92e2406f05 \
    androidboot.sdv.rpc.interface=lo

# vbmeta.digest is a placeholder: there is no AVB and the firmware passes none, and
# sdv_sd_agent rejects all zeros. Development only. sdv.rpc.interface: the SDV RPC servers
# bind to this interface's address; loopback keeps them on the device.
