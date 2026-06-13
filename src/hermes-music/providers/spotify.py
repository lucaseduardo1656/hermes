"""
Spotify provider — metadata + playlists via Web API (free tier OK).
Audio resolved via yt-dlp (Spotube approach): no Premium needed.
"""
import asyncio
from typing import Any

import spotipy
from spotipy.oauth2 import SpotifyOAuth

from auth import token_store
from config import settings

SCOPES = (
    "user-read-private "
    "user-library-read "
    "playlist-read-private "
    "user-top-read "
    "user-read-recently-played"
)

_sp: spotipy.Spotify | None = None


def _oauth_manager() -> SpotifyOAuth:
    return SpotifyOAuth(
        client_id=settings.spotify_client_id,
        client_secret=settings.spotify_client_secret,
        redirect_uri=settings.spotify_redirect_uri,
        scope=SCOPES,
        cache_handler=_DiskCacheHandler(),
        open_browser=False,
    )


class _DiskCacheHandler(spotipy.CacheHandler):
    """Bridge spotipy cache to our token store."""

    def get_cached_token(self):
        return token_store.get("spotify")

    def save_token_to_cache(self, token_info):
        token_store.put("spotify", token_info)


def get_auth_url() -> str:
    return _oauth_manager().get_authorize_url()


def handle_callback(code: str) -> None:
    mgr = _oauth_manager()
    token = mgr.get_access_token(code, as_dict=True, check_cache=False)
    token_store.put("spotify", token)
    global _sp
    _sp = spotipy.Spotify(auth_manager=mgr)


def is_connected() -> bool:
    return token_store.get("spotify") is not None


def _client() -> spotipy.Spotify:
    global _sp
    if _sp is None:
        mgr = _oauth_manager()
        _sp = spotipy.Spotify(auth_manager=mgr)
    return _sp


# ── Data helpers ──────────────────────────────────────────────────────────────

def _track_to_dict(item: dict) -> dict:
    t = item.get("track") or item  # handle playlist item wrapper
    if not t or t.get("is_local"):
        return {}
    artists = ", ".join(a["name"] for a in t.get("artists", []))
    album = t.get("album", {})
    images = album.get("images", [])
    return {
        "id":         f"spotify:{t['id']}",
        "source":     "spotify",
        "title":      t["name"],
        "artist":     artists,
        "album":      album.get("name", ""),
        "duration_ms": t.get("duration_ms", 0),
        "artwork":    images[0]["url"] if images else "",
        # kept for yt-dlp search query
        "_search":    f"{t['name']} {artists}",
    }


async def get_playlists() -> list[dict]:
    sp = _client()
    result = await asyncio.to_thread(lambda: sp.current_user_playlists(limit=50))
    playlists = []
    for p in result.get("items", []):
        if not p:
            continue
        images = p.get("images", [])
        playlists.append({
            "id":      f"spotify:playlist:{p['id']}",
            "source":  "spotify",
            "title":   p["name"],
            "count":   p["tracks"]["total"],
            "artwork": images[0]["url"] if images else "",
        })
    return playlists


async def get_playlist_tracks(playlist_id: str) -> list[dict]:
    """playlist_id: raw Spotify ID (without 'spotify:playlist:' prefix)."""
    sp = _client()
    tracks = []
    offset = 0
    while True:
        result = await asyncio.to_thread(
            lambda o=offset: sp.playlist_items(playlist_id, limit=100, offset=o)
        )
        for item in result.get("items", []):
            t = _track_to_dict(item)
            if t:
                tracks.append(t)
        if result.get("next") is None:
            break
        offset += 100
    return tracks


async def get_liked_tracks(limit: int = 50) -> list[dict]:
    sp = _client()
    result = await asyncio.to_thread(lambda: sp.current_user_saved_tracks(limit=limit))
    return [t for item in result.get("items", []) if (t := _track_to_dict(item))]


async def like_track(raw_id: str) -> None:
    sp = _client()
    await asyncio.to_thread(lambda: sp.current_user_saved_tracks_add([raw_id]))


async def unlike_track(raw_id: str) -> None:
    sp = _client()
    await asyncio.to_thread(lambda: sp.current_user_saved_tracks_delete([raw_id]))


async def is_liked(raw_id: str) -> bool:
    sp = _client()
    result = await asyncio.to_thread(lambda: sp.current_user_saved_tracks_contains([raw_id]))
    return bool(result and result[0])


async def get_top_tracks(limit: int = 30) -> list[dict]:
    sp = _client()
    result = await asyncio.to_thread(
        lambda: sp.current_user_top_tracks(limit=limit, time_range="medium_term")
    )
    return [t for item in result.get("items", []) if (t := _track_to_dict({"track": item}))]


async def get_recommendations(seed_tracks: list[str] | None = None, limit: int = 30) -> list[dict]:
    sp = _client()
    # Use top tracks as seeds if none provided
    if not seed_tracks:
        top = await asyncio.to_thread(
            lambda: sp.current_user_top_tracks(limit=5, time_range="short_term")
        )
        seed_tracks = [t["id"] for t in top.get("items", [])][:5]

    if not seed_tracks:
        return []

    result = await asyncio.to_thread(
        lambda: sp.recommendations(seed_tracks=seed_tracks[:5], limit=limit)
    )
    return [t for item in result.get("tracks", []) if (t := _track_to_dict({"track": item}))]


async def search(query: str, limit: int = 20) -> list[dict]:
    sp = _client()
    result = await asyncio.to_thread(
        lambda: sp.search(q=query, type="track", limit=limit)
    )
    return [
        t for item in result.get("tracks", {}).get("items", [])
        if (t := _track_to_dict({"track": item}))
    ]
