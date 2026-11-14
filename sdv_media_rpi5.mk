# sdv_media_rpi5: SDV Media (SDV core, apps on harry, no Java framework) on the Raspberry Pi 5.
# The same product as device/rb3/sdv_media_db845c, on another board: SDV core base with its
# own root init (BoardConfig.mk), the house's bundles, the panel (its browser is experimental and off by default). The board
# layer is this folder; PLAN.md lists what comes from where.

$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)

# as sdv_core_arm64.mk; the core base errors without them
SDV_VM_LEVEL_PERMISSIONS_MODULE := com.oem.sdv.authz.allow_all.core
SDV_SOMEIP_BROKER_CONFIG := broker_config.json
PRODUCT_SYSTEM_PROPERTIES += ro.sdv.someip.broker_config=/system/etc/someip/broker_config.json
# keystore2 needs a KeyMint; no TEE in AOSP for this board, so SDV's nonsecure one
PRODUCT_PACKAGES += android.sdv.hardware.security.keymint-service.nonsecure
SDV_VEHICLE_POWER_STATE_MANAGER_MODULE := vepsm
SDV_DIAGNOSTICS_AGENT_MODULE := sdv_diagnostics_agent

include device/google/sdv/sdv_core_base/sdv_core_base.mk

# The screen link between the panel (vendor) and the dashboard bundle (product): VINTF checks a
# vendor HAL against a framework matrix, and its client lives on /product.
DEVICE_PRODUCT_COMPATIBILITY_MATRIX_FILE += device/rpi5/sdv_media_rpi5/vintf/product_compatibility_matrix.xml

# the core base sets ro.soc.* for a VM: the real chip instead, a property once only
PRODUCT_VENDOR_PROPERTIES := $(filter-out ro.soc.manufacturer=% ro.soc.model=%,$(PRODUCT_VENDOR_PROPERTIES))
PRODUCT_VENDOR_PROPERTIES += \
    ro.soc.manufacturer=Broadcom \
    ro.soc.model=BCM2712
# no system_dlkm partition on this board: the kernel has its drivers built in
PRODUCT_PACKAGES := $(filter-out system_dlkm-build.prop,$(PRODUCT_PACKAGES))

PRODUCT_COPY_FILES += \
    device/google/sdv/sdv_core_arm64/sdv_product_native_services_names:$(TARGET_COPY_OUT_PRODUCT)/etc/sdv_native_services_names

PRODUCT_NAME := sdv_media_rpi5
PRODUCT_DEVICE := sdv_media_rpi5
PRODUCT_BRAND := Android
PRODUCT_MODEL := SDV media on Raspberry Pi 5
PRODUCT_MANUFACTURER := Raspberry Pi

# The kernel runs with 16 KiB pages: every ELF aligned to 16 KiB, no PAGE_SIZE macro
PRODUCT_MAX_PAGE_SIZE_SUPPORTED := 16384
PRODUCT_NO_BIONIC_PAGE_SIZE_MACRO := true

# Partitions: dynamic partitions with Virtual A/B on slot _a, as on the RB3. The boot HAL keeps
# its slot state in the misc partition; update_verifier (SDV init) waits for it at every boot.
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota.mk)
PRODUCT_BUILD_SUPER_PARTITION := true
PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_USE_DYNAMIC_PARTITION_SIZE := true
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    product \
    system \
    system_ext \
    vendor
PRODUCT_PACKAGES += com.android.hardware.boot

# first stage init reads the fstab from the ramdisk, mount_all from /vendor
PRODUCT_COPY_FILES += \
    device/rpi5/sdv_media_rpi5/fstab.rpi5:$(TARGET_COPY_OUT_RAMDISK)/fstab.rpi5 \
    device/rpi5/sdv_media_rpi5/fstab.rpi5:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.rpi5

# the core base's ueventd.rc imports /vendor/etc/sdv_core_ueventd/: the board's device nodes go there
PRODUCT_COPY_FILES += \
    device/rpi5/sdv_media_rpi5/ueventd.rpi5.rc:$(TARGET_COPY_OUT_VENDOR)/etc/sdv_core_ueventd/ueventd.rpi5.rc

# The GPU: Mesa of the reference port (external/mesa3d-rpi): v3d renders, vc4 drives the
# display. Its own Soong namespace, so that no other product of the tree sees its modules.
# Installed in /vendor/lib64/egl as on the RB3; harry drives KMS itself (no drm_hwcomposer).
PRODUCT_SOONG_NAMESPACES += external/mesa3d-rpi
PRODUCT_PACKAGES += \
    libEGL_mesa \
    libGLESv1_CM_mesa \
    libGLESv2_mesa \
    libgallium_dri
PRODUCT_VENDOR_PROPERTIES += \
    ro.hardware.egl=mesa \
    ro.opengles.version=196609

# harry's renderer, for an app run from /data/local/tmp during development
PRODUCT_PACKAGES += libimpeller

# vendor scripts (net_bringup.sh, everyware-browser.sh) need a vendor shell and toybox
PRODUCT_PACKAGES += \
    sh_vendor \
    toybox_vendor \
    awk_vendor

# userdata is f2fs with metadata encryption, formatted by init on the first boot; the core
# base brings the ext4 tools only
PRODUCT_PACKAGES += \
    fsck.f2fs \
    make_f2fs \
    secdiscard

# audio: harry plays through tinyalsa (HDMI audio of vc4)
PRODUCT_PACKAGES += \
    libtinyalsav2 \
    tinyplay \
    tinycap \
    tinymix \
    tinypcminfo

# Bluetooth: the HAL only; the Android stack is Java
PRODUCT_PACKAGES += android.hardware.bluetooth-service.default

# Wi-Fi: wpa_supplicant only (wificond is framework), started by net/net_bringup.sh. The
# driver (brcmfmac) and its firmware are built into the kernel.
PRODUCT_PACKAGES += \
    wpa_supplicant \
    wpa_cli

# the board's init: cpusets, adb over USB-C, Wi-Fi and the clock
PRODUCT_COPY_FILES += \
    device/rpi5/sdv_media_rpi5/init.sdv_rpi5.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/init.sdv_rpi5.rc

# network without the framework: AOSP's dhcpclient (Trusty's, in a Soong namespace) and the script
PRODUCT_SOONG_NAMESPACES += device/generic/trusty
PRODUCT_PACKAGES += dhcpclient
PRODUCT_COPY_FILES += \
    device/rpi5/sdv_media_rpi5/net/net_bringup.sh:$(TARGET_COPY_OUT_VENDOR)/bin/net_bringup.sh

# the root init (androidboot.init_rc in BoardConfig.mk): init reads this file and its imports only
PRODUCT_COPY_FILES += \
    device/rpi5/sdv_media_rpi5/init.sdv_media.rc:$(TARGET_COPY_OUT_SYSTEM)/etc/init/hw/init.sdv_media.rc

# SDV on one device: the sample policies, the test identity, service discovery on loopback
include device/google/sdv/sdv_core_base/sepolicy/samples/device_sepolicy.mk

# identity: instance1 of Google's example mesh, DICE from a test file. Test secrets, development only
include device/google/sdv/sdv_base/init_open_dice/init_open_dice_from_file.mk
PRODUCT_PACKAGES += vvmconfig.example
# sdv_sd_agent panics without an ACL provider
$(call soong_config_set,sdv_authz,acl_provider_type,sdv_acl_provider)
# the trust store of instance1 from /product/etc: the board has no vvmtruststore partition
PRODUCT_PACKAGES += \
    vvmtruststore.preprovisioned.rc \
    vvmtruststore_instance1_etc_uds_certs \
    vvmtruststore_instance1_etc_uds_pubs

# the network namespaces the SDV agents enter, with loopback only: no mesh on one device
PRODUCT_COPY_FILES += \
    device/rpi5/sdv_media_rpi5/ethernet/ethernet_sd_mesh_local.sh:$(TARGET_COPY_OUT_PRODUCT)/bin/ethernet/ethernet_sd_mesh_local.sh

# the media profile; the app comes with its own APEX. Not the stock harry: its sample config
# names Cuttlefish's displays, and its safety monitor spins without it
PRODUCT_SYSTEM_PROPERTIES += ro.sdv.profile=media

PRODUCT_COPY_FILES += \
    device/rpi5/sdv_media_rpi5/init.sdv_media_rpi5.rc:$(TARGET_COPY_OUT_SYSTEM)/etc/init/init.sdv_media_rpi5.rc

include device/google/sdv/sdv_media_base/sdv_samples_media.mk

# name resolution without netd
$(call inherit-product, vendor/sdv-everyware/dnsproxyd/dnsproxyd.mk)

# the clock over NTP: the board boots in 1970 without an RTC battery, and TLS certificates are
# "not yet valid"
$(call inherit-product, vendor/sdv-everyware/third_party/chrony/chrony.mk)

# the service bundles of the house (weather, news, Wi-Fi, Matter, the dashboard bridge), one
# APEX each, and the contexts that put them into their SELinux domains
$(call inherit-product, vendor/sdv-everyware/everyware/product/everyware.mk)

# the domains of the two bundles that reach the network themselves (everyware/bundles/wifi and
# /matter): the Wi-Fi bundle talks to the supplicant's control socket, the Matter bundle has
# UDP and multicast; the supplicant's side of the socket is in sepolicy/vendor
SYSTEM_EXT_PUBLIC_SEPOLICY_DIRS += device/rpi5/sdv_media_rpi5/sepolicy/system_ext/public
SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += device/rpi5/sdv_media_rpi5/sepolicy/system_ext/private

# The device's settings: SDV's user_preferences keeps them and asks the service that owns one to
# apply it (the System bundle owns the time zone). Google ships the service only as a sample
# APEX; with it come three car samples (HVAC, seats, an HMI) that start only in a test group.
PRODUCT_PACKAGES += com.android.sdv.sample.user_preferences

# the panel: a vendor APEX with its harry app, started by its own init script (smarthome-app's
# apex/). The app keeps HAR's domain vendor_harplatform (BoardConfig.mk), and the bundles bind
# TCP sockets (the dashboard's gRPC): HAR's own policy, as harry_apex/product.mk wires it
PRODUCT_PACKAGES += com.everyware.smarthome
SYSTEM_EXT_PUBLIC_SEPOLICY_DIRS += packages/services/display_safety/service/product/har_sdv_service_bundle_apex/lifecycle/sepolicy/public
SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += packages/services/display_safety/service/product/har_sdv_service_bundle_apex/lifecycle/sepolicy

# adb remount on a userdebug build: the tools of the overlay on /data (android-17.0.0_r1's
# sdv_core_base does not ship them yet)
PRODUCT_PACKAGES_DEBUG += \
    remount \
    overlay_remounter \
    gsid
