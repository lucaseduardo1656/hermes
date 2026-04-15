#!/bin/bash
set -e

BOARD_DIR="$(dirname "$0")"
BOARD_NAME="$(basename "${BOARD_DIR}")"
TARGET_DIR="${TARGET_DIR}"

# Criar usuário hermes se não existir no rootfs
if ! grep -q "^hermes:" "${TARGET_DIR}/etc/passwd"; then
    echo "hermes:x:1000:1000:Hermes,,,:/home/hermes:/bin/bash" >> "${TARGET_DIR}/etc/passwd"
    echo "hermes:x:1000:" >> "${TARGET_DIR}/etc/group"
    echo "hermes::19000:0:99999:7:::" >> "${TARGET_DIR}/etc/shadow"
    install -d -m 0755 -o 1000 -g 1000 "${TARGET_DIR}/home/hermes"
fi

# Adicionar hermes aos grupos necessários (sem duplicar)
for group in audio video input render seat tty dialout; do
    if grep -q "^${group}:" "${TARGET_DIR}/etc/group"; then
        if ! grep -q "^${group}:.*hermes" "${TARGET_DIR}/etc/group"; then
            sed -i "s/^${group}:\(.*\)/\0,hermes/" "${TARGET_DIR}/etc/group"
        fi
    fi
done

# Habilitar serviços systemd
SYSTEMD_DIR="${TARGET_DIR}/etc/systemd/system"
mkdir -p "${SYSTEMD_DIR}/multi-user.target.wants"
mkdir -p "${SYSTEMD_DIR}/network-online.target.wants"

ln -sf /lib/systemd/system/bluetooth.service \
    "${SYSTEMD_DIR}/multi-user.target.wants/bluetooth.service" 2>/dev/null || true

ln -sf /lib/systemd/system/wpa_supplicant.service \
    "${SYSTEMD_DIR}/multi-user.target.wants/wpa_supplicant.service" 2>/dev/null || true

ln -sf /etc/systemd/system/hermes.service \
    "${SYSTEMD_DIR}/multi-user.target.wants/hermes.service"

ln -sf /lib/systemd/system/dropbear.service \
    "${SYSTEMD_DIR}/multi-user.target.wants/dropbear.service" 2>/dev/null || true

# WiFi firmware — driver brcmfmac procura em brcm/, binário está em cypress/
# Cria symlinks para RPi5 (CYW43455)
BRCM_FW="${TARGET_DIR}/lib/firmware/brcm"
CYPRESS_FW="${TARGET_DIR}/lib/firmware/cypress"
if [ -d "${CYPRESS_FW}" ] && [ -f "${CYPRESS_FW}/cyfmac43455-sdio.bin" ]; then
    mkdir -p "${BRCM_FW}"
    ln -sf ../cypress/cyfmac43455-sdio.bin \
        "${BRCM_FW}/brcmfmac43455-sdio.bin" 2>/dev/null || true
    ln -sf ../cypress/cyfmac43455-sdio.clm_blob \
        "${BRCM_FW}/brcmfmac43455-sdio.clm_blob" 2>/dev/null || true
    # Txt de board para RPi5 — copia do RPi4 (chips compatíveis)
    # Tenta primeiro do target (se BCM43XXX instalou), depois direto da source
    RPi4_TXT="${BRCM_FW}/brcmfmac43455-sdio.raspberrypi,4-model-b.txt"
    RPi4_SRC=$(find /home/mirage/Projects/hermes/buildroot/output/build/linux-firmware-*/brcm/ \
        -name "brcmfmac43455-sdio.raspberrypi,4-model-b.txt" 2>/dev/null | head -1)
    if [ -f "${RPi4_TXT}" ]; then
        cp -f "${RPi4_TXT}" "${BRCM_FW}/brcmfmac43455-sdio.raspberrypi,5-model-b.txt" 2>/dev/null || true
    elif [ -f "${RPi4_SRC}" ]; then
        cp -f "${RPi4_SRC}" "${BRCM_FW}/brcmfmac43455-sdio.raspberrypi,5-model-b.txt" 2>/dev/null || true
    fi
fi

# Não bloquear boot esperando rede
ln -sf /dev/null \
    "${SYSTEMD_DIR}/network-online.target.wants/systemd-networkd-wait-online.service" 2>/dev/null || true

echo "post-build.sh: ${BOARD_NAME} done."
