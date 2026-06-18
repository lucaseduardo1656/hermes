#!/usr/bin/env bash
# Flash the built image to an SD card.
#
#   ./scripts/flash.sh /dev/sdX
#
# DESTRUCTIVE: overwrites the whole target device. Lists block devices, shows
# the target, and requires you to type the device path again to confirm.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DEV="${1:-}"
[ -n "$DEV" ] || { lsblk -dpno NAME,SIZE,MODEL; die "usage: $0 /dev/sdX (pick a whole disk above, not a partition)"; }
[ -b "$DEV" ] || die "$DEV is not a block device"
[ -f "$IMAGE" ] || die "no image at $IMAGE — run ./scripts/image.sh first"

echo "=== TARGET ==="; lsblk -po NAME,SIZE,MODEL,MOUNTPOINTS "$DEV"
echo "=== IMAGE  ==="; ls -lh "$IMAGE"
err "This will ERASE everything on $DEV."
read -rp "Type the device path again to confirm ($DEV): " confirm
[ "$confirm" = "$DEV" ] || die "mismatch — aborted"

log "flashing… (sudo)"
sudo dd if="$IMAGE" of="$DEV" bs=4M status=progress conv=fsync
sync
ok "flashed $IMAGE -> $DEV"
