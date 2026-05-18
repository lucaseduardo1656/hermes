"""
Local play history — persisted to disk.
Used to build "Recently played" section on home page.
"""
import json
import time
from collections import deque
from pathlib import Path

from config import DATA_DIR

_HISTORY_FILE = DATA_DIR / "history.json"
_MAX = 50  # keep last 50 tracks

# In-memory deque, newest first
_history: deque[dict] = deque(maxlen=_MAX)
_loaded = False


def _load() -> None:
    global _loaded
    if _loaded:
        return
    _loaded = True
    if not _HISTORY_FILE.exists():
        return
    try:
        items = json.loads(_HISTORY_FILE.read_text())
        _history.extend(reversed(items))  # file is newest-first, deque appends to right
    except Exception:
        pass


def _save() -> None:
    items = list(reversed(_history))  # newest first
    _HISTORY_FILE.write_text(json.dumps(items, indent=2))


def record(track: dict) -> None:
    """Call when a track starts playing."""
    _load()
    # Remove existing entry for same track (avoid duplicates)
    existing = [t for t in _history if t.get("id") == track.get("id")]
    for e in existing:
        _history.remove(e)
    _history.append({**track, "_played_at": time.time()})
    _save()


def recent(limit: int = 20) -> list[dict]:
    _load()
    items = list(reversed(_history))  # newest first
    return items[:limit]
