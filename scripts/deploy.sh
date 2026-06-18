#!/usr/bin/env bash
# Dev loop: cross-build elise, ship the binary to the running Pi, restart the
# service, and tail the journal for QML errors.
#
#   ./scripts/deploy.sh            # build + deploy + show journal tail
#   ./scripts/deploy.sh --no-build # skip the build, just redeploy $CROSS_DIR/elise
#   ./scripts/deploy.sh <ip>       # force a specific Pi IP (skips discovery)
#
# The Pi binary lives at /usr/bin/elise and is held open by the running
# service, so we stop `hermes` before copying ("Text file busy" otherwise).
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

DO_BUILD=1; PI_IP=""
for a in "$@"; do
  case "$a" in
    --no-build) DO_BUILD=0 ;;
    [0-9]*.[0-9]*) PI_IP="$a" ;;
    *) die "usage: $0 [--no-build] [ip]" ;;
  esac
done

if [ "$DO_BUILD" = 1 ]; then
  ensure_cross
  log "cross build…"
  cmake --build "$CROSS_DIR" -- -j"$(nproc)"
fi
[ -f "$CROSS_DIR/elise" ] || die "no binary at $CROSS_DIR/elise — run a build first"

[ -n "$PI_IP" ] || PI_IP="$(find_pi)"
ok "Pi at $PI_IP"

log "stopping hermes…";            pi_ssh "$PI_IP" 'systemctl stop hermes'
log "copying elise…";              pi_scp "$PI_IP" "$CROSS_DIR/elise" /usr/bin/elise
log "starting hermes…";            pi_ssh "$PI_IP" 'systemctl start hermes'
sleep 2
log "journal (errors/warnings):"
pi_ssh "$PI_IP" 'journalctl -u hermes -n 20 --no-pager | grep -iE "qml:|error|warning" || echo CLEAN'
ok "deployed"
