from pydantic_settings import BaseSettings
from pathlib import Path

DATA_DIR = Path.home() / ".hermes-music"
DATA_DIR.mkdir(exist_ok=True)


class Settings(BaseSettings):
    host: str = "127.0.0.1"
    port: int = 8765

    # Spotify — register app at developer.spotify.com (free)
    spotify_client_id: str = ""
    spotify_client_secret: str = ""
    # redirect must match what's registered in Spotify dashboard
    spotify_redirect_uri: str = "http://localhost:8765/auth/spotify/callback"

    # YouTube Music — no client creds needed, uses Google OAuth
    # SoundCloud — public content works without auth via yt-dlp

    # yt-dlp audio quality preference
    audio_format: str = "bestaudio[ext=m4a]/bestaudio/best"
    audio_codec: str = "m4a"          # m4a plays natively in Qt QMediaPlayer

    # cache TTL seconds
    playlist_cache_ttl: int = 300
    stream_url_cache_ttl: int = 3600  # stream URLs expire ~6h on YT, cache 1h to be safe

    class Config:
        env_file = DATA_DIR / ".env"
        env_file_encoding = "utf-8"


settings = Settings()
