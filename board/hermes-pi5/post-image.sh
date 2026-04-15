#!/bin/bash
set -e

BOARD_DIR="$(dirname "$0")"
GENIMAGE_CFG="${BINARIES_DIR}/genimage.cfg"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"

# Flatten rpi-firmware/ files to BINARIES_DIR root.
# The RPi5 EEPROM expects firmware files (config.txt, cmdline.txt, etc.)
# at the root of the VFAT boot partition.
for i in "${BINARIES_DIR}"/rpi-firmware/*; do
    [ -f "$i" ] && cp -f "$i" "${BINARIES_DIR}/"
done

# Copy the overlays/ directory to BINARIES_DIR root so genimage can include it.
# This is critical for BCM2712D0 boards (RPi5 Rev 1.1) — the EEPROM applies
# overlays/bcm2712d0.dtbo automatically before the kernel boots; without it,
# GPIO pull registers are misconfigured and the kernel gets an SError.
if [ -d "${BINARIES_DIR}/rpi-firmware/overlays" ]; then
    cp -r "${BINARIES_DIR}/rpi-firmware/overlays" "${BINARIES_DIR}/"
fi

# Our config.txt and cmdline.txt override the rpi-firmware defaults
cp -f "${BOARD_DIR}/config.txt" "${BINARIES_DIR}/config.txt"
cp -f "${BOARD_DIR}/cmdline.txt" "${BINARIES_DIR}/cmdline.txt"

# Collect files for the boot VFAT
FILES=()

# DTBs (all .dtb files at BINARIES_DIR root)
for i in "${BINARIES_DIR}"/*.dtb; do
    [ -f "$i" ] && FILES+=( "$(basename "$i")" )
done

# Firmware blobs (skip subdirectories, those are handled separately)
for f in start.elf fixup.dat start4.elf fixup4.dat bootcode.bin; do
    [ -f "${BINARIES_DIR}/${f}" ] && FILES+=( "${f}" )
done

# Essential boot files
FILES+=( "config.txt" "cmdline.txt" "Image" )

# Overlays directory (for bcm2712d0.dtbo and others)
[ -d "${BINARIES_DIR}/overlays" ] && FILES+=( "overlays" )

# Build the file list for genimage.cfg
BOOT_FILES=""
for f in "${FILES[@]}"; do
    BOOT_FILES="${BOOT_FILES}			\"${f}\",\n"
done

# Generate genimage.cfg from template
awk -v files="${BOOT_FILES}" '
    /^#BOOT_FILES#$/ { printf "%s", files; next }
    { print }
' "${BOARD_DIR}/genimage.cfg.in" > "${GENIMAGE_CFG}"

# Run genimage
trap 'rm -rf "${ROOTPATH_TMP}"' EXIT
ROOTPATH_TMP="$(mktemp -d)"
rm -rf "${GENIMAGE_TMP}"

genimage \
    --rootpath "${ROOTPATH_TMP}" \
    --tmppath  "${GENIMAGE_TMP}" \
    --inputpath "${BINARIES_DIR}" \
    --outputpath "${BINARIES_DIR}" \
    --config "${GENIMAGE_CFG}"

echo ""
echo "========================================="
echo "  Imagem: output/images/hermes-pi5.img"
echo "  Gravar: sudo dd if=output/images/hermes-pi5.img of=/dev/sdX bs=4M status=progress"
echo "========================================="
