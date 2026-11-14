#!/usr/bin/env bash
# Writes sdv_media_rpi5 to a card in a card reader of this machine. It asks before it writes and
# uses sudo for the writes only.
#
#     tools/flash.sh card  /dev/sdX   the whole image of tools/mkimg.sh; userdata then grows to
#                                     the end of the card. Everything on the card is lost.
#     tools/flash.sh boot  /dev/sdX   p1 only (kernel, ramdisk, cmdline.txt, config.txt)
#     tools/flash.sh super /dev/sdX   p5 only (system, system_ext, product, vendor); data stays
#     tools/flash.sh wipe  /dev/sdX   empties metadata, misc and userdata: a first boot again
#
# boot, super and wipe expect a card written with "card" before. There is no fastboot on this
# board; the card goes back into the Raspberry Pi afterwards.
set -euo pipefail

mode="${1:-}"
dev="${2:-}"
case "$mode" in card|boot|super|wipe) ;; *) sed -n '2,13p' "$0"; exit 2 ;; esac

# a whole disk that is removable or on USB, with nothing mounted: never the host's own disks
[ -b "$dev" ] || { echo "$dev is not a block device"; exit 1; }
[ "$(lsblk -dno TYPE "$dev")" = disk ] || { echo "$dev is not a whole disk"; exit 1; }
if [ "$(lsblk -dno RM "$dev" | tr -d ' ')" != 1 ] && [ "$(lsblk -dno TRAN "$dev" | tr -d ' ')" != usb ]; then
  echo "$dev is neither removable nor on USB: not writing"; exit 1
fi
if lsblk -no MOUNTPOINTS "$dev" 2>/dev/null | grep -q . || lsblk -no MOUNTPOINT "$dev" | grep -q .; then
  echo "$dev has mounted partitions: unmount them first"; exit 1
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$HERE/env.sh" >/dev/null
: "${ANDROID_PRODUCT_OUT:?lunch did not set ANDROID_PRODUCT_OUT}"

# /dev/sdb -> /dev/sdb5, /dev/mmcblk0 -> /dev/mmcblk0p5
part() { case "$dev" in *[0-9]) echo "${dev}p$1" ;; *) echo "$dev$1" ;; esac; }

lsblk -o NAME,SIZE,TYPE,TRAN,RM,MODEL,LABEL "$dev"
read -r -p "write \"$mode\" to $dev? [y/N] " ans
[ "$ans" = y ] || { echo "aborted"; exit 1; }

case "$mode" in
  card)
    img="$ANDROID_PRODUCT_OUT/sdv_media_rpi5-sdcard.img"
    [ -s "$img" ] || { echo "missing $img: tools/mkimg.sh first"; exit 1; }
    # every byte: zeros in the image have to overwrite what the card had there
    sudo dd if="$img" of="$dev" bs=4M conv=fsync status=progress
    sudo parted -s "$dev" resizepart 3 100%
    ;;
  boot)
    vfat="$ANDROID_PRODUCT_OUT/rpiboot.vfat"
    [ -s "$vfat" ] || { echo "missing $vfat: tools/mkimg.sh first"; exit 1; }
    sudo dd if="$vfat" of="$(part 1)" bs=4M conv=fsync status=progress
    ;;
  super)
    super="$ANDROID_PRODUCT_OUT/super.img"
    if [ "$(od -An -tx4 -N4 "$super" | tr -d ' ')" = ed26ff3a ]; then
      sudo "$ANDROID_HOST_OUT/bin/simg2img" "$super" "$(part 5)"
    else
      sudo dd if="$super" of="$(part 5)" bs=4M conv=fsync status=progress
    fi
    ;;
  wipe)
    for p in 6 7 3; do
      sudo dd if=/dev/zero of="$(part $p)" bs=1M count=4 conv=fsync status=none
    done
    ;;
esac
sync
echo "done: $mode on $dev"
