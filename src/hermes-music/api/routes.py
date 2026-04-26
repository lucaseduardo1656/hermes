"""
REST API routes for hermes-music daemon.
Qt MusicBackend talks to these endpoints.
"""
from fastapi import APIRouter, HTTPException, Query, Request
from fastapi.responses import JSONResponse

from providers import spotify, ytmusic, soundcloud
from resolver import resolve
import downloader as dl
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
    track = await request.json()
    if not track.get("id"):
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
