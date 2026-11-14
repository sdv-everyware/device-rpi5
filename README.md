# sdv_media_rpi5

SDV media on the Raspberry Pi 5: SDV core, the house's service bundles, the smart home panel
on harry and its browser, and no Java framework. The same product as
`device/rb3/sdv_media_db845c` on another board. Choices and sources: [PLAN.md](PLAN.md).

## Build

Needs two projects of the reference port in the tree: `device/brcm/rpi5-kernel` and
`external/mesa3d-rpi` (PLAN.md, "Downloads").

```
RPI5_OUT_DISK=<mount point of a disk with 60 GB free>   # optional
source device/rpi5/sdv_media_rpi5/tools/env.sh
m
device/rpi5/sdv_media_rpi5/tools/mkimg.sh
```

`tools/env.sh` sets `OUT_DIR=raspberry_out` and runs lunch. `tools/mkimg.sh` makes
`$ANDROID_PRODUCT_OUT/sdv_media_rpi5-sdcard.img` (about 6.4 GB, mostly empty) without root.

## Card

A card of 8 GB or more. Either write the image with Raspberry Pi Imager ("Use custom"), or with
the script, which also grows userdata to the end of the card:

```
device/rpi5/sdv_media_rpi5/tools/flash.sh card /dev/sdX    # everything on the card is lost
device/rpi5/sdv_media_rpi5/tools/flash.sh boot /dev/sdX    # later: kernel, ramdisk, cmdline only
device/rpi5/sdv_media_rpi5/tools/flash.sh super /dev/sdX   # later: system, vendor, product; data stays
device/rpi5/sdv_media_rpi5/tools/flash.sh wipe /dev/sdX    # later: a first boot again
```

The board's EEPROM bootloader should be recent (Raspberry Pi Imager, "Misc utility images",
"Bootloader", "SD card boot"; or `rpi-eeprom-update` on Raspberry Pi OS).

## First boot

- Power: the official 27 W USB-C supply.
- Display: an HDMI monitor of 1920x1080 on HDMI0 (the micro HDMI port next to the USB-C port);
  a USB touch screen on a USB port.
- Console: the debug UART (3-pin connector between the HDMI ports, 115200 8N1), for example
  with the Raspberry Pi Debug Probe. It gives a root shell.
- adb: over the USB-C port when the host's port powers the board; otherwise the console.

The first boot formats metadata and userdata. Wi-Fi stays off until its configuration exists
on the device, as on the RB3:

```
adb shell 'cat > /data/vendor/wifi/wpa_supplicant.conf' <<'CONF'
ctrl_interface=/data/vendor/wifi/wpa/sockets
network={
    ssid="<name>"
    psk="<passphrase>"
}
CONF
adb reboot
```

Check: `adb shell getprop ro.sdv.profile` (media), `adb shell ls -l /dev/dri` (card0 v3d,
card1 vc4, renderD128), `adb logcat -s net_bringup dhcpclient`. The browser's Debian root is
set up once per board as on the RB3 (`vendor/sdv-everyware/everyware/docs/project/browser.md`).

SELinux is permissive and the device identity uses Google's public test secrets: development
only.
