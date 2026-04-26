#!/usr/bin/env bash
# Build a standalone binary with PyInstaller for Buildroot deployment.
# Run on the RPi or via cross-compilation with matching Python version.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "[hermes-music] Installing dependencies..."
pip install -r requirements.txt pyinstaller --quiet

echo "[hermes-music] Building binary..."
pyinstaller \
    --onefile \
    --name hermes-music \
    --add-data "$(python -c 'import ytmusicapi; import os; print(os.path.dirname(ytmusicapi.__file__))'):ytmusicapi" \
    --hidden-import uvicorn.logging \
    --hidden-import uvicorn.loops.auto \
    --hidden-import uvicorn.protocols.http.auto \
    --hidden-import uvicorn.lifespan.on \
    --hidden-import yt_dlp.extractor \
    main.py

echo "[hermes-music] Binary at dist/hermes-music"
echo "Copy to target: scp dist/hermes-music pi@raspberrypi:/usr/share/hermes-music/"
