#!/usr/bin/env bash
# Build environment for sdv_media_rpi5. Source it, do not execute it: lunch and OUT_DIR have to
# land in the calling shell.
#
#     source device/rpi5/sdv_media_rpi5/tools/env.sh
#     m
#
# OUT_DIR is raspberry_out, one out directory for this product: a product switch inside a
# shared out directory rebuilds thousands of steps. Set RPI5_OUT_DISK to a mount point to keep
# the directory on another disk; the tree then gets a symlink to it (Soong rejects an absolute
# out directory outside the tree).
#
# Needs two projects of the reference port in the tree (PLAN.md, "Downloads"):
#     device/brcm/rpi5-kernel   the kernel, its device trees and overlays
#     external/mesa3d-rpi       Mesa with the v3d and vc4 drivers

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "source me, do not execute: source ${0}"
  exit 1
fi

TREE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
export OUT_DIR="${OUT_DIR:-raspberry_out}"

if [ -n "${RPI5_OUT_DISK:-}" ]; then
  if ! mountpoint -q "$RPI5_OUT_DISK"; then
    echo "RPI5_OUT_DISK=$RPI5_OUT_DISK is not a mount point. Not sourcing."
    return 1
  fi
  if [ -e "$TREE/$OUT_DIR" ] && [ ! -L "$TREE/$OUT_DIR" ]; then
    echo "$TREE/$OUT_DIR exists and is not a symlink. Not sourcing."
    return 1
  fi
  mkdir -p "$RPI5_OUT_DISK/$OUT_DIR"
  [ -L "$TREE/$OUT_DIR" ] || ln -s "$RPI5_OUT_DISK/$OUT_DIR" "$TREE/$OUT_DIR"
fi

for p in device/brcm/rpi5-kernel/Image external/mesa3d-rpi/Android.bp; do
  if [ ! -e "$TREE/$p" ]; then
    echo "$p is missing: see PLAN.md, \"Downloads\". Not sourcing."
    return 1
  fi
done

cd "$TREE" || return 1
source build/envsetup.sh
lunch sdv_media_rpi5-trunk_staging-userdebug || return 1
echo "OUT_DIR=$OUT_DIR"
