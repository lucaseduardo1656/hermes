#!/bin/bash
set -e

BOARD_DIR="$(dirname "$0")"
GENIMAGE_CFG="${1:-${BOARD_DIR}/genimage.cfg}"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"

# Usar genimage para criar a imagem do SD card
rm -rf "${GENIMAGE_TMP}"

genimage \
    --rootpath "${TARGET_DIR}" \
    --tmppath "${GENIMAGE_TMP}" \
    --inputpath "${BINARIES_DIR}" \
    --outputpath "${BINARIES_DIR}" \
    --config "${GENIMAGE_CFG}"

echo ""
echo "========================================="
echo "  Imagem gerada: output/images/hermes-pi5.img"
echo "  Gravar com:"
echo "  sudo dd if=output/images/hermes-pi5.img of=/dev/sdX bs=4M status=progress"
echo "========================================="
