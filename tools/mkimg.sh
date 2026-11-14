#!/usr/bin/env bash
# Makes the card image of sdv_media_rpi5 from the build's output, as an ordinary user (no root,
# no loop device):
#
#     tools/mkimg.sh [image]       default: $ANDROID_PRODUCT_OUT/sdv_media_rpi5-sdcard.img
#
# MBR, as the reference port and the board's firmware use it:
#     p1  boot      FAT32, 256 MiB: config.txt, cmdline.txt, kernel, device trees, overlays,
#                   ramdisk ($ANDROID_PRODUCT_OUT/rpiboot, build/tasks/rpiboot.mk); also kept
#                   as $ANDROID_PRODUCT_OUT/rpiboot.vfat
#     p2  extended
#     p5  super     the build's super.img (system, system_ext, product, vendor)
#     p6  metadata  empty: init formats it on the first boot
#     p7  misc      empty: the boot HAL writes its slot state there
#     p3  userdata  empty, DATA_MB (default 3072) MiB: init formats it on the first boot;
#                   tools/flash.sh card grows it to the end of the card
# The kernel command line names these partitions (androidboot.partition_map, BoardConfig.mk).
#
# Needs on the host: parted, mkfs.vfat (dosfstools), mcopy (mtools).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "$HERE/env.sh" >/dev/null
: "${ANDROID_PRODUCT_OUT:?lunch did not set ANDROID_PRODUCT_OUT}"
: "${ANDROID_HOST_OUT:?lunch did not set ANDROID_HOST_OUT}"

IMG="${1:-$ANDROID_PRODUCT_OUT/sdv_media_rpi5-sdcard.img}"
BOOT_MB=256
SUPER_MB=$(( $(get_build_var BOARD_SUPER_PARTITION_SIZE) / 1048576 ))
META_MB=64
MISC_MB=4
DATA_MB="${DATA_MB:-3072}"

for t in parted mkfs.vfat mcopy; do
  command -v "$t" >/dev/null || { echo "$t is missing on the host (parted, dosfstools, mtools)"; exit 1; }
done
BOOT_DIR="$ANDROID_PRODUCT_OUT/rpiboot"
SUPER="$ANDROID_PRODUCT_OUT/super.img"
[ -s "$BOOT_DIR/cmdline.txt" ] || { echo "missing $BOOT_DIR: build first (m)"; exit 1; }
[ -s "$SUPER" ] || { echo "missing $SUPER: build first (m)"; exit 1; }
[ -e "$IMG" ] && { echo "$IMG exists; remove it first"; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/sdv_media_rpi5.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# super.img may be sparse (Android's format): the card needs the raw bytes
if [ "$(od -An -tx4 -N4 "$SUPER" | tr -d ' ')" = ed26ff3a ]; then
  SIMG2IMG="$ANDROID_HOST_OUT/bin/simg2img"
  [ -x "$SIMG2IMG" ] || { echo "super.img is sparse and $SIMG2IMG is missing: m simg2img"; exit 1; }
  "$SIMG2IMG" "$SUPER" "$WORK/super.raw"
  SUPER="$WORK/super.raw"
fi
super_bytes=$(stat -c %s "$SUPER")
[ "$super_bytes" -le $(( SUPER_MB * 1048576 )) ] || { echo "super.img is larger than ${SUPER_MB} MiB"; exit 1; }

# the FAT partition: the firmware reads config.txt and loads what it names. Kept beside the
# image for tools/flash.sh boot.
BOOT_VFAT="$ANDROID_PRODUCT_OUT/rpiboot.vfat"
rm -f "$BOOT_VFAT"
mkfs.vfat -C -F 32 -n BOOT "$BOOT_VFAT" $(( BOOT_MB * 1024 )) >/dev/null
mcopy -s -i "$BOOT_VFAT" "$BOOT_DIR"/* ::/

# the layout in MiB; every logical partition has 1 MiB in front of it for its EBR
p1_start=1;                       p1_end=$(( p1_start + BOOT_MB ))
ext_start=$p1_end
p5_start=$(( ext_start + 1 ));    p5_end=$(( p5_start + SUPER_MB ))
p6_start=$(( p5_end + 1 ));       p6_end=$(( p6_start + META_MB ))
p7_start=$(( p6_end + 1 ));       p7_end=$(( p7_start + MISC_MB ))
ext_end=$p7_end
p3_start=$ext_end;                p3_end=$(( p3_start + DATA_MB ))

truncate -s "${p3_end}M" "$IMG"
parted -s "$IMG" -- \
  mklabel msdos \
  mkpart primary fat32 ${p1_start}MiB ${p1_end}MiB \
  set 1 boot on \
  set 1 lba on \
  mkpart extended ${ext_start}MiB ${ext_end}MiB \
  mkpart logical ${p5_start}MiB ${p5_end}MiB \
  mkpart logical ${p6_start}MiB ${p6_end}MiB \
  mkpart logical ${p7_start}MiB ${p7_end}MiB \
  mkpart primary ${p3_start}MiB 100%

dd if="$BOOT_VFAT" of="$IMG" bs=1M seek=$p1_start conv=notrunc status=none
dd if="$SUPER" of="$IMG" bs=1M seek=$p5_start conv=notrunc,sparse status=none

echo "made $IMG"
parted -s "$IMG" unit MiB print
