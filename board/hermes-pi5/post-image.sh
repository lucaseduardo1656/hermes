#!/bin/bash
set -e

BOARD_DIR="$(dirname "$0")"
GENIMAGE_CFG="${BINARIES_DIR}/genimage.cfg"
GENIMAGE_TMP="${BUILD_DIR}/genimage.tmp"

# Coletar arquivos do boot: DTBs + conteúdo de rpi-firmware/ + kernel
FILES=()
for i in "${BINARIES_DIR}"/*.dtb; do
    [ -f "$i" ] && FILES+=( "$(basename "$i")" )
done
for i in "${BINARIES_DIR}"/rpi-firmware/*; do
    [ -f "$i" ] && FILES+=( "rpi-firmware/$(basename "$i")" )
done
FILES+=( "Image" )

# Montar bloco de arquivos para o genimage.cfg
BOOT_FILES=""
for f in "${FILES[@]}"; do
    BOOT_FILES="${BOOT_FILES}			\"${f}\",\n"
done

# Gerar genimage.cfg a partir do template usando awk
awk -v files="${BOOT_FILES}" '
    /^#BOOT_FILES#$/ { printf "%s", files; next }
    { print }
' "${BOARD_DIR}/genimage.cfg.in" > "${GENIMAGE_CFG}"

# Rodar genimage
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
