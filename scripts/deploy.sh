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

# Build FIRST, while the service keeps running — a slow or failed build never
# touches the Pi, so it can't leave the screen dead.
if [ "$DO_BUILD" = 1 ]; then
  ensure_cross
  log "cross build…"
  cmake --build "$CROSS_DIR" -- -j"$(nproc)"
fi
[ -f "$CROSS_DIR/elise" ] || die "no binary at $CROSS_DIR/elise — run a build first"

[ -n "$PI_IP" ] || PI_IP="$(find_pi)"
ok "Pi at $PI_IP"

# Stage the new binary while hermes is still up (scp is the slow step; doing it
# here keeps the service-down window to a single mv). /usr/bin/elise is held
# open by the running service, so we can't overwrite it directly — copy beside
# it, then swap under a brief stop.
log "staging binary…";             pi_scp "$PI_IP" "$CROSS_DIR/elise" /usr/bin/elise.new

# From here on the service may be stopped — guarantee it comes back even if we
# are killed (e.g. an outer timeout), so the Pi never gets stranded with a dead
# UI. This was the old failure mode.
restart_guard() { pi_ssh "$PI_IP" 'systemctl start hermes' >/dev/null 2>&1 || true; }
trap restart_guard EXIT INT TERM

log "swapping + restarting…"
pi_ssh "$PI_IP" 'systemctl stop hermes && mv /usr/bin/elise.new /usr/bin/elise && systemctl start hermes'

trap - EXIT INT TERM   # clean swap done; drop the guard
sleep 2
log "journal (errors/warnings):"
pi_ssh "$PI_IP" 'journalctl -u hermes -n 20 --no-pager | grep -iE "qml:|error|warning" || echo CLEAN'
ok "deployed"
