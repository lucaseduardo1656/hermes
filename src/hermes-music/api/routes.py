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


@router.post("/library/like")
async def like_track(request: Request):
    track = await request.json()
    track_id: str = track.get("id", "")
    try:
        if track_id.startswith("spotify:") and spotify.is_connected():
            await spotify.like_track(track_id.split(":", 1)[1])
        elif track_id.startswith("ytmusic:") and ytmusic.is_connected():
            await ytmusic.like_track(track_id.split(":", 1)[1])
    except Exception as e:
        raise HTTPException(500, str(e))
    return {"ok": True}


@router.post("/library/unlike")
async def unlike_track(request: Request):
    track = await request.json()
    track_id: str = track.get("id", "")
    try:
        if track_id.startswith("spotify:") and spotify.is_connected():
            await spotify.unlike_track(track_id.split(":", 1)[1])
        elif track_id.startswith("ytmusic:") and ytmusic.is_connected():
            await ytmusic.unlike_track(track_id.split(":", 1)[1])
    except Exception as e:
        raise HTTPException(500, str(e))
    return {"ok": True}


@router.get("/library/liked/check")
async def check_liked(id: str = Query(...)):
    """Returns {"liked": bool} for the given track id (e.g. "spotify:abc")."""
    try:
        if id.startswith("spotify:") and spotify.is_connected():
            liked = await spotify.is_liked(id.split(":", 1)[1])
            return {"liked": liked}
        if id.startswith("ytmusic:") and ytmusic.is_connected():
            liked = await ytmusic.is_liked(id.split(":", 1)[1])
            return {"liked": liked}
    except Exception:
        pass
    return {"liked": False}


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

# Home feed cache.
#
# `sections` is grown lazily for infinite scroll: initial fill loads
# recents + charts + YT Music's home rows. Once the client paginates past
# what's there, we extend the list one mood-category section at a time
# (Chill, Energize, Party, Sad, …) until YT Music's mood catalog is
# exhausted. Each section is a real upstream feed, never a hardcoded
# title or track list.
_HOME_CACHE: dict = {
    "sections":      [],
    "fetched_at":    0.0,
    "moods":         None,   # list[{title, params}] — None until loaded
    "moods_cursor":  0,      # next mood index to expand into a section
}
_HOME_TTL_SECS = 600   # 10 min


async def _build_home_sections() -> list[dict]:
    import asyncio
    tasks = {
        "recents":         asyncio.create_task(_safe(lambda: hist.recent(10))),
        "charts":          asyncio.create_task(_safe(lambda: ytmusic.get_charts_tracks("BR", 20))),
        "yt_sections":     asyncio.create_task(_safe(lambda: ytmusic.get_home_sections(12))),
        "playlists":       asyncio.create_task(_safe(_all_playlists)),
        "recommendations": asyncio.create_task(_safe(_all_recommendations)),
        "top_tracks":      asyncio.create_task(_safe(_top_tracks)),
        "liked":           asyncio.create_task(_safe(_all_liked)),
    }
    results = {k: await v for k, v in tasks.items()}

    out: list[dict] = []
    if results["recents"]:
        out.append({"id": "recents", "title": "Tocadas recentemente",
                    "type": "tracks", "items": results["recents"]})
    if results["charts"]:
        out.append({"id": "charts", "title": "Em alta no Brasil",
                    "type": "tracks", "items": results["charts"]})
    # Pass YT Music's home rows through verbatim.
    for i, s in enumerate(results["yt_sections"] or []):
        out.append({
            "id":    f"yt_{i}",
            "title": s.get("title") or "Pra você",
            "type":  "tracks",
            "items": s.get("items") or [],
        })
    if results["playlists"]:
        out.append({"id": "playlists", "title": "Suas playlists",
                    "type": "playlists", "items": results["playlists"]})
    if results["recommendations"]:
        out.append({"id": "recommendations", "title": "Recomendado pra você",
                    "type": "tracks", "items": results["recommendations"]})
    if results["top_tracks"]:
        out.append({"id": "top_tracks", "title": "Suas mais tocadas",
                    "type": "tracks", "items": results["top_tracks"]})
    if results["liked"]:
        out.append({"id": "liked", "title": "Músicas curtidas",
                    "type": "tracks", "items": results["liked"]})
    return out


async def _extend_home_with_mood() -> bool:
    """
    Append one more section to `_HOME_CACHE` by expanding the next mood
    category from YT Music. Returns True if a section was added, False
    once the mood catalog is exhausted.
    """
    if _HOME_CACHE["moods"] is None:
        _HOME_CACHE["moods"] = await _safe(ytmusic.get_mood_catalog) or []
    moods   = _HOME_CACHE["moods"]
    cursor  = _HOME_CACHE["moods_cursor"]
    if cursor >= len(moods):
        return False

    mood   = moods[cursor]
    _HOME_CACHE["moods_cursor"] = cursor + 1
    tracks = await _safe(lambda: ytmusic.get_mood_section(mood["params"], 12)) or []
    if not tracks:
        return await _extend_home_with_mood()   # skip empty, try next

    _HOME_CACHE["sections"].append({
        "id":    f"mood_{cursor}",
        "title": mood["title"],
        "type":  "tracks",
        "items": tracks,
    })
    return True


@router.get("/home")
async def home(offset: int = 0, limit: int = 4):
    """
    Paginated home feed for infinite scroll. Initial pages serve cached
    YT Music home rows + charts + history; further pages grow the cache
    on-demand by expanding mood categories. The whole cache is rebuilt
    after `_HOME_TTL_SECS`.
    """
    import time
    now = time.time()

    # Cold start or cache expired — rebuild from scratch.
    # If the build returns nothing, or only the local "recents" section
    # (network/TLS not ready yet at boot, YT Music calls all failed),
    # we deliberately leave `fetched_at` at zero so the next request
    # retries instead of caching the degraded result for the TTL.
    if not _HOME_CACHE["sections"] or (now - _HOME_CACHE["fetched_at"]) > _HOME_TTL_SECS:
        built = await _build_home_sections()
        non_local = [s for s in built if s["id"] != "recents"]
        if non_local:
            _HOME_CACHE["sections"]     = built
            _HOME_CACHE["fetched_at"]   = now
            _HOME_CACHE["moods"]        = None
            _HOME_CACHE["moods_cursor"] = 0
        elif built and not _HOME_CACHE["sections"]:
            # Serve recents-only this request without poisoning the cache.
            return {"sections": built, "offset": 0, "limit": limit,
                    "total": len(built), "has_more": False}

    offset = max(0, offset)
    limit  = max(1, min(limit, 50))

    # Lazily extend until we can satisfy `offset + limit`, or until the
    # mood catalog runs out (whichever comes first).
    while len(_HOME_CACHE["sections"]) < offset + limit:
        if not await _extend_home_with_mood():
            break

    cached = _HOME_CACHE["sections"]
    total  = len(cached)
    slice_ = cached[offset:offset + limit]

    # has_more = either we still have unread cached sections, or the
    # mood catalog still has unconsumed entries we can lazy-load next.
    cursor_left = (_HOME_CACHE["moods"] is not None
                   and _HOME_CACHE["moods_cursor"] < len(_HOME_CACHE["moods"] or []))
    return {
        "sections": slice_,
        "offset":   offset,
        "limit":    limit,
        "total":    total,
        "has_more": (offset + limit < total) or cursor_left,
    }


async def warm_home_cache(initial_delay: float = 2.0,
                          retry_delay:   float = 15.0) -> None:
    """
    Background task: keep rebuilding the home feed until it actually
    contains YT Music data (not just local recents). Once that lands,
    swap it into `_HOME_CACHE` atomically. Subsequent /home requests
    then serve a healthy cache from the very first call.
    """
    import asyncio
    import time
    await asyncio.sleep(initial_delay)
    while True:
        try:
            built = await _build_home_sections()
            non_local = [s for s in built if s["id"] != "recents"]
            if non_local:
                _HOME_CACHE["sections"]     = built
                _HOME_CACHE["fetched_at"]   = time.time()
                _HOME_CACHE["moods"]        = None
                _HOME_CACHE["moods_cursor"] = 0
                return
        except Exception:
            pass
        await asyncio.sleep(retry_delay)


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
