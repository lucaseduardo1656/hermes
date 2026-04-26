"""
REST API routes for hermes-music daemon.
Qt MusicBackend talks to these endpoints.
"""
from fastapi import APIRouter, HTTPException, Query, Request
from fastapi.responses import JSONResponse

from providers import spotify, ytmusic, soundcloud
from resolver import resolve
import downloader as dl
import history as hist
from config import settings

router = APIRouter()


# ── Status ────────────────────────────────────────────────────────────────────

@router.get("/status")
async def status():
    return {
        "ok": True,
        "sources": {
            "spotify":    spotify.is_connected(),
            "ytmusic":    ytmusic.is_connected(),
            "soundcloud": soundcloud.is_connected(),
        },
    }


# ── Auth: Spotify ─────────────────────────────────────────────────────────────

@router.get("/auth/spotify/start")
async def spotify_auth_start():
    """Returns the Spotify OAuth URL. Qt opens it (QDesktopServices or QR code)."""
    if not settings.spotify_client_id:
        raise HTTPException(400, "Spotify client_id not configured. Set in ~/.hermes-music/.env")
    return {"url": spotify.get_auth_url()}


@router.get("/auth/spotify/callback")
async def spotify_callback(code: str = Query(...), error: str = Query(None)):
    """Spotify redirects here after user grants permission."""
    if error:
        return JSONResponse({"error": error}, status_code=400)
    try:
        spotify.handle_callback(code)
    except Exception as e:
        raise HTTPException(500, str(e))
    # Return a nice page so the user's browser shows success
    return JSONResponse({"ok": True, "message": "Spotify connected! You can close this tab."})


@router.delete("/auth/spotify")
async def spotify_disconnect():
    from auth import token_store
    token_store.delete("spotify")
    return {"ok": True}


# ── Auth: YouTube Music ───────────────────────────────────────────────────────

@router.get("/auth/ytmusic/instructions")
async def ytmusic_instructions():
    """Returns setup instructions to display in Qt UI."""
    return ytmusic.get_auth_instructions()


@router.post("/auth/ytmusic/upload")
async def ytmusic_upload(request: Request):
    """
    Accept the OAuth JSON from ytmusicapi CLI.
    User pastes/uploads the file content; Qt sends it here.
    """
    body = await request.body()
    try:
        ytmusic.accept_oauth_json(body.decode())
    except Exception as e:
        raise HTTPException(400, f"Invalid OAuth JSON: {e}")
    return {"ok": True, "connected": ytmusic.is_connected()}


@router.get("/auth/ytmusic/status")
async def ytmusic_status():
    return {"connected": ytmusic.is_connected()}


# ── Playlists ─────────────────────────────────────────────────────────────────

@router.get("/playlists")
async def get_playlists(source: str = Query("all")):
    """
    Returns unified playlist list from all connected sources.
    source: 'all' | 'spotify' | 'ytmusic'
    """
    result = []
    errors = {}

    if source in ("all", "spotify") and spotify.is_connected():
        try:
            result.extend(await spotify.get_playlists())
        except Exception as e:
            errors["spotify"] = str(e)

    if source in ("all", "ytmusic") and ytmusic.is_connected():
        try:
            result.extend(await ytmusic.get_playlists())
        except Exception as e:
            errors["ytmusic"] = str(e)

    return {"playlists": result, "errors": errors}


@router.get("/playlists/{playlist_id}/tracks")
async def get_playlist_tracks(playlist_id: str):
    """
    playlist_id format: '{source}:playlist:{raw_id}'
    e.g. 'spotify:playlist:abc123' or 'ytmusic:playlist:PLxxx'
    """
    parts = playlist_id.split(":", 2)
    if len(parts) < 3:
        raise HTTPException(400, "Invalid playlist_id format")

    source, _, raw_id = parts

    if source == "spotify":
        tracks = await spotify.get_playlist_tracks(raw_id)
    elif source == "ytmusic":
        tracks = await ytmusic.get_playlist_tracks(raw_id)
    else:
        raise HTTPException(400, f"Unknown source: {source}")

    return {"tracks": tracks}


# ── Liked / Library ───────────────────────────────────────────────────────────

@router.get("/library/liked")
async def get_liked(source: str = Query("all"), limit: int = Query(50)):
    result = []
    errors = {}

    if source in ("all", "spotify") and spotify.is_connected():
        try:
            result.extend(await spotify.get_liked_tracks(limit))
        except Exception as e:
            errors["spotify"] = str(e)

    if source in ("all", "ytmusic") and ytmusic.is_connected():
        try:
            result.extend(await ytmusic.get_liked_songs(limit))
        except Exception as e:
            errors["ytmusic"] = str(e)

    return {"tracks": result, "errors": errors}


# ── Recommendations ───────────────────────────────────────────────────────────

@router.get("/recommendations")
async def get_recommendations():
    """Unified recommendations from all connected sources."""
    result = []
    errors = {}

    if spotify.is_connected():
        try:
            result.extend(await spotify.get_recommendations())
        except Exception as e:
            errors["spotify"] = str(e)

    if ytmusic.is_connected():
        try:
            result.extend(await ytmusic.get_recommendations())
        except Exception as e:
            errors["ytmusic"] = str(e)

    # Interleave sources for variety
    from itertools import zip_longest
    spotify_tracks = [t for t in result if t["source"] == "spotify"]
    yt_tracks      = [t for t in result if t["source"] == "ytmusic"]
    mixed = []
    for a, b in zip_longest(spotify_tracks, yt_tracks):
        if a: mixed.append(a)
        if b: mixed.append(b)

    return {"tracks": mixed, "errors": errors}


# ── Top Tracks ────────────────────────────────────────────────────────────────

@router.get("/top-tracks")
async def get_top_tracks(limit: int = Query(30)):
    result = []
    errors = {}

    if spotify.is_connected():
        try:
            result.extend(await spotify.get_top_tracks(limit))
        except Exception as e:
            errors["spotify"] = str(e)

    return {"tracks": result, "errors": errors}


# ── Search ────────────────────────────────────────────────────────────────────

@router.get("/search")
async def search(q: str = Query(...), source: str = Query("all"), limit: int = Query(20)):
    result = []
    errors = {}

    if source in ("all", "spotify") and spotify.is_connected():
        try:
            result.extend(await spotify.search(q, limit))
        except Exception as e:
            errors["spotify"] = str(e)

    if source in ("all", "ytmusic"):
        try:
            result.extend(await ytmusic.search(q, limit))
        except Exception as e:
            errors["ytmusic"] = str(e)

    if source in ("all", "soundcloud"):
        try:
            result.extend(await soundcloud.search(q, limit // 2))
        except Exception as e:
            errors["soundcloud"] = str(e)

    return {"tracks": result, "errors": errors}


# ── SoundCloud ────────────────────────────────────────────────────────────────

@router.get("/soundcloud/user")
async def sc_user_tracks(url: str = Query(...)):
    tracks = await soundcloud.get_user_tracks(url)
    return {"tracks": tracks}


@router.get("/soundcloud/playlist")
async def sc_playlist(url: str = Query(...)):
    tracks = await soundcloud.get_playlist(url)
    return {"tracks": tracks}


# ── Home page ────────────────────────────────────────────────────────────────

@router.get("/home")
async def home():
    """
    Unified home page for the Qt MusicView.
    Returns sections: recents, playlists, recommendations, top tracks.
    All providers merged — UI doesn't need to know the source.
    Sections with no data are omitted so Qt renders only what's available.
    """
    import asyncio

    # Fire all requests in parallel
    tasks = {
        "recents":         asyncio.create_task(_safe(lambda: hist.recent(10))),
        "playlists":       asyncio.create_task(_safe(_all_playlists)),
        "recommendations": asyncio.create_task(_safe(_all_recommendations)),
        "top_tracks":      asyncio.create_task(_safe(_top_tracks)),
        "liked":           asyncio.create_task(_safe(_all_liked)),
    }

    results = {k: await v for k, v in tasks.items()}

    sections = []

    if results["recents"]:
        sections.append({"id": "recents", "title": "Tocadas recentemente",
                         "type": "tracks", "items": results["recents"]})

    if results["playlists"]:
        sections.append({"id": "playlists", "title": "Suas playlists",
                         "type": "playlists", "items": results["playlists"]})

    if results["recommendations"]:
        sections.append({"id": "recommendations", "title": "Recomendado pra você",
                         "type": "tracks", "items": results["recommendations"]})

    if results["top_tracks"]:
        sections.append({"id": "top_tracks", "title": "Suas mais tocadas",
                         "type": "tracks", "items": results["top_tracks"]})

    if results["liked"]:
        sections.append({"id": "liked", "title": "Músicas curtidas",
                         "type": "tracks", "items": results["liked"]})

    return {"sections": sections}


async def _safe(fn):
    """Run fn, return [] on any error (home page must never fail)."""
    try:
        result = fn()
        if hasattr(result, "__await__") or hasattr(result, "cr_frame"):
            return await result
        return result
    except Exception:
        return []


async def _all_playlists() -> list[dict]:
    import asyncio
    results = await asyncio.gather(
        spotify.get_playlists()  if spotify.is_connected()  else _empty(),
        ytmusic.get_playlists()  if ytmusic.is_connected()  else _empty(),
        return_exceptions=True,
    )
    out = []
    for r in results:
        if isinstance(r, list):
            out.extend(r)
    return out


async def _all_recommendations() -> list[dict]:
    import asyncio
    from itertools import zip_longest
    results = await asyncio.gather(
        spotify.get_recommendations() if spotify.is_connected() else _empty(),
        ytmusic.get_recommendations() if ytmusic.is_connected() else _empty(),
        return_exceptions=True,
    )
    sp = results[0] if isinstance(results[0], list) else []
    yt = results[1] if isinstance(results[1], list) else []
    mixed = []
    for a, b in zip_longest(sp, yt):
        if a: mixed.append(a)
        if b: mixed.append(b)
    return mixed[:30]


async def _top_tracks() -> list[dict]:
    if not spotify.is_connected():
        return []
    return await spotify.get_top_tracks(limit=20)


async def _all_liked() -> list[dict]:
    import asyncio
    results = await asyncio.gather(
        spotify.get_liked_tracks(20) if spotify.is_connected() else _empty(),
        ytmusic.get_liked_songs(20)  if ytmusic.is_connected()  else _empty(),
        return_exceptions=True,
    )
    out = []
    for r in results:
        if isinstance(r, list):
            out.extend(r)
    return out


async def _empty() -> list:
    return []


# ── Play history (Qt calls this when a track starts) ─────────────────────────

@router.post("/played")
async def mark_played(request: Request):
    """
    Qt calls this when a track starts playing.
    Persists to local history for 'Recently played' section.
    """
    try:
        track = await request.json()
    except Exception:
        raise HTTPException(400, "Body must be a JSON track object")
    if not isinstance(track, dict) or not track.get("id"):
        raise HTTPException(400, "track.id required")
    hist.record(track)
    return {"ok": True}


@router.get("/played")
async def get_history(limit: int = Query(20)):
    return {"tracks": hist.recent(limit)}


# ── Stream URL resolution (the core of Spotube approach) ─────────────────────

@router.post("/resolve")
async def resolve_track(request: Request):
    """
    Body: track dict (as returned by /playlists, /search, etc.)
    Returns: {url, ext, local, expires_at}
    Qt passes url to QMediaPlayer directly. 'local' = True means offline file.
    """
    track = await request.json()
    if not track.get("id"):
        raise HTTPException(400, "track.id required")
    try:
        result = await resolve(track)
    except ValueError as e:
        raise HTTPException(404, str(e))
    except Exception as e:
        raise HTTPException(500, str(e))
    return result


# ── Downloads (offline library) ───────────────────────────────────────────────

@router.post("/downloads")
async def enqueue_download(request: Request):
    """Enqueue track for offline download. Idempotent."""
    try:
        track = await request.json()
    except Exception:
        raise HTTPException(400, "Body must be a JSON track object")
    if not isinstance(track, dict) or not track.get("id"):
        raise HTTPException(400, "track.id required")
    item = await dl.enqueue(track)
    return {
        "track_id": item.track_id,
        "state":    item.state,
    }


@router.get("/downloads")
async def list_downloads():
    """List all downloads with state and progress."""
    return {"downloads": dl.list_downloads()}


@router.get("/downloads/library")
async def offline_library():
    """Only completed downloads — offline playback library."""
    return {"tracks": dl.list_completed()}


@router.delete("/downloads/{track_id:path}")
async def delete_download(track_id: str):
    found = dl.delete_download(track_id)
    if not found:
        raise HTTPException(404, "Download not found")
    return {"ok": True}
