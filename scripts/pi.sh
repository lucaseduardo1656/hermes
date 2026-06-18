#!/usr/bin/env bash
# Pi helpers: discover IP, open a shell, tail logs, restart, push fonts.
#
#   ./scripts/pi.sh ip                 # discover + print the Pi IP (cached)
#   ./scripts/pi.sh ssh [cmd...]       # ssh into the Pi (or run a command)
#   ./scripts/pi.sh logs               # follow the hermes journal
#   ./scripts/pi.sh restart            # restart the hermes service
#   ./scripts/pi.sh fonts              # push rootfs-overlay fonts to the Pi (dev)
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

cmd="${1:-ip}"; shift || true
IP="$(find_pi)"

case "$cmd" in
  ip)      echo "$IP" ;;
  ssh)     if [ "$#" -gt 0 ]; then pi_ssh "$IP" "$@"; else ssh "${SSH_OPTS[@]}" "$PI_USER@$IP"; fi ;;
  logs)    pi_ssh "$IP" 'journalctl -u hermes -f' ;;
  restart) pi_ssh "$IP" 'systemctl restart hermes'; ok "restarted" ;;
  fonts)
    local_overlay="$PROJECT/board/hermes-pi5/rootfs-overlay/usr/share/fonts"
    [ -d "$local_overlay" ] || die "no font overlay at $local_overlay"
    log "pushing fonts from overlay…"
    pi_ssh "$IP" 'mkdir -p /usr/share/fonts'
    # copy each font dir under the overlay
    find "$local_overlay" -type f \( -name '*.ttf' -o -name '*.otf' \) | while read -r f; do
      rel="${f#"$local_overlay"/}"
      pi_ssh "$IP" "mkdir -p /usr/share/fonts/$(dirname "$rel")"
      pi_scp "$IP" "$f" "/usr/share/fonts/$rel"
    done
    pi_ssh "$IP" 'fc-cache -f >/dev/null 2>&1; echo done'
    ok "fonts pushed (+ fc-cache)"
    ;;
  *) die "usage: $0 [ip|ssh|logs|restart|fonts]" ;;
esac
