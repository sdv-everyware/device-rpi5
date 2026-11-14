# The files of the card's FAT partition, in $(PRODUCT_OUT)/rpiboot: the board's firmware loads
# them (boot/config.txt). The kernel, its device trees and overlays are the reference port's
# prebuilt (device/brcm/rpi5-kernel); the ramdisk and the kernel's arguments come from this
# build. tools/mkimg.sh makes the FAT partition and the card image from this folder; the
# build itself cannot run mkfs.vfat.
ifeq ($(TARGET_DEVICE),sdv_media_rpi5)

RPI5_KERNEL_DIR := device/brcm/rpi5-kernel
RPI5_BOOT_OUT := $(PRODUCT_OUT)/rpiboot
RPI5_BOOT_INPUTS := \
    device/rpi5/sdv_media_rpi5/boot/config.txt \
    $(RPI5_KERNEL_DIR)/Image \
    $(wildcard $(RPI5_KERNEL_DIR)/bcm2712*.dtb) \
    $(wildcard $(RPI5_KERNEL_DIR)/overlays/*)

$(RPI5_BOOT_OUT)/cmdline.txt: PRIVATE_CMDLINE := $(strip $(BOARD_KERNEL_CMDLINE))
$(RPI5_BOOT_OUT)/cmdline.txt: $(INSTALLED_RAMDISK_TARGET) $(RPI5_BOOT_INPUTS)
	rm -rf $(RPI5_BOOT_OUT)
	mkdir -p $(RPI5_BOOT_OUT)/overlays
	cp device/rpi5/sdv_media_rpi5/boot/config.txt $(RPI5_BOOT_OUT)/
	cp $(RPI5_KERNEL_DIR)/Image $(RPI5_KERNEL_DIR)/bcm2712*.dtb $(RPI5_BOOT_OUT)/
	cp $(RPI5_KERNEL_DIR)/overlays/* $(RPI5_BOOT_OUT)/overlays/
	cp $(INSTALLED_RAMDISK_TARGET) $(RPI5_BOOT_OUT)/ramdisk.img
	echo '$(PRIVATE_CMDLINE)' > $@

droidcore: $(RPI5_BOOT_OUT)/cmdline.txt

endif
