-- Hermes road metadata — offline SQLite schema.
-- Shared between the Python generator (tools/roaddata/build.py) and the
-- runtime auto-downloader (RoadInfoController on the Pi). Both write here, so
-- keep this in sync with RoadInfoController::ensureSchema().
--
-- Tile grid: fixed 0.1° cells. cell_x = floor(lon/0.1), cell_y = floor(lat/0.1).
-- The `tile` table records which cells have been fetched so the runtime knows
-- whether an area is covered (offline) or must be downloaded (online).

PRAGMA journal_mode = WAL;
PRAGMA synchronous  = NORMAL;

-- Road segments (consecutive node pairs) carrying a numeric speed limit.
CREATE TABLE IF NOT EXISTS road_seg (
    lat1     REAL NOT NULL,
    lon1     REAL NOT NULL,
    lat2     REAL NOT NULL,
    lon2     REAL NOT NULL,
    minlat   REAL NOT NULL,
    maxlat   REAL NOT NULL,
    minlon   REAL NOT NULL,
    maxlon   REAL NOT NULL,
    maxspeed INTEGER NOT NULL          -- km/h
);
CREATE INDEX IF NOT EXISTS idx_seg_bbox ON road_seg(minlat, maxlat, minlon, maxlon);

-- Speed / red-light cameras.
CREATE TABLE IF NOT EXISTS camera (
    lat      REAL NOT NULL,
    lon      REAL NOT NULL,
    maxspeed INTEGER,                  -- posted limit at the camera, if tagged
    osm_id   INTEGER UNIQUE            -- dedup across overlapping fetches
);
CREATE INDEX IF NOT EXISTS idx_cam ON camera(lat, lon);

-- Points of interest.
CREATE TABLE IF NOT EXISTS poi (
    lat      REAL NOT NULL,
    lon      REAL NOT NULL,
    category TEXT NOT NULL,            -- normalised bucket (food|fuel|shopping|…)
    subcat   TEXT,                     -- fine category (overture/osm), shown as label
    importance REAL DEFAULT 0.4,       -- 0..1 prominence (overture confidence)
    name     TEXT,
    address  TEXT,
    phone    TEXT,
    website  TEXT,
    socials  TEXT,                     -- first social URL, if any
    src      TEXT,                     -- osm | overture
    osm_id   INTEGER UNIQUE
);
CREATE INDEX IF NOT EXISTS idx_poi ON poi(lat, lon);

-- Fetched-tile registry (0.1° grid).
CREATE TABLE IF NOT EXISTS tile (
    cx          INTEGER NOT NULL,
    cy          INTEGER NOT NULL,
    fetched_at  INTEGER NOT NULL,      -- unix epoch
    PRIMARY KEY (cx, cy)
);
