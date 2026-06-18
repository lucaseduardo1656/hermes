#!/usr/bin/env bash
# Build the full flashable SD-card image via Buildroot.
#
#   ./scripts/image.sh          # rebuild the elise package + reassemble the image
#   ./scripts/image.sh --full    # also re-run defconfig (toolchain/manifest change)
#
# `elise-dirclean` is required because the package uses the `local` site method:
# editing src/elise/ does NOT trigger a rebuild on its own. The rootfs-overlay
# (fonts, etc.) is copied in at image-assembly time. Output: $IMAGE.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cd "$BUILDROOT"

if [ "${1:-}" = "--full" ]; then
  log "make hermes_pi5_defconfig…"
  make hermes_pi5_defconfig
fi

log "elise-dirclean (force pkg rebuild from src)…"
make elise-dirclean

log "make (rebuild elise + reassemble image)… this takes a while"
make

[ -f "$IMAGE" ] || die "image not produced at $IMAGE"
ok "image ready: $IMAGE ($(du -h "$IMAGE" | cut -f1))"
echo "flash with: ./scripts/flash.sh /dev/sdX"
