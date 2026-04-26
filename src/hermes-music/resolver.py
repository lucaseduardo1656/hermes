"""
Audio stream URL resolver using yt-dlp.
- ytmusic tracks: resolved by YouTube video ID directly.
- spotify tracks: searched on YouTube by "title artist" query (Spotube approach).
- soundcloud tracks: resolved by SC webpage URL directly.
- All sources: check local downloads first (offline fallback).
"""
import asyncio
import time
from pathlib import Path

import yt_dlp

from config import settings, DATA_DIR

_COOKIES_FILE = DATA_DIR / "cookies.txt"
DOWNLOADS_DIR = DATA_DIR / "downloads"
DOWNLOADS_DIR.mkdir(exist_ok=True)

# In-memory stream URL cache: {track_id: (url, expires_at)}
_cache: dict[str, tuple[str, float]] = {}


def _ydl_opts(extra: dict | None = None) -> dict:
    opts: dict = {
        "quiet": True,
        "no_warnings": True,
        "skip_download": True,
        "format": settings.audio_format,
        "cachedir": str(DATA_DIR / "yt-dlp-cache"),
    }
    if _COOKIES_FILE.exists():
        opts["cookiefile"] = str(_COOKIES_FILE)
    else:
        opts["cookiesfrombrowser"] = ("firefox",)
    if extra:
        opts.update(extra)
    return opts


def local_path(track_id: str) -> Path | None:
    """Return path to downloaded file if it exists, else None."""
    safe = track_id.replace(":", "_").replace("/", "_")
    for ext in ("m4a", "opus", "mp3", "webm", "ogg"):
        p = DOWNLOADS_DIR / f"{safe}.{ext}"
        if p.exists():
            return p
    return None


async def resolve(track: dict) -> dict:
    """
    Returns {url, ext, local, expires_at} or raises ValueError.
    Checks local downloads first — works offline.
    """
    track_id = track["id"]

    # 1. Local download — always works offline
    local = local_path(track_id)
    if local:
        return {
            "url":        local.as_uri(),   # file:///path/to/file.m4a
            "ext":        local.suffix.lstrip("."),
            "local":      True,
            "expires_at": None,
            "cached":     False,
        }

    # 2. In-memory stream URL cache
    if track_id in _cache:
        url, exp = _cache[track_id]
        if time.time() < exp:
            return {"url": url, "local": False, "cached": True}
        del _cache[track_id]

    # 3. Resolve via yt-dlp (requires network)
    source = track.get("source", "")

    if source == "ytmusic" and track.get("_yt_id"):
        url, ext = await _resolve_by_yt_id(track["_yt_id"])
    elif source == "soundcloud" and track.get("_sc_url"):
        url, ext = await _resolve_by_url(track["_sc_url"])
    elif track.get("_search"):
        url, ext = await _resolve_by_search(track["_search"])
    else:
        raise ValueError(f"Cannot resolve track: {track_id}")

    expires_at = time.time() + settings.stream_url_cache_ttl
    _cache[track_id] = (url, expires_at)

    return {
        "url":        url,
        "ext":        ext,
        "local":      False,
        "expires_at": expires_at,
        "cached":     False,
    }


# ── yt-dlp helpers ────────────────────────────────────────────────────────────

async def _resolve_by_yt_id(video_id: str) -> tuple[str, str]:
    return await _resolve_by_url(f"https://music.youtube.com/watch?v={video_id}")


async def _resolve_by_url(url: str) -> tuple[str, str]:
    def _extract():
        with yt_dlp.YoutubeDL(_ydl_opts()) as ydl:
            info = ydl.extract_info(url, download=False)
            if not info:
                raise ValueError(f"yt-dlp returned nothing for {url}")
            if "entries" in info:
                info = info["entries"][0]
            return _best_audio_url(info)

    return await asyncio.to_thread(_extract)


async def _resolve_by_search(query: str) -> tuple[str, str]:
    def _extract():
        with yt_dlp.YoutubeDL(_ydl_opts()) as ydl:
            info = ydl.extract_info(f"ytsearch1:{query} audio", download=False)
            if not info:
                raise ValueError(f"No results for: {query}")
            entry = info
            if "entries" in info:
                entries = list(info["entries"])
                if not entries:
                    raise ValueError(f"No entries for: {query}")
                entry = entries[0]
            return _best_audio_url(entry)

    return await asyncio.to_thread(_extract)


def _best_audio_url(info: dict) -> tuple[str, str]:
    formats = info.get("formats") or []
    audio = [f for f in formats if f.get("vcodec") == "none" and f.get("url")]
    if audio:
        for f in reversed(audio):
            if f.get("ext") in ("m4a", "aac"):
                return f["url"], f.get("ext", "m4a")
        best = audio[-1]
        return best["url"], best.get("ext", "webm")
    url = info.get("url", "")
    if not url:
        raise ValueError("No audio URL found in yt-dlp info")
    return url, info.get("ext", "m4a")
