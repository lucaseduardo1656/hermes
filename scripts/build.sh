#!/usr/bin/env bash
# Build the Elise app.
#
#   ./scripts/build.sh host   # x86 host build — fast QML/CMake validation
#   ./scripts/build.sh arm     # aarch64 cross build (Buildroot SDK) -> $CROSS_DIR/elise
#   ./scripts/build.sh         # both (host first, then arm)
#
# Use `host` for a quick "does the QML compile" check; `arm` produces the binary
# that deploy.sh ships to the Pi.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

build_host() {
  log "host build (QML validation)…"
  cmake --build "$HOST_BUILD" -- -j"$(nproc)"
  ok "host build done"
}

build_arm() {
  ensure_cross
  log "aarch64 cross build…"
  cmake --build "$CROSS_DIR" -- -j"$(nproc)"
  ok "arm build done -> $CROSS_DIR/elise"
}

case "${1:-all}" in
  host) build_host ;;
  arm)  build_arm ;;
  all)  build_host; build_arm ;;
  *)    die "usage: $0 [host|arm]" ;;
esac
