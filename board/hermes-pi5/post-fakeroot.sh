#!/bin/bash
# Runs inside fakeroot, AFTER systemctl preset-all — safe to fix wpa symlinks here.
set -e

TARGET_DIR="${TARGET_DIR}"
SYSTEMD_DIR="${TARGET_DIR}/etc/systemd/system"

mkdir -p "${SYSTEMD_DIR}/multi-user.target.wants"

# We drive wpa_supplicant directly over D-Bus (fi.w1.wpa_supplicant1) from
# elise's NetworkController. The service must run in -u mode (no per-iface
# instance, no config file). Buildroot's preset can leave the @wlan0
# instance enabled; remove it and force the generic unit instead.
rm -f "${SYSTEMD_DIR}/multi-user.target.wants/wpa_supplicant@wlan0.service"
ln -sf /lib/systemd/system/wpa_supplicant.service \
    "${SYSTEMD_DIR}/multi-user.target.wants/wpa_supplicant.service" 2>/dev/null || true

echo "post-fakeroot.sh: wpa_supplicant.service (D-Bus mode) enabled."
