#!/usr/bin/env python3
"""Enrich the road-metadata SQLite with POIs from Overture Maps Places.

Overture's open Places dataset (GeoParquet on public S3) has far better POI
coverage than OSM, especially for small Brazilian towns. We query it with the
DuckDB CLI directly over S3 — no full download — filter to a bbox, map the
fine-grained Overture category to our display buckets, and INSERT the useful
ones into the `poi` table with src='overture'. OSM stays the source for roads
and speed cameras (Overture has neither).

Requires the `duckdb` CLI (v1.x). Usage mirrors build.py:
    build_places.py --lat -20.0135 --lon -45.5526 --radius 25 --out roaddata.sqlite
    build_places.py --bbox MINLAT MINLON MAXLAT MAXLON --out roaddata.sqlite
"""
import argparse, math, os, subprocess, sys

RELEASE = "2026-05-20.0"
S3 = (f"s3://overturemaps-us-west-2/release/{RELEASE}"
      "/theme=places/type=place/*")

# Overture category (categories.primary) → our bucket. Evaluated top-down as a
# SQL CASE; unmapped categories are skipped so the map stays useful, not noisy.
CATEGORY_CASE = """
CASE
  WHEN cat IN ('gas_station','fuel') OR cat LIKE '%gas_station%' THEN 'fuel'
  WHEN cat LIKE '%ev_charging%' OR cat LIKE '%charging_station%'
       OR cat LIKE '%electric_vehicle%' THEN 'charging'
  WHEN cat LIKE '%pharmacy%' OR cat LIKE '%drugstore%' THEN 'pharmacy'
  WHEN cat LIKE '%hospital%' OR cat LIKE '%clinic%'
       OR cat IN ('doctor','dentist','urgent_care_clinic','medical_clinic') THEN 'hospital'
  WHEN cat IN ('bank','atm') OR cat LIKE '%bank%' OR cat LIKE '%atm%' THEN 'bank'
  WHEN cat IN ('supermarket','grocery_store','convenience_store') THEN 'supermarket'
  WHEN cat LIKE '%restaurant%' OR cat LIKE '%coffee%' OR cat LIKE '%cafe%'
       OR cat IN ('bar','pub','bakery','ice_cream_shop','food_court','food',
                  'fast_food_restaurant','snack_bar','steakhouse','pizzeria',
                  'churrascaria','lanchonete') THEN 'food'
  WHEN cat LIKE '%hotel%' OR cat IN ('motel','hostel','lodging','bed_and_breakfast',
                                     'inn','guest_house','pousada') THEN 'lodging'
  WHEN cat LIKE '%worship%' OR cat LIKE '%church%' OR cat LIKE '%temple%'
       OR cat LIKE '%religious%'
       OR cat IN ('mosque','synagogue','cathedral','chapel') THEN 'worship'
  WHEN cat LIKE '%beauty%' OR cat LIKE '%barber%' OR cat LIKE '%hair%'
       OR cat LIKE '%nail%' OR cat LIKE '%cosmetic%' OR cat LIKE '%spa%'
       OR cat LIKE '%eyewear%' OR cat IN ('esthetician','tanning_salon') THEN 'beauty'
  WHEN cat LIKE '%gym%' OR cat LIKE '%fitness%' OR cat IN ('yoga_studio',
       'martial_arts','sports_club','pilates') THEN 'gym'
  WHEN cat LIKE '%automotive%' OR cat LIKE '%car_dealer%' OR cat LIKE '%car_wash%'
       OR cat LIKE '%motorcycle%' OR cat IN ('car_repair','auto_parts',
       'tire_shop','gas_station_and_garage') THEN 'automotive'
  WHEN cat LIKE '%park%' OR cat IN ('garden','playground','dog_park','national_park',
                                    'state_park','botanical_garden') THEN 'park'
  WHEN cat LIKE '%school%' OR cat IN ('college_university','university','kindergarten',
                                      'education','library') THEN 'education'
  WHEN cat LIKE '%tourist%' OR cat LIKE '%attraction%' OR cat LIKE '%museum%'
       OR cat IN ('viewpoint','monument','landmark_and_historical_building','art_gallery',
                  'zoo','aquarium','beach','stadium','arena','theme_park','scenic_point') THEN 'attraction'
  WHEN cat LIKE '%_store' OR cat LIKE '%_shop' OR cat LIKE '%market%'
       OR cat LIKE '%mall%' OR cat LIKE '%boutique%' OR cat LIKE '%shopping%' THEN 'shopping'
  ELSE 'place'   -- generic: everything named still shows (church, salon, office…)
END
"""


def build_sql(db, minlat, minlon, maxlat, maxlon):
    # bbox center is exact for point geometries (xmin==xmax). Avoids needing
    # the spatial extension just to read the coordinate.
    return f"""
INSTALL httpfs; LOAD httpfs;
INSTALL sqlite;  LOAD sqlite;
SET s3_region='us-west-2';
ATTACH '{db}' AS db (TYPE sqlite);

DELETE FROM db.poi WHERE src='overture';

INSERT INTO db.poi (lat, lon, category, subcat, importance, name, address, phone, website, socials, src, osm_id)
WITH raw AS (
  SELECT
    (bbox.ymin + bbox.ymax) / 2.0 AS lat,
    (bbox.xmin + bbox.xmax) / 2.0 AS lon,
    names.primary               AS name,
    TRY(addresses[1].freeform)  AS address,
    TRY(phones[1])              AS phone,
    TRY(websites[1])            AS website,
    TRY(socials[1])             AS socials,
    confidence                  AS importance,
    categories.primary          AS cat
  FROM read_parquet('{S3}', hive_partitioning=1)
  WHERE bbox.xmin BETWEEN {minlon} AND {maxlon}
    AND bbox.ymin BETWEEN {minlat} AND {maxlat}
    AND confidence > 0.40
    AND names.primary IS NOT NULL
),
mapped AS (
  SELECT lat, lon, name, address, phone, website, socials, importance, cat,
         {CATEGORY_CASE.strip()} AS bucket
  FROM raw
)
SELECT lat, lon, bucket, cat, importance, name, address, phone, website, socials, 'overture', NULL
FROM mapped
WHERE bucket IS NOT NULL;

SELECT 'overture pois', COUNT(*) FROM db.poi WHERE src='overture';
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lat", type=float)
    ap.add_argument("--lon", type=float)
    ap.add_argument("--radius", type=float, default=25)
    ap.add_argument("--bbox", type=float, nargs=4,
                    metavar=("MINLAT", "MINLON", "MAXLAT", "MAXLON"))
    ap.add_argument("--out", required=True)
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

    if not os.path.exists(args.out):
        ap.error(f"{args.out} not found — run build.py first")

    sql = build_sql(os.path.abspath(args.out), minlat, minlon, maxlat, maxlon)
    print(f"Overture {RELEASE} · bbox {minlat:.3f},{minlon:.3f} → {maxlat:.3f},{maxlon:.3f}")
    print("querying S3 (this can take a minute)…")
    r = subprocess.run(["duckdb"], input=sql, text=True,
                       capture_output=True, timeout=900)
    sys.stdout.write(r.stdout)
    if r.returncode != 0:
        sys.stderr.write(r.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
