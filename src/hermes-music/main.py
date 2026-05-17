"""hermes-music daemon entry point."""
import asyncio
import logging
import signal
from contextlib import asynccontextmanager

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.routes import router
from config import settings

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
log = logging.getLogger("hermes-music")


@asynccontextmanager
async def lifespan(app: FastAPI):
    log.info("hermes-music started on %s:%d", settings.host, settings.port)
    from auth import token_store
    import downloader as dl
    connected = token_store.connected_providers()
    if connected:
        log.info("Connected providers: %s", ", ".join(connected))
    else:
        log.info("No providers connected yet.")
    # Start download worker as background task
    worker_task = asyncio.create_task(dl.run_worker())
    log.info("Download worker started")
    # Warm the home cache in the background — keeps retrying until at
    # least one upstream YT Music section lands, so /home never serves
    # a degraded recents-only payload that would then sit in cache for
    # the TTL.
    from api.routes import warm_home_cache
    warmer_task = asyncio.create_task(warm_home_cache())
    log.info("Home cache warmer started")
    yield
    for t in (worker_task, warmer_task):
        t.cancel()
    for t in (worker_task, warmer_task):
        try:
            await t
        except asyncio.CancelledError:
            pass


app = FastAPI(title="hermes-music", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router)


def main():
    config = uvicorn.Config(
        app,
        host=settings.host,
        port=settings.port,
        log_level="info",
        loop="asyncio",
    )
    server = uvicorn.Server(config)

    # Graceful shutdown on SIGTERM (systemd)
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    def _handle_signal():
        log.info("Shutting down hermes-music...")
        loop.create_task(server.shutdown())

    loop.add_signal_handler(signal.SIGTERM, _handle_signal)
    loop.add_signal_handler(signal.SIGINT,  _handle_signal)

    try:
        loop.run_until_complete(server.serve())
    finally:
        loop.close()


if __name__ == "__main__":
    main()
