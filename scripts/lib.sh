#!/usr/bin/env bash
# Shared helpers for the Elise build/deploy/flash scripts.
# Sourced by the other scripts in this dir — not run directly.
#
# Provides: paths, Pi discovery (DHCP floats), SSH/SCP wrappers that tolerate
# host-key rotation on reflash, and cross-build-dir bootstrap.
set -euo pipefail

# ── Paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$SCRIPT_DIR/.." && pwd)"

ELISE_SRC="$PROJECT/src/elise"            # Qt/QML app source
HOST_BUILD="$ELISE_SRC/build"             # host build dir (x86, QML validation)
CROSS_DIR="/tmp/hermes-cross-build"       # aarch64 cross build dir (dev loop)
BUILDROOT="$PROJECT/buildroot"
TOOLCHAIN="$BUILDROOT/output/host"        # Buildroot host SDK (aarch64 toolchain)
IMAGE="$BUILDROOT/output/images/hermes-pi5.img"

PI_USER="root"
PI_PORT=22
PI_HOSTNAME="hermes"                      # how we identify the right host on the LAN
PI_SUBNET="192.168.0"                     # /24 to scan when discovering the Pi
PI_CACHE="/tmp/hermes-pi-ip"              # last known good IP

SSH_OPTS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=5)

log()  { printf '\033[1;36m▶ %s\033[0m\n' "$*" >&2; }
ok()   { printf '\033[1;32m✓ %s\033[0m\n' "$*" >&2; }
err()  { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

# ── SSH/SCP wrappers ─────────────────────────────────────────────────────────
# Reflashing the Pi rotates its SSH host key; drop the stale entry and retry
# rather than failing with "REMOTE HOST IDENTIFICATION HAS CHANGED".
_fix_hostkey() { ssh-keygen -R "$1" >/dev/null 2>&1 || true; }

pi_ssh() {  # pi_ssh <ip> <remote-cmd...>
  local ip="$1"; shift
  if ! ssh "${SSH_OPTS[@]}" "$PI_USER@$ip" "$@" 2>/tmp/.pi_ssh_err; then
    if grep -q "HOST IDENTIFICATION HAS CHANGED\|Host key verification failed" /tmp/.pi_ssh_err; then
      _fix_hostkey "$ip"
      ssh "${SSH_OPTS[@]}" "$PI_USER@$ip" "$@"
    else
      cat /tmp/.pi_ssh_err >&2; return 1
    fi
  fi
}

pi_scp() {  # pi_scp <ip> <localfile> <remotepath>
  local ip="$1" src="$2" dst="$3"
  _fix_hostkey "$ip"   # always refresh — cheap, avoids the changed-key abort
  scp -O "${SSH_OPTS[@]}" "$src" "$PI_USER@$ip:$dst"
}

# ── Pi discovery ─────────────────────────────────────────────────────────────
# DHCP moves the Pi around; never hardcode. Verify by hostname so we never
# deploy to the wrong host. Result is cached in $PI_CACHE.
_is_pi() { [ "$(pi_ssh "$1" hostname 2>/dev/null)" = "$PI_HOSTNAME" ]; }

find_pi() {
  # 1) cached IP
  if [ -f "$PI_CACHE" ]; then
    local cached; cached="$(cat "$PI_CACHE")"
    if _is_pi "$cached"; then echo "$cached"; return 0; fi
  fi
  # 2) parallel SSH-port scan of the /24, then verify hostname on each open host.
  #    (A ping-sweep just floods the ARP table with INCOMPLETE entries, so we
  #    probe port 22 directly and collect the hosts that answer.)
  log "discovering Pi (hostname=$PI_HOSTNAME) on $PI_SUBNET.0/24…"
  local open="/tmp/.pi_open.$$"; : > "$open"
  local i
  for i in $(seq 2 254); do
    ( timeout 1 bash -c "echo > /dev/tcp/$PI_SUBNET.$i/$PI_PORT" 2>/dev/null \
        && echo "$PI_SUBNET.$i" >> "$open" ) &
  done
  wait
  local ip
  for ip in $(sort -t. -k4 -n "$open"); do
    if _is_pi "$ip"; then rm -f "$open"; echo "$ip" | tee "$PI_CACHE"; return 0; fi
  done
  rm -f "$open"
  die "Pi not found on $PI_SUBNET.0/24 (hostname=$PI_HOSTNAME). Powered on?"
}

# ── Cross build dir ──────────────────────────────────────────────────────────
# /tmp is wiped on reboot; recreate the aarch64 cross dir from the Buildroot SDK.
ensure_cross() {
  [ -x "$TOOLCHAIN/bin/qt-cmake" ] || die "Buildroot SDK missing at $TOOLCHAIN (run a full image build once)"
  if [ ! -f "$CROSS_DIR/CMakeCache.txt" ]; then
    log "bootstrapping cross build dir $CROSS_DIR…"
    local prefix="$TOOLCHAIN/aarch64-buildroot-linux-gnu/sysroot"
    mkdir -p "$CROSS_DIR"
    ( cd "$CROSS_DIR" && "$TOOLCHAIN/bin/qt-cmake" \
        -DCMAKE_BUILD_TYPE=Release \
        -DQT_CHAINLOAD_TOOLCHAIN_FILE="$TOOLCHAIN/share/buildroot/toolchainfile.cmake" \
        -DQT_ADDITIONAL_PACKAGES_PREFIX_PATH="$prefix/usr" \
        "$ELISE_SRC" >/dev/null )
  fi
}
