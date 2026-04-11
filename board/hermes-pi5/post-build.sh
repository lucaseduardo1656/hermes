#!/bin/bash
set -e

BOARD_DIR="$(dirname "$0")"
BOARD_NAME="$(basename "${BOARD_DIR}")"
GENIMAGE_CFG="${BOARD_DIR}/genimage.cfg"
TARGET_DIR="${TARGET_DIR}"

# Copiar config.txt do firmware para a partição boot
cp "${BOARD_DIR}/config.txt" "${BINARIES_DIR}/config.txt"

# cmdline.txt — parâmetros do kernel
cat > "${BINARIES_DIR}/cmdline.txt" << 'EOF'
console=ttyAMA0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait quiet logo.nologo
EOF

# Criar usuário hermes se não existir no rootfs
if ! grep -q "^hermes:" "${TARGET_DIR}/etc/passwd"; then
    echo "hermes:x:1000:1000:Hermes,,,:/home/hermes:/bin/bash" >> "${TARGET_DIR}/etc/passwd"
    echo "hermes:x:1000:" >> "${TARGET_DIR}/etc/group"
    echo "hermes::19000:0:99999:7:::" >> "${TARGET_DIR}/etc/shadow"
    install -d -m 0755 -o 1000 -g 1000 "${TARGET_DIR}/home/hermes"
fi

# Adicionar hermes aos grupos necessários
for group in audio video input render seat tty dialout; do
    if grep -q "^${group}:" "${TARGET_DIR}/etc/group"; then
        sed -i "s/^${group}:\(.*\)/\0,hermes/" "${TARGET_DIR}/etc/group" 2>/dev/null || true
    fi
done

# Habilitar serviços systemd
SYSTEMD_DIR="${TARGET_DIR}/etc/systemd/system"
ln -sf /lib/systemd/system/bluetooth.service \
    "${SYSTEMD_DIR}/bluetooth.service" 2>/dev/null || true

ln -sf /lib/systemd/system/wpa_supplicant.service \
    "${SYSTEMD_DIR}/multi-user.target.wants/wpa_supplicant.service" 2>/dev/null || true

echo "post-build.sh: ${BOARD_NAME} done."
