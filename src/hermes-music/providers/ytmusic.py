"""
YouTube Music provider via ytmusicapi.
Auth: browser-based OAuth (Google account). Token persisted to disk.
Audio: yt-dlp (native, same video IDs).
"""
import asyncio
from pathlib import Path

from ytmusicapi import YTMusic

from auth import token_store
from config import DATA_DIR

_OAUTH_FILE = DATA_DIR / "ytmusic_oauth.json"
_yt: YTMusic | None = None


def is_connected() -> bool:
    return _OAUTH_FILE.exists()


def get_auth_instructions() -> dict:
    """
    ytmusicapi uses a one-time browser setup. We return instructions so the
    Qt UI can display them; user runs the setup CLI once via SSH or terminal.
    For a future improvement this can be automated via Google OAuth PKCE flow.
    """
    return {
        "method": "cli_setup",
        "instructions": (
            "Run on the Raspberry Pi:\n"
            "  ytmusicapi oauth\n"
            f"Then copy the generated file to: {_OAUTH_FILE}\n"
            "Or run: ytmusicapi browser  (paste request headers from browser)"
        ),
    }


def _client() -> YTMusic:
    global _yt
    if _yt is None:
        if _OAUTH_FILE.exists():
            _yt = YTMusic(str(_OAUTH_FILE))
        else:
            _yt = YTMusic()  # unauthenticated — public content only
    return _yt


def _reload_client() -> None:
    global _yt
    _yt = None


def accept_oauth_json(json_str: str) -> None:
    """Called by API when user uploads/pastes the OAuth JSON from ytmusicapi CLI."""
    _OAUTH_FILE.write_text(json_str)
    _OAUTH_FILE.chmod(0o600)
    _reload_client()


# ── Data helpers ──────────────────────────────────────────────────────────────

def _song_to_dict(item: dict, source_context: str = "") -> dict:
    vid = item.get("videoId") or item.get("video_id", "")
    if not vid:
        return {}
    artists = item.get("artists") or []
    artist_str = ", ".join(a.get("name", "") for a in artists) if isinstance(artists, list) else str(artists)
    thumbnails = item.get("thumbnails") or []
    artwork = thumbnails[-1]["url"] if thumbnails else ""
    album = item.get("album") or {}
    return {
        "id":          f"ytmusic:{vid}",
        "source":      "ytmusic",
        "title":       item.get("title", ""),
        "artist":      artist_str,
        "album":       album.get("name", "") if isinstance(album, dict) else "",
        "duration_ms": (item.get("duration_seconds") or 0) * 1000,
        "artwork":     artwork,
        # yt-dlp uses video ID directly — no search needed
        "_yt_id":      vid,
    }


async def get_playlists() -> list[dict]:
    yt = _client()
    result = await asyncio.to_thread(lambda: yt.get_library_playlists(limit=50))
    playlists = []
    for p in result or []:
        thumbnails = p.get("thumbnails") or []
        playlists.append({
            "id":      f"ytmusic:playlist:{p['playlistId']}",
            "source":  "ytmusic",
            "title":   p.get("title", ""),
            "count":   p.get("count", 0),
            "artwork": thumbnails[-1]["url"] if thumbnails else "",
        })
    return playlists


async def get_playlist_tracks(playlist_id: str) -> list[dict]:
    yt = _client()
    result = await asyncio.to_thread(lambda: yt.get_playlist(playlist_id, limit=None))
    tracks = result.get("tracks") or []
    return [t for item in tracks if (t := _song_to_dict(item))]


async def get_liked_songs(limit: int = 100) -> list[dict]:
    yt = _client()
    result = await asyncio.to_thread(lambda: yt.get_liked_songs(limit=limit))
    tracks = result.get("tracks") or []
    return [t for item in tracks if (t := _song_to_dict(item))]


async def get_recommendations() -> list[dict]:
    yt = _client()
    result = await asyncio.to_thread(lambda: yt.get_home(limit=3))
    tracks = []
    for section in result or []:
        for item in section.get("contents", []):
            t = _song_to_dict(item)
            if t:
                tracks.append(t)
    return tracks[:50]


async def search(query: str, limit: int = 20) -> list[dict]:
    yt = _client()
    result = await asyncio.to_thread(lambda: yt.search(query, filter="songs", limit=limit))
    return [t for item in (result or []) if (t := _song_to_dict(item))]
