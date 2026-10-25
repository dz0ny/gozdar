#!/usr/bin/env -S uv run --quiet --with pyshp --with pyproj --with shapely python
"""Split one parcels database into a north-west and a south-east half.

R2 uploads with wrangler stop at 300 MiB, so the largest county needs two files.
Each KO stays whole. The cut is a line of constant (lon - lat) that puts half
of the parcels on each side.

Run `./split_region.py parcels-splitsko-dalmatinska.sqlite regije_hr.json -o out/`.
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3

from shapely.geometry import Polygon, mapping, shape

import convert


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("db")
    ap.add_argument("regions", help="JSON list of region features; the one with this DB's name is cut")
    ap.add_argument("-o", "--output", required=True)
    ap.add_argument("--suffixes", default="SZ,JI", help="names for the NW and SE halves")
    args = ap.parse_args()
    nw_sfx, se_sfx = args.suffixes.split(",")

    src = sqlite3.connect(args.db)
    meta = dict(src.execute("SELECT k, v FROM meta"))
    base = meta["region"]
    rows = src.execute(
        "SELECT sifko, parcela, area, eid, min_lat, max_lat, min_lon, max_lon, poly "
        "FROM parcels ORDER BY sifko, id").fetchall()

    # KO key: mean of the parcel bbox centres
    sums: dict[int, list[float]] = {}
    for r in rows:
        s = sums.setdefault(r[0], [0.0, 0.0, 0])
        s[0] += (r[6] + r[7]) / 2
        s[1] += (r[4] + r[5]) / 2
        s[2] += 1
    key = {k: v[0] / v[2] - v[1] / v[2] for k, v in sums.items()}
    counts = {k: v[2] for k, v in sums.items()}
    total = sum(counts.values())
    acc, cut = 0, None
    for k in sorted(key, key=key.get):
        acc += counts[k]
        if acc >= total / 2:
            cut = key[k]
            break
    nw = {k for k in key if key[k] <= cut}

    os.makedirs(args.output, exist_ok=True)
    names = {True: f"{base} ({nw_sfx})", False: f"{base} ({se_sfx})"}
    writers = {}
    for side, name in names.items():
        path = os.path.join(args.output, f"parcels-{convert._slug(name)}.sqlite")
        if os.path.exists(path):
            os.remove(path)
        writers[side] = convert._DbWriter(path)
    for sifko, parcela, area, eid, mnlat, mxlat, mnlon, mxlon, blob in rows:
        writers[sifko in nw].add(sifko, parcela, area, eid, mnlat, mxlat, mnlon, mxlon, blob)
    keep = [(k, v) for k, v in meta.items() if k not in ("region", "rows", "has_rtree")]
    for side, w in writers.items():
        w.finalize(keep + [("region", names[side])])
        print(f"{names[side]}: {w.rows:,} parcels, {os.path.getsize(w.path) / 1e6:.0f} MB")

    # cut the region polygon with the same line: lon - lat <= cut
    feats = json.load(open(args.regions, encoding="utf-8"))
    out = []
    for f in feats:
        if f["properties"]["name"] != base:
            out.append(f)
            continue
        g = shape(f["geometry"])
        # half-plane lon - lat <= cut, as a polygon
        half = Polygon([(cut + 40, 40), (cut + 50, 50), (5, 50), (5, 40)])
        for side, geom in ((True, g.intersection(half)), (False, g.difference(half))):
            code = f["properties"]["code"] + ("1" if side else "2")
            out.append({"type": "Feature", "geometry": mapping(geom),
                        "properties": {"code": code, "name": names[side], "area": 0}})
    json.dump(out, open(os.path.join(args.output, "regije_hr.json"), "w", encoding="utf-8"),
              ensure_ascii=False, separators=(",", ":"))
    print("region polygon cut at lon - lat =", round(cut, 4))


if __name__ == "__main__":
    main()
