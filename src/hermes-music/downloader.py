"""
Download manager: queue tracks for offline playback.
Uses yt-dlp to download audio. Persists metadata alongside the file.
"""
import asyncio
import json
import time
from enum import Enum
from pathlib import Path
from typing import Callable

import yt_dlp

from config import DATA_DIR, settings
from resolver import DOWNLOADS_DIR, _COOKIES_FILE, _best_audio_url

_META_DIR = DATA_DIR / "downloads_meta"
_META_DIR.mkdir(exist_ok=True)


class DownloadState(str, Enum):
    queued     = "queued"
    downloading = "downloading"
    done       = "done"
    failed     = "failed"


class DownloadItem:
    def __init__(self, track: dict):
        self.track    = track
        self.track_id = track["id"]
        self.state    = DownloadState.queued
        self.progress = 0.0   # 0.0 – 1.0
        self.error    = ""
        self.file_path: Path | None = None
        self.queued_at = time.time()


# Global queue and active downloads map
_queue: asyncio.Queue[DownloadItem] = asyncio.Queue()
_items: dict[str, DownloadItem] = {}          # track_id → item
_progress_callbacks: list[Callable] = []


def subscribe(cb: Callable[[DownloadItem], None]) -> None:
    """Register callback for progress updates (called from worker thread)."""
    _progress_callbacks.append(cb)


def _notify(item: DownloadItem) -> None:
    for cb in _progress_callbacks:
        try:
            cb(item)
        except Exception:
            pass


def _safe_filename(track_id: str) -> str:
    return track_id.replace(":", "_").replace("/", "_")


def _ydl_download_opts(out_template: str, progress_hook) -> dict:
    opts: dict = {
        "quiet": True,
        "no_warnings": True,
        "format": settings.audio_format,
        "outtmpl": out_template,
        "progress_hooks": [progress_hook],
        "postprocessors": [{
            "key": "FFmpegExtractAudio",
            "preferredcodec": "m4a",
            "preferredquality": "0",
        }],
    }
    if _COOKIES_FILE.exists():
        opts["cookiefile"] = str(_COOKIES_FILE)
    else:
        opts["cookiesfrombrowser"] = ("firefox",)
    return opts


async def enqueue(track: dict) -> DownloadItem:
    """Add track to download queue. Idempotent — ignores if already queued/done."""
    tid = track["id"]
    if tid in _items:
        return _items[tid]

    item = DownloadItem(track)
    _items[tid] = item
    await _queue.put(item)
    _notify(item)
    return item


def list_downloads() -> list[dict]:
    """Return all download items as serialisable dicts."""
    result = []
    for item in _items.values():
        result.append({
            "track_id":  item.track_id,
            "title":     item.track.get("title", ""),
            "artist":    item.track.get("artist", ""),
            "artwork":   item.track.get("artwork", ""),
            "state":     item.state,
            "progress":  round(item.progress, 3),
            "error":     item.error,
            "file_path": str(item.file_path) if item.file_path else None,
        })
    return result


def list_completed() -> list[dict]:
    """Only completed downloads — used to build offline library."""
    return [d for d in list_downloads() if d["state"] == DownloadState.done]


def delete_download(track_id: str) -> bool:
    """Remove downloaded file and metadata. Returns True if found."""
    item = _items.pop(track_id, None)
    if item and item.file_path and item.file_path.exists():
        item.file_path.unlink()
    meta = _META_DIR / f"{_safe_filename(track_id)}.json"
    if meta.exists():
        meta.unlink()
    return item is not None


def _load_persisted() -> None:
    """Restore completed downloads from disk on startup."""
    for meta_file in _META_DIR.glob("*.json"):
        try:
            data = json.loads(meta_file.read_text())
            tid = data["track_id"]
            if tid in _items:
                continue
            fp = Path(data.get("file_path", ""))
            if not fp.exists():
                meta_file.unlink()
                continue
            item = DownloadItem(data["track"])
            item.state     = DownloadState.done
            item.progress  = 1.0
            item.file_path = fp
            _items[tid]    = item
        except Exception:
            pass


async def run_worker() -> None:
    """
    Long-running coroutine — start with asyncio.create_task() at startup.
    Processes one download at a time to avoid hammering the network.
    """
    _load_persisted()
    while True:
        item = await _queue.get()
        try:
            await _download(item)
        except Exception as e:
            item.state = DownloadState.failed
            item.error = str(e)
            _notify(item)
        finally:
            _queue.task_done()


async def _download(item: DownloadItem) -> None:
    item.state = DownloadState.downloading
    _notify(item)

    tid      = item.track_id
    track    = item.track
    out_stem = _safe_filename(tid)
    out_tmpl = str(DOWNLOADS_DIR / f"{out_stem}.%(ext)s")

    # Determine source URL / search query
    source = track.get("source", "")
    if source == "ytmusic" and track.get("_yt_id"):
        fetch_url = f"https://music.youtube.com/watch?v={track['_yt_id']}"
    elif source == "soundcloud" and track.get("_sc_url"):
        fetch_url = track["_sc_url"]
    elif track.get("_search"):
        fetch_url = f"ytsearch1:{track['_search']} audio"
    else:
        raise ValueError(f"No resolvable URL for {tid}")

    def _progress_hook(d: dict) -> None:
        if d.get("status") == "downloading":
            total   = d.get("total_bytes") or d.get("total_bytes_estimate") or 0
            current = d.get("downloaded_bytes", 0)
            item.progress = (current / total) if total else 0.0
            _notify(item)

    def _run() -> Path:
        opts = _ydl_download_opts(out_tmpl, _progress_hook)
        opts["skip_download"] = False   # actually download this time
        with yt_dlp.YoutubeDL(opts) as ydl:
            ydl.download([fetch_url])
        # FFmpegExtractAudio renames to .m4a
        p = DOWNLOADS_DIR / f"{out_stem}.m4a"
        if not p.exists():
            # Find whatever yt-dlp created
            matches = list(DOWNLOADS_DIR.glob(f"{out_stem}.*"))
            if not matches:
                raise FileNotFoundError(f"Download produced no file for {tid}")
            p = matches[0]
        return p

    file_path = await asyncio.to_thread(_run)

    item.state     = DownloadState.done
    item.progress  = 1.0
    item.file_path = file_path
    _notify(item)

    # Persist metadata so we survive restarts
    meta = {
        "track_id":  tid,
        "track":     track,
        "file_path": str(file_path),
    }
    (_META_DIR / f"{out_stem}.json").write_text(json.dumps(meta, indent=2))
