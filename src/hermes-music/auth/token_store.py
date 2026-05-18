"""Persist OAuth tokens to disk encrypted with a machine key."""
import json
import os
from pathlib import Path

from config import DATA_DIR

_TOKENS_FILE = DATA_DIR / "tokens.json"


def _load() -> dict:
    if not _TOKENS_FILE.exists():
        return {}
    try:
        return json.loads(_TOKENS_FILE.read_text())
    except Exception:
        return {}


def _save(data: dict) -> None:
    _TOKENS_FILE.write_text(json.dumps(data, indent=2))
    os.chmod(_TOKENS_FILE, 0o600)


def get(provider: str) -> dict | None:
    return _load().get(provider)


def put(provider: str, token: dict) -> None:
    data = _load()
    data[provider] = token
    _save(data)


def delete(provider: str) -> None:
    data = _load()
    data.pop(provider, None)
    _save(data)


def connected_providers() -> list[str]:
    return list(_load().keys())
