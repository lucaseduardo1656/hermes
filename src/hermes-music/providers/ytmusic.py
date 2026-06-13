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


async def like_track(video_id: str) -> None:
    yt = _client()
    await asyncio.to_thread(lambda: yt.rate_song(video_id, "LIKE"))


async def unlike_track(video_id: str) -> None:
    yt = _client()
    await asyncio.to_thread(lambda: yt.rate_song(video_id, "INDIFFERENT"))


async def is_liked(video_id: str) -> bool:
    yt = _client()
    result = await asyncio.to_thread(lambda: yt.get_song(video_id))
    return result.get("videoDetails", {}).get("rating") == "LIKE"


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


async def get_mood_catalog() -> list[dict]:
    """
    Flattened list of YT Music's mood/genre categories. Each entry is
    `{title, params}` where `params` is the token used by
    get_mood_playlists. Works unauthenticated.
    """
    yt = _client()
    cats = await asyncio.to_thread(yt.get_mood_categories) or {}
    out: list[dict] = []
    for moods in cats.values():
        for m in moods:
            if m.get("params") and m.get("title"):
                out.append({"title": m["title"], "params": m["params"]})
    return out


async def get_mood_section(params: str, per_section: int = 12) -> list[dict]:
    """
    Expand a mood category into a flat list of tracks by pulling the top
    playlists for that mood and merging their tracks.
    """
    yt = _client()
    playlists = await asyncio.to_thread(lambda: yt.get_mood_playlists(params)) or []
    seen: set[str] = set()
    tracks: list[dict] = []
    for pl in playlists[:3]:
        if len(tracks) >= per_section:
            break
        pid = pl.get("playlistId")
        if not pid:
            continue
        try:
            data = await asyncio.to_thread(
                lambda p=pid: yt.get_playlist(p, limit=per_section))
        except Exception:
            continue
        for it in (data.get("tracks") or [])[:per_section]:
            t = _song_to_dict(it)
            if not t or t["_yt_id"] in seen:
                continue
            seen.add(t["_yt_id"])
            tracks.append(t)
            if len(tracks) >= per_section:
                break
    return tracks


async def get_charts_tracks(country: str = "BR", limit: int = 20) -> list[dict]:
    """
    Top songs chart for `country`. Works without authentication.

    YT Music's public charts response doesn't include a flat song list for
    unauth callers — it returns trending *playlists* (e.g. "Trending 20
    Brazil"). We pick the first one and expand it into track dicts.
    """
    yt = _client()
    charts = await asyncio.to_thread(lambda: yt.get_charts(country=country))
    videos = (charts or {}).get("videos") or []
    if not videos:
        return []
    playlist_id = videos[0].get("playlistId")
    if not playlist_id:
        return []
    pl = await asyncio.to_thread(
        lambda: yt.get_playlist(playlist_id, limit=limit))
    items = pl.get("tracks") or []
    return [t for it in items if (t := _song_to_dict(it))][:limit]


async def get_home_sections(per_section: int = 12) -> list[dict]:
    """
    Return YT Music's home feed split into multiple sections, mirroring
    the app's home screen ("Hits de hoje", "Quick picks", "Calm tunes",
    etc.). Each section is converted into a flat list of tracks: direct
    song entries pass through, playlist entries are expanded a few
    tracks each.

    Shape: [{ "title": str, "items": [track, ...] }, ...]
    """
    yt = _client()
    raw = await asyncio.to_thread(lambda: yt.get_home(limit=8))
    sections: list[dict] = []
    for s in raw or []:
        title = s.get("title") or ""
        tracks: list[dict] = []
        seen: set[str] = set()

        direct_items   = []
        playlist_items = []
        for item in s.get("contents", []):
            if item.get("videoId"):
                direct_items.append(item)
            elif item.get("playlistId"):
                playlist_items.append(item)

        for item in direct_items:
            t = _song_to_dict(item)
            if t and t["_yt_id"] not in seen:
                seen.add(t["_yt_id"])
                tracks.append(t)
            if len(tracks) >= per_section:
                break

        # Fall back to expanding playlists when the section had none /
        # not enough direct songs. Pulls a handful per playlist.
        for item in playlist_items:
            if len(tracks) >= per_section:
                break
            try:
                pl = await asyncio.to_thread(
                    lambda p=item["playlistId"]: yt.get_playlist(p, limit=6))
            except Exception:
                continue
            for it in (pl.get("tracks") or [])[:6]:
                t = _song_to_dict(it)
                if not t or t["_yt_id"] in seen:
                    continue
                seen.add(t["_yt_id"])
                tracks.append(t)
                if len(tracks) >= per_section:
                    break

        if tracks:
            sections.append({"title": title, "items": tracks})
    return sections


async def search(query: str, limit: int = 20) -> list[dict]:
    yt = _client()
    result = await asyncio.to_thread(lambda: yt.search(query, filter="songs", limit=limit))
    return [t for item in (result or []) if (t := _song_to_dict(item))]
