#!/usr/bin/env python3
"""Generate two Tesla-like MapLibre styles (light + dark) from the OpenFreeMap
`liberty` style: keep the 3D buildings, drop the basemap's own POI layers, and
recolour every layer to a flat, minimal palette like the Model 3/Y map.

Input:  liberty.json  (fetched from tiles.openfreemap.org/styles/liberty)
Output: map-light.json, map-dark.json
"""
import json, sys, os

LIGHT = {
    "bg": "#e8e9ec", "water": "#a8c5de", "green": "#cdddb8",
    "road": "#ffffff", "road_casing": "#d3d7dd",
    "hwy": "#fdeecb", "hwy_casing": "#e3c386",
    "building": "#dee1e6", "text": "#4c515a", "halo": "#ffffff",
    "boundary": "#c0c4cb",
}
DARK = {
    "bg": "#181b21", "water": "#16344a", "green": "#1e2b1c",
    "road": "#2b2f37", "road_casing": "#353a43",
    "hwy": "#3d434e", "hwy_casing": "#4b525e",
    "building": "#22262e", "text": "#9aa2ad", "halo": "#0c0e12",
    "boundary": "#2d313a",
}


def recolor(layer, P):
    t   = layer.get("type", "")
    sl  = layer.get("source-layer", "")
    lid = layer.get("id", "").lower()
    paint = layer.setdefault("paint", {})

    # Tesla maps are flat — kill any fill texture (wetland grass, paved
    # pedestrian hatch…) and fall back to a solid colour.
    if "fill-pattern" in paint:
        del paint["fill-pattern"]
        paint["fill-color"] = P["road"] if "pedestrian" in lid or "road" in lid else P["green"]
        paint["fill-opacity"] = 1.0
        return layer

    if t == "background":
        paint["background-color"] = P["bg"]
    elif t == "fill-extrusion":                       # 3D buildings
        paint["fill-extrusion-color"]   = P["building"]
        paint["fill-extrusion-opacity"] = 0.9
    elif sl == "water" or sl == "ocean" or "water" in lid:
        if t == "fill": paint["fill-color"] = P["water"]
        if t == "line": paint["line-color"] = P["water"]
    elif sl in ("landcover", "landuse", "park") or any(
            k in lid for k in ("park", "wood", "green", "grass", "landcover", "landuse")):
        if t == "fill": paint["fill-color"] = P["green"]
    elif sl == "building":
        if t == "fill": paint["fill-color"] = P["building"]
    elif sl == "transportation" or any(
            k in lid for k in ("road", "highway", "bridge", "tunnel", "street", "motorway", "trunk")):
        if t == "line":
            casing = "casing" in lid or "outline" in lid
            hwy = any(k in lid for k in ("motorway", "trunk", "primary", "highway"))
            paint["line-color"] = (P["hwy_casing"] if hwy else P["road_casing"]) if casing \
                                  else (P["hwy"] if hwy else P["road"])
    elif t == "symbol":
        paint["text-color"]      = P["text"]
        paint["text-halo-color"] = P["halo"]
    elif sl == "boundary" or "boundary" in lid or "admin" in lid:
        if t == "line": paint["line-color"] = P["boundary"]
    return layer


def is_poi(l):
    sl = l.get("source-layer", "")
    return sl in ("poi", "mountain_peak") or l.get("id", "").lower().startswith("poi")


def build(src, palette, name):
    s = json.loads(json.dumps(src))            # deep copy
    s["name"] = name
    s["layers"] = [recolor(l, palette) for l in s["layers"] if not is_poi(l)]
    return s


def main():
    here = os.path.dirname(__file__) or "."
    src_path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/liberty.json"
    src = json.load(open(src_path))
    for pal, fn, nm in [(LIGHT, "map-light.json", "Hermes Light"),
                        (DARK,  "map-dark.json",  "Hermes Dark")]:
        out = build(src, pal, nm)
        path = os.path.join(here, fn)
        json.dump(out, open(path, "w"), separators=(",", ":"))
        print(f"{fn}: {len(out['layers'])} layers, {os.path.getsize(path)} B")


if __name__ == "__main__":
    main()
