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

# bluetoothd runs with default options for phase 1. We previously
# enabled --experimental for battery/A2DP improvements, but it also
# advertises LE Audio Broadcast (Auracast), which Samsung phones pick
# up as a broadcast source and confuses the pairing UX. Re-enable
# once LE Audio plumbing in WirePlumber is wired up.
rm -f "${TARGET_DIR}/etc/systemd/system/bluetooth.service.d/experimental.conf"

# PipeWire + WirePlumber as the system audio stack. WirePlumber handles
# routing — when a BT device connects with the A2DP-source role we hold,
# the PipeWire bluez5 module exposes a sink and WirePlumber routes audio
# to it. Both run as system services (no per-user session here).
ln -sf /usr/lib/systemd/system/pipewire.service \
    "${SYSTEMD_DIR}/multi-user.target.wants/pipewire.service" 2>/dev/null || true
ln -sf /usr/lib/systemd/system/wireplumber.service \
    "${SYSTEMD_DIR}/multi-user.target.wants/wireplumber.service" 2>/dev/null || true

# gpsd uses systemd socket activation — the socket listens on :2947
# and bluetoothd-style spawns the daemon on first client. We enable
# the socket (not the service itself); elise's GpsController connects
# whenever it likes and gpsd is fork()ed at that moment.
ln -sf /usr/lib/systemd/system/gpsd.socket \
    "${SYSTEMD_DIR}/sockets.target.wants/gpsd.socket" 2>/dev/null || true
mkdir -p "${SYSTEMD_DIR}/sockets.target.wants"
ln -sf /usr/lib/systemd/system/gpsd.socket \
    "${SYSTEMD_DIR}/sockets.target.wants/gpsd.socket" 2>/dev/null || true
# gpsd reads device list from /etc/default/gpsd. Until a real HAT is
# wired, leave DEVICES empty — the daemon still listens and elise
# falls back to its mock pose.
mkdir -p "${TARGET_DIR}/etc/default"
cat > "${TARGET_DIR}/etc/default/gpsd" <<'EOF'
DEVICES=""
GPSD_OPTIONS="-n"
USBAUTO="true"
EOF

# Disable bluez's packaged mpris-proxy.service — phase 2B reads the
# remote's MediaPlayer1 via bluez directly from BluetoothController,
# so no MPRIS bridge is needed.
rm -f "${SYSTEMD_DIR}/multi-user.target.wants/mpris-proxy.service"

ln -sf wpa_supplicant.conf \
    "${TARGET_DIR}/etc/wpa_supplicant/wpa_supplicant-wlan0.conf" 2>/dev/null || true

ln -sf /etc/systemd/system/hermes.service \
    "${SYSTEMD_DIR}/multi-user.target.wants/hermes.service"

ln -sf /lib/systemd/system/dropbear.service \
    "${SYSTEMD_DIR}/multi-user.target.wants/dropbear.service" 2>/dev/null || true

# wpa_supplicant on the system bus (-u). NetworkController in elise drives
# it directly via fi.w1.wpa_supplicant1. dhcpcd takes care of IP once the
# link comes up.
ln -sf /lib/systemd/system/wpa_supplicant.service \
    "${SYSTEMD_DIR}/multi-user.target.wants/wpa_supplicant.service" 2>/dev/null || true
ln -sf /lib/systemd/system/dhcpcd.service \
    "${SYSTEMD_DIR}/multi-user.target.wants/dhcpcd.service" 2>/dev/null || true

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

# Remove stale unit files left in /etc/systemd/system by previous overlay
# generations. Authoritative units now live under /usr/lib/systemd/system/
# (installed by their respective packages). Buildroot's incremental rootfs
# build does not garbage-collect files removed from the overlay, so we do
# it here explicitly to avoid the old file shadowing the package version.
rm -f "${SYSTEMD_DIR}/hermes-music.service"

# Disable services we don't use, *without* removing their packages —
# systemd installs system users and tmpfiles entries via those packages,
# and removing them leaves the rootfs in a broken state at image-gen
# time (e.g. fakeroot fails because `systemd-network` user is missing).
# Masking via /dev/null symlinks is the canonical way to keep a unit
# installed but never started.
#
# - networkd / resolved / timesyncd: superseded by dhcpcd + wpa_supplicant
#   (NetworkController talks to wpa_supplicant1 over D-Bus directly).
#   Masking these saves ~1-2 s of boot time.
# - hermes-music-bootstrap: replaced by build-time install of all Python
#   deps into the target's site-packages — no first-boot setup needed.
for u in \
    systemd-networkd.service \
    systemd-networkd-wait-online.service \
    systemd-resolved.service ; do
    ln -sf /dev/null "${SYSTEMD_DIR}/${u}"
done
# Keep timesyncd active: the Pi 5 has no battery-backed RTC, so without
# NTP the clock starts at the rootfs build date and TLS certificate
# checks fail with "certificate is not yet valid".
#
# Buildroot's target/ is incremental — older runs may have masked
# timesyncd. Drop any stale /dev/null symlink and (re-)create the enable
# link matching the unit's `WantedBy=sysinit.target`.
rm -f "${SYSTEMD_DIR}/systemd-timesyncd.service"
mkdir -p "${SYSTEMD_DIR}/sysinit.target.wants"
ln -sf /usr/lib/systemd/system/systemd-timesyncd.service \
    "${SYSTEMD_DIR}/sysinit.target.wants/systemd-timesyncd.service"

# systemd-time-wait-sync.service blocks `time-sync.target` until the
# clock has actually been synchronised by timesyncd. hermes.service and
# hermes-music.service order themselves after that target so they never
# run with a build-date clock that breaks TLS.
ln -sf /usr/lib/systemd/system/systemd-time-wait-sync.service \
    "${SYSTEMD_DIR}/sysinit.target.wants/systemd-time-wait-sync.service"
rm -f "${TARGET_DIR}/usr/lib/systemd/system/hermes-music-bootstrap.service"
rm -f "${SYSTEMD_DIR}/multi-user.target.wants/hermes-music-bootstrap.service"

# /etc/resolv.conf ships as a symlink to /run/systemd/resolve/resolv.conf
# because systemd installs it that way. With resolved masked, that path
# never exists, so libc resolution fails. Replace it with a real file
# containing a couple of public resolvers; dhcpcd will rewrite it from
# DHCP options on link-up.
rm -f "${TARGET_DIR}/etc/resolv.conf"
cat > "${TARGET_DIR}/etc/resolv.conf" <<'EOF'
# Default resolvers — dhcpcd rewrites this file at runtime with the
# resolvers advertised over DHCP.
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

# OpenSSL's compiled-in default CA file is /etc/ssl/cert.pem (BSD-style),
# but Buildroot's ca-certificates package writes the bundle to
# /etc/ssl/certs/ca-certificates.crt (Debian-style). Without the symlink,
# Python's ssl module ends up with cafile=None and any HTTPS request
# fails with CERTIFICATE_VERIFY_FAILED.
ln -sf certs/ca-certificates.crt "${TARGET_DIR}/etc/ssl/cert.pem"

# Não bloquear boot esperando rede
ln -sf /dev/null \
    "${SYSTEMD_DIR}/network-online.target.wants/systemd-networkd-wait-online.service" 2>/dev/null || true

echo "post-build.sh: ${BOARD_NAME} done."
