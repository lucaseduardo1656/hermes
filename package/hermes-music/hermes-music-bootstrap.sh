#!/bin/sh
# First-boot bootstrap for hermes-music: creates a Python venv on the
# target and pip-installs the daemon's requirements. Runs once; the
# venv lives in /var/lib/hermes-music/venv and persists across reboots.
set -e

VENV=/var/lib/hermes-music/venv
SRC=/usr/share/hermes-music
MARKER=/var/lib/hermes-music/.bootstrap-done

if [ -f "$MARKER" ] && [ -x "$VENV/bin/python3" ]; then
    echo "hermes-music: bootstrap already complete; skipping."
    exit 0
fi

mkdir -p /var/lib/hermes-music
python3 -m venv "$VENV"
"$VENV/bin/pip" install --upgrade pip
"$VENV/bin/pip" install -r "$SRC/requirements.txt"
touch "$MARKER"
echo "hermes-music: bootstrap complete."
