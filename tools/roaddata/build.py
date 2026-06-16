#!/usr/bin/env python3
"""Build the Hermes offline road-metadata SQLite from OpenStreetMap (Overpass).

Tiles the requested area into a fixed 0.1° grid and fetches each cell once.
Re-running is incremental: already-fetched cells (recorded in `tile`) are
skipped, so you can grow coverage over time or resume after an interruption.

The exact same query + parse logic is mirrored in RoadInfoController on the Pi
for online auto-download of new regions — keep them in sync.

Usage:
    build.py --lat -20.0135 --lon -45.5526 --radius 40 --out roaddata.sqlite
    build.py --bbox MINLAT MINLON MAXLAT MAXLON --out roaddata.sqlite
"""
import argparse, json, math, os, sqlite3, sys, time, urllib.parse, urllib.request

CELL = 0.1  # degrees — must match RoadInfoController tile grid

AMENITY_CAT = {
    "fuel": "fuel",
    "charging_station": "charging",
    "restaurant": "food", "fast_food": "food", "cafe": "food",
    "bar": "food", "pub": "food", "ice_cream": "food", "food_court": "food",
    "hospital": "hospital", "clinic": "hospital", "doctors": "hospital",
    "pharmacy": "pharmacy",
    "bank": "bank", "atm": "bank", "bureau_de_change": "bank",
}
SHOP_CAT = {
    "supermarket": "supermarket", "convenience": "supermarket",
    "bakery": "food", "butcher": "food", "greengrocer": "food",
    "mall": "shopping", "department_store": "shopping",
}
TOURISM_CAT = {"hotel": "lodging", "motel": "lodging", "guest_house": "lodging"}


def normalize_category(tags):
    """Map raw OSM tags to a display bucket, or None to skip."""
    a = tags.get("amenity")
    if a in AMENITY_CAT:
        return AMENITY_CAT[a]
    s = tags.get("shop")
    if s:
        return SHOP_CAT.get(s, "shopping")   # any other shop → generic shopping
    t = tags.get("tourism")
    if t in TOURISM_CAT:
        return TOURISM_CAT[t]
    return None


def addr_of(tags):
    parts = []
    if tags.get("addr:street"):
        st = tags["addr:street"]
        if tags.get("addr:housenumber"):
            st += ", " + tags["addr:housenumber"]
        parts.append(st)
    if tags.get("addr:suburb"):
        parts.append(tags["addr:suburb"])
    return ", ".join(parts) or None


def centroid(geom):
    if not geom:
        return None
    return (sum(p["lat"] for p in geom) / len(geom),
            sum(p["lon"] for p in geom) / len(geom))

ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
]


def overpass_query(minlat, minlon, maxlat, maxlon):
    bbox = f"{minlat},{minlon},{maxlat},{maxlon}"
    # nwr = node+way+relation. Shops/amenities mapped as building polygons are
    # captured as ways and reduced to a centroid on ingest. `out center` gives
    # ways a center point; `geom` is still needed for maxspeed road geometry,
    # so we request both via `out geom` and compute centroids ourselves.
    return f"""[out:json][timeout:120];
(
  way["maxspeed"]({bbox});
  node["highway"="speed_camera"]({bbox});
  nwr["amenity"~"^(fuel|charging_station|restaurant|fast_food|cafe|bar|pub|ice_cream|food_court|hospital|clinic|doctors|pharmacy|bank|atm|bureau_de_change)$"]({bbox});
  nwr["shop"]({bbox});
  nwr["tourism"~"^(hotel|motel|guest_house)$"]({bbox});
);
out body geom;"""


def fetch(query):
    data = urllib.parse.urlencode({"data": query}).encode()
    last = None
    for ep in ENDPOINTS:
        for _ in range(2):
            try:
                req = urllib.request.Request(
                    ep, data=data, headers={"User-Agent": "hermes-roaddata/1.0"})
                with urllib.request.urlopen(req, timeout=150) as r:
                    return json.load(r)
            except Exception as e:  # noqa: BLE001
                last = e
                sys.stderr.write(f"  retry ({ep.split('/')[2]}): {type(e).__name__}\n")
                time.sleep(4)
    raise RuntimeError(f"all endpoints failed: {last}")


def parse_maxspeed(raw):
    """Return integer km/h or None. Numeric only — implicit tags ignored to
    avoid asserting a wrong limit on a safety warning."""
    if not raw:
        return None
    raw = raw.strip().lower()
    num = ""
    for ch in raw:
        if ch.isdigit():
            num += ch
        elif num:
            break
    if not num:
        return None
    v = int(num)
    if "mph" in raw:
        v = round(v * 1.60934)
    return v if 5 <= v <= 140 else None


def add_poi(conn, lat, lon, cat, tags, osm_id):
    conn.execute(
        "INSERT OR IGNORE INTO poi(lat,lon,category,name,address,phone,website,src,osm_id)"
        " VALUES (?,?,?,?,?,?,?,?,?)",
        (lat, lon, cat, tags.get("name"), addr_of(tags),
         tags.get("phone") or tags.get("contact:phone"),
         tags.get("website") or tags.get("contact:website"),
         "osm", osm_id))


def ingest(conn, payload):
    segs = cams = pois = 0
    for el in payload.get("elements", []):
        t = el.get("type")
        tags = el.get("tags", {})
        oid = el.get("id")

        # Roads with a speed limit → segments.
        if t == "way" and "maxspeed" in tags:
            ms = parse_maxspeed(tags.get("maxspeed"))
            if ms is not None:
                geom = el.get("geometry", [])
                for a, b in zip(geom, geom[1:]):
                    la1, lo1, la2, lo2 = a["lat"], a["lon"], b["lat"], b["lon"]
                    conn.execute(
                        "INSERT INTO road_seg(lat1,lon1,lat2,lon2,minlat,maxlat,minlon,maxlon,maxspeed)"
                        " VALUES (?,?,?,?,?,?,?,?,?)",
                        (la1, lo1, la2, lo2, min(la1, la2), max(la1, la2),
                         min(lo1, lo2), max(lo1, lo2), ms))
                    segs += 1

        # Speed cameras (nodes only).
        if t == "node" and tags.get("highway") == "speed_camera":
            conn.execute(
                "INSERT OR IGNORE INTO camera(lat,lon,maxspeed,osm_id) VALUES (?,?,?,?)",
                (el["lat"], el["lon"], parse_maxspeed(tags.get("maxspeed")), oid))
            cams += 1
            continue

        # POIs (node lat/lon, or way/relation centroid).
        cat = normalize_category(tags)
        if cat:
            if t == "node":
                la, lo = el.get("lat"), el.get("lon")
            else:
                c = centroid(el.get("geometry"))
                la, lo = (c if c else (el.get("center", {}).get("lat"),
                                       el.get("center", {}).get("lon")))
            if la is not None and lo is not None:
                # OSM ids collide across node/way namespaces; offset ways.
                uid = oid if t == "node" else (oid + 10_000_000_000)
                add_poi(conn, la, lo, cat, tags, uid)
                pois += 1
    return segs, cams, pois


def cells_for(minlat, minlon, maxlat, maxlon):
    cy0, cy1 = math.floor(minlat / CELL), math.floor(maxlat / CELL)
    cx0, cx1 = math.floor(minlon / CELL), math.floor(maxlon / CELL)
    for cy in range(cy0, cy1 + 1):
        for cx in range(cx0, cx1 + 1):
            yield cx, cy


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lat", type=float)
    ap.add_argument("--lon", type=float)
    ap.add_argument("--radius", type=float, default=40, help="km")
    ap.add_argument("--bbox", type=float, nargs=4,
                    metavar=("MINLAT", "MINLON", "MAXLAT", "MAXLON"))
    ap.add_argument("--out", required=True)
    ap.add_argument("--delay", type=float, default=3.0, help="s between tiles")
    args = ap.parse_args()

    if args.bbox:
        minlat, minlon, maxlat, maxlon = args.bbox
    elif args.lat is not None and args.lon is not None:
        dlat = args.radius / 111.0
        dlon = args.radius / (111.0 * math.cos(math.radians(args.lat)))
        minlat, maxlat = args.lat - dlat, args.lat + dlat
        minlon, maxlon = args.lon - dlon, args.lon + dlon
    else:
        ap.error("provide --lat/--lon or --bbox")

    schema = os.path.join(os.path.dirname(__file__), "schema.sql")
    conn = sqlite3.connect(args.out)
    with open(schema) as f:
        conn.executescript(f.read())

    todo = [c for c in cells_for(minlat, minlon, maxlat, maxlon)
            if not conn.execute("SELECT 1 FROM tile WHERE cx=? AND cy=?", c).fetchone()]
    print(f"area {minlat:.3f},{minlon:.3f} → {maxlat:.3f},{maxlon:.3f}")
    print(f"{len(todo)} tiles to fetch ({CELL}° grid)")

    tot = [0, 0, 0]
    for i, (cx, cy) in enumerate(todo, 1):
        la, lo = cy * CELL, cx * CELL
        print(f"[{i}/{len(todo)}] cell ({cx},{cy}) {la:.2f},{lo:.2f} …", end=" ", flush=True)
        try:
            payload = fetch(overpass_query(la, lo, la + CELL, lo + CELL))
        except RuntimeError as e:
            print(f"FAIL {e}")
            continue
        s, c, p = ingest(conn, payload)
        conn.execute("INSERT OR REPLACE INTO tile(cx,cy,fetched_at) VALUES (?,?,?)",
                     (cx, cy, int(time.time())))
        conn.commit()
        tot[0] += s; tot[1] += c; tot[2] += p
        print(f"seg={s} cam={c} poi={p}")
        time.sleep(args.delay)

    conn.execute("PRAGMA wal_checkpoint(TRUNCATE)")
    conn.execute("VACUUM")
    conn.close()
    size = os.path.getsize(args.out) / 1e6
    print(f"\nDONE  segments={tot[0]} cameras={tot[1]} pois={tot[2]}  ({size:.1f} MB)")


if __name__ == "__main__":
    main()
