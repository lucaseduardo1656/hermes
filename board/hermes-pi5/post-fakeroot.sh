#!/bin/bash
# Runs inside fakeroot, AFTER systemctl preset-all — safe to fix wpa symlinks here.
set -e

TARGET_DIR="${TARGET_DIR}"
SYSTEMD_DIR="${TARGET_DIR}/etc/systemd/system"

mkdir -p "${SYSTEMD_DIR}/multi-user.target.wants"

# Remove generic wpa_supplicant.service that preset-all may have re-enabled
rm -f "${SYSTEMD_DIR}/multi-user.target.wants/wpa_supplicant.service"

# Enable interface-specific instance so wpa_cli can reach wlan0
ln -sf /lib/systemd/system/wpa_supplicant@.service \
    "${SYSTEMD_DIR}/multi-user.target.wants/wpa_supplicant@wlan0.service" 2>/dev/null || true

echo "post-fakeroot.sh: wpa_supplicant@wlan0 enabled."
