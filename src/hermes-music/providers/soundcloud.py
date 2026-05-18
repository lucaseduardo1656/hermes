"""
SoundCloud provider.
Public tracks/playlists: yt-dlp handles SC natively (no auth needed).
Liked tracks / private playlists: SC OAuth (client_id from app registration).
For most users, public content + yt-dlp is sufficient.
"""
import asyncio
import re

import yt_dlp

_SC_BASE = "https://soundcloud.com"


def is_connected() -> bool:
    # SoundCloud public content works without auth
    return True


def _ydl_opts(extract_flat: bool = True) -> dict:
    return {
        "quiet": True,
        "no_warnings": True,
        "extract_flat": extract_flat,
        "skip_download": True,
    }


def _item_to_dict(entry: dict) -> dict:
    vid = entry.get("id") or ""
    # webpage_url is the canonical SC track page; url may be an internal API URL
    sc_url = entry.get("webpage_url") or entry.get("url", "")
    thumbnails = entry.get("thumbnails") or []
    artwork = thumbnails[-1].get("url", "") if thumbnails else entry.get("thumbnail", "")
    return {
        "id":          f"soundcloud:{vid}",
        "source":      "soundcloud",
        "title":       entry.get("title", ""),
        "artist":      entry.get("uploader", ""),
        "album":       "",
        "duration_ms": int((entry.get("duration") or 0) * 1000),
        "artwork":     artwork,
        "_sc_url":     sc_url,
    }


async def get_user_tracks(profile_url: str) -> list[dict]:
    """Fetch public tracks from a SoundCloud user URL."""
    url = f"{profile_url}/tracks"

    def _fetch():
        with yt_dlp.YoutubeDL(_ydl_opts(extract_flat=True)) as ydl:
            info = ydl.extract_info(url, download=False)
            return info.get("entries", []) if info else []

    entries = await asyncio.to_thread(_fetch)
    return [t for e in entries if e and (t := _item_to_dict(e))]


async def get_playlist(playlist_url: str) -> list[dict]:
    """Fetch tracks from any public SoundCloud playlist/set URL."""
    def _fetch():
        with yt_dlp.YoutubeDL(_ydl_opts(extract_flat=True)) as ydl:
            info = ydl.extract_info(playlist_url, download=False)
            return info.get("entries", []) if info else []

    entries = await asyncio.to_thread(_fetch)
    return [t for e in entries if e and (t := _item_to_dict(e))]


async def search(query: str, limit: int = 20) -> list[dict]:
    search_url = f"scsearch{limit}:{query}"

    def _fetch():
        with yt_dlp.YoutubeDL(_ydl_opts(extract_flat=True)) as ydl:
            info = ydl.extract_info(search_url, download=False)
            return info.get("entries", []) if info else []

    entries = await asyncio.to_thread(_fetch)
    return [t for e in entries if e and (t := _item_to_dict(e))]
