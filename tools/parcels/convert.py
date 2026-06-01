#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "pyshp>=2.3.1",
#   "pyproj>=3.6.0",
# ]
# ///
"""Convert the GURS "Kataster nepremičnin – Parcele" shapefile into a compact,
offline-queryable ``parcels.sqlite`` for the Gozdar app.

The output mirrors the conventions of the app's existing ``owners.sqlite``:
a ``meta(k,v)`` table, per-row bounding boxes, and an (optional) R-tree spatial
index. Geometry is reprojected from the Slovenian D96/TM grid (EPSG:3794) to
WGS84 (EPSG:4326) and stored as a tiny binary blob the Dart side decodes.

Usage
-----
  python3 convert.py inspect PARCELE.shp
      Print geometry type, feature count, field names/types and a few sample
      records so the right attribute columns can be mapped.

  python3 convert.py build PARCELE.shp -o parcels.sqlite \
      [--ko-field KO_ID] [--parc-field ST_PARCELE] \
      [--area-field POVRSINA] [--eid-field EID_PARCELA] \
      [--source "GURS KN parcele"] [--date 2026-05-31]
      Build the SQLite database. Field flags are auto-detected when omitted.
      Owners are NOT stored here — the app resolves them from owners.sqlite.

The script streams features, so it works on the whole-Slovenia file without
loading it all into memory.
"""

from __future__ import annotations

import argparse
import json
import os
import sqlite3
import struct
import sys
import time

try:
    import shapefile  # pyshp
except ImportError:
    sys.exit("Missing dependency: pip install -r requirements.txt (pyshp)")

try:
    from pyproj import Transformer
except ImportError:
    sys.exit("Missing dependency: pip install -r requirements.txt (pyproj)")


# Source projection of the GURS data and our storage projection.
SRC_CRS = "EPSG:3794"  # Slovenia 1996 / Slovene National Grid (D96/TM)
DST_CRS = "EPSG:4326"  # WGS84 lon/lat

# Geometry blob format version (must match the Dart decoder).
BLOB_VERSION = 1

# Candidate attribute names (case-insensitive) for auto-detection. Names match
# the GURS "Kataster nepremičnin – PARCELE" (SI.GURS.KN:PARCELE) layer; older
# "sifko"/"st_parcele" spellings are kept as fallbacks. Inspect first if unsure.
#
# Note: PARCELE has no owner attribute. Owners (legal persons only) live in
# separate tables and are resolved at runtime by the app's owners.sqlite via
# OwnerLookupService — they are intentionally NOT stored here.
KO_CANDIDATES = ["ko_id", "sifko", "koid", "st_ko", "stko", "ko"]
PARC_CANDIDATES = [
    "st_parcele", "stparcele", "parcela", "stparcela", "stparc",
    "parc_st", "stev_parc", "stevparc", "parcst", "parc",
]
AREA_CANDIDATES = ["povrsina", "povr", "pov", "area", "shape_area", "ploscina"]
EID_CANDIDATES = ["eid_parcela", "eid", "featureid"]


def _find_field(fields: list[str], candidates: list[str]) -> str | None:
    lower = {f.lower(): f for f in fields}
    for c in candidates:
        if c in lower:
            return lower[c]
    # Loose contains-match as a fallback.
    for c in candidates:
        for low, orig in lower.items():
            if c in low:
                return orig
    return None


def _open_reader(shp_path: str) -> shapefile.Reader:
    # GURS descriptive data is UTF-8 (per the portal note).
    return shapefile.Reader(shp_path, encoding="utf-8")


def cmd_inspect(args: argparse.Namespace) -> None:
    r = _open_reader(args.shp)
    geom_types = {
        0: "NULL", 1: "POINT", 3: "POLYLINE", 5: "POLYGON",
        8: "MULTIPOINT", 11: "POINTZ", 13: "POLYLINEZ", 15: "POLYGONZ",
    }
    print(f"File:        {args.shp}")
    print(f"Shape type:  {r.shapeType} ({geom_types.get(r.shapeType, '?')})")
    print(f"Features:    {len(r)}")
    fields = [f for f in r.fields if f[0] != "DeletionFlag"]
    print("\nFields:")
    for name, ftype, length, dec in fields:
        print(f"  {name:<16} type={ftype} len={length} dec={dec}")
    names = [f[0] for f in fields]
    print("\nAuto-detected mapping:")
    print(f"  KO field:     {_find_field(names, KO_CANDIDATES)}")
    print(f"  Parcel field: {_find_field(names, PARC_CANDIDATES)}")
    print(f"  Area field:   {_find_field(names, AREA_CANDIDATES)}")
    print(f"  EID field:    {_find_field(names, EID_CANDIDATES)}")
    print("\nFirst 3 records:")
    for i, sr in enumerate(r.iterShapeRecords()):
        if i >= 3:
            break
        print(f"  [{i}] {dict(zip(names, list(sr.record)))}")
        pts = sr.shape.points
        print(f"      parts={sr.shape.parts} npoints={len(pts)} first={pts[:2]}")


def _encode_geometry(shape, transform) -> tuple[bytes, float, float, float, float] | None:
    """Reproject a polygon/polyline shape to WGS84 and pack its rings into a
    compact blob. Returns (blob, min_lon, max_lon, min_lat, max_lat) or None for
    empty geometry.

    Blob layout (little-endian): version u8, ringCount u32, then per ring
    pointCount u32 followed by pointCount * (lon_e7 i32, lat_e7 i32).
    """
    pts = shape.points
    if not pts:
        return None
    parts = list(shape.parts) + [len(pts)]

    # Bulk-reproject all vertices at once (pyproj is vectorized).
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    lons, lats = transform(xs, ys)

    min_lon = min_lat = float("inf")
    max_lon = max_lat = float("-inf")
    rings: list[bytes] = []
    for i in range(len(parts) - 1):
        start, end = parts[i], parts[i + 1]
        n = end - start
        if n < 3:
            continue
        buf = bytearray()
        for j in range(start, end):
            lon, lat = lons[j], lats[j]
            if lon < min_lon:
                min_lon = lon
            if lon > max_lon:
                max_lon = lon
            if lat < min_lat:
                min_lat = lat
            if lat > max_lat:
                max_lat = lat
            buf += struct.pack("<ii", round(lon * 1e7), round(lat * 1e7))
        rings.append(struct.pack("<I", n) + bytes(buf))

    if not rings:
        return None
    blob = struct.pack("<BI", BLOB_VERSION, len(rings)) + b"".join(rings)
    return blob, min_lon, max_lon, min_lat, max_lat


def _create_schema(db: sqlite3.Connection) -> bool:
    db.executescript(
        """
        CREATE TABLE meta (k TEXT PRIMARY KEY, v TEXT);
        CREATE TABLE parcels (
            id      INTEGER PRIMARY KEY,
            sifko   INTEGER,
            parcela TEXT,
            area    REAL,
            eid     TEXT,
            min_lat REAL, max_lat REAL, min_lon REAL, max_lon REAL,
            poly    BLOB
        );
        """
    )
    # Best-effort R-tree; older sqlite builds may lack the module.
    try:
        db.executescript(
            "CREATE VIRTUAL TABLE parcels_rtree USING rtree("
            "id, min_lon, max_lon, min_lat, max_lat);"
        )
        return True
    except sqlite3.OperationalError:
        print("  (R-tree module unavailable — using plain bbox columns only)")
        return False


def _point_in_ring(lon: float, lat: float, ring: list) -> bool:
    """Ray-casting point-in-polygon for a single ring of (lon, lat) tuples."""
    inside = False
    n = len(ring)
    j = n - 1
    for i in range(n):
        xi, yi = ring[i]
        xj, yj = ring[j]
        if ((yi > lat) != (yj > lat)) and \
                (lon < (xj - xi) * (lat - yi) / (yj - yi) + xi):
            inside = not inside
        j = i
    return inside


# Map Slovenian special letters to ASCII for filename slugs.
_SLUG_MAP = str.maketrans({
    "š": "s", "č": "c", "ž": "z", "đ": "d", "ć": "c",
    "Š": "s", "Č": "c", "Ž": "z", "Đ": "d", "Ć": "c",
})


def _slug(name: str) -> str:
    s = name.strip().lower().translate(_SLUG_MAP)
    out = []
    for ch in s:
        out.append(ch if ch.isalnum() else "-")
    slug = "".join(out)
    while "--" in slug:
        slug = slug.replace("--", "-")
    return slug.strip("-") or "regija"


class RegionIndex:
    """Assigns a (lon, lat) point to a named region polygon. Region geometry is
    loaded from a GeoJSON or shapefile and reprojected to WGS84 once."""

    def __init__(self, path: str, name_field: str | None, src_crs: str):
        to_wgs = Transformer.from_crs(src_crs, DST_CRS, always_xy=True).transform
        # Each entry: (name, [rings], (minx, miny, maxx, maxy)).
        self.regions: list = []
        if path.lower().endswith((".geojson", ".json")):
            self._load_geojson(path, name_field, to_wgs)
        else:
            self._load_shapefile(path, name_field, to_wgs)
        if not self.regions:
            sys.exit(f"No region polygons loaded from {path}.")
        print(f"Loaded {len(self.regions)} regions: "
              f"{', '.join(n for n, _, _ in self.regions)}")

    def _add(self, name, rings):
        if not rings:
            return
        xs = [p[0] for r in rings for p in r]
        ys = [p[1] for r in rings for p in r]
        self.regions.append((name, rings, (min(xs), min(ys), max(xs), max(ys))))

    def _load_geojson(self, path, name_field, to_wgs):
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
        feats = data.get("features", []) if data.get("type") == "FeatureCollection" \
            else [data]
        for i, feat in enumerate(feats):
            props = feat.get("properties", {}) or {}
            name = str(props.get(name_field) if name_field else None
                       or props.get("name") or props.get("NAME")
                       or props.get("SR_UIME") or f"regija-{i}")
            geom = feat.get("geometry", {}) or {}
            rings = self._geom_rings(geom, to_wgs)
            self._add(name, rings)

    def _geom_rings(self, geom, to_wgs):
        gtype = geom.get("type")
        coords = geom.get("coordinates", [])
        polys = []
        if gtype == "Polygon":
            polys = [coords]
        elif gtype == "MultiPolygon":
            polys = coords
        rings = []
        for poly in polys:
            for ring in poly:
                xs = [c[0] for c in ring]
                ys = [c[1] for c in ring]
                lons, lats = to_wgs(xs, ys)
                rings.append(list(zip(lons, lats)))
        return rings

    def _load_shapefile(self, path, name_field, to_wgs):
        rd = shapefile.Reader(path, encoding="utf-8")
        fields = [f[0] for f in rd.fields if f[0] != "DeletionFlag"]
        nf = name_field or _find_field(
            fields, ["sr_uime", "ime", "naziv", "name", "region", "sr_ime"])
        ni = {n: i for i, n in enumerate(fields)}.get(nf) if nf else None
        for i, sr in enumerate(rd.iterShapeRecords()):
            name = str(sr.record[ni]) if ni is not None else f"regija-{i}"
            parts = list(sr.shape.parts) + [len(sr.shape.points)]
            rings = []
            for k in range(len(parts) - 1):
                pts = sr.shape.points[parts[k]:parts[k + 1]]
                if len(pts) < 3:
                    continue
                xs = [p[0] for p in pts]
                ys = [p[1] for p in pts]
                lons, lats = to_wgs(xs, ys)
                rings.append(list(zip(lons, lats)))
            self._add(name, rings)

    def region_for(self, lon: float, lat: float) -> str | None:
        nearest = None
        nearest_d2 = None
        for name, rings, bbox in self.regions:
            mnx, mny, mxx, mxy = bbox
            if mnx <= lon <= mxx and mny <= lat <= mxy:
                inside = False
                for ring in rings:
                    if _point_in_ring(lon, lat, ring):
                        inside = not inside  # even-odd handles holes / multipart
                if inside:
                    return name
            # Track nearest region for the fallback (border points that fall in
            # a gap of the simplified polygons). Cheap: region_for is per-KO.
            d2 = self._min_vertex_dist2(lon, lat, rings)
            if nearest_d2 is None or d2 < nearest_d2:
                nearest_d2 = d2
                nearest = name
        return nearest

    @staticmethod
    def _min_vertex_dist2(lon: float, lat: float, rings: list) -> float:
        best = float("inf")
        for ring in rings:
            for x, y in ring:
                d = (x - lon) ** 2 + (y - lat) ** 2
                if d < best:
                    best = d
        return best


class _DbWriter:
    """One output parcels database, with batched inserts and finalize."""

    _COLS = ("INSERT INTO parcels(id,sifko,parcela,area,eid,"
             "min_lat,max_lat,min_lon,max_lon,poly) "
             "VALUES (?,?,?,?,?,?,?,?,?,?)")

    def __init__(self, path: str):
        self.path = path
        self.db = sqlite3.connect(path)
        self.db.execute("PRAGMA journal_mode=OFF")
        self.db.execute("PRAGMA synchronous=OFF")
        self.has_rtree = _create_schema(self.db)
        self.rows = 0
        self._parcels: list = []
        self._rtree: list = []

    def add(self, sifko, parcela, area, eid, mnlat, mxlat, mnlon, mxlon, blob):
        self.rows += 1
        pid = self.rows
        self._parcels.append(
            (pid, sifko, parcela, area, eid, mnlat, mxlat, mnlon, mxlon, blob))
        self._rtree.append((pid, mnlon, mxlon, mnlat, mxlat))
        if len(self._parcels) >= 5000:
            self.flush()

    def flush(self):
        if not self._parcels:
            return
        self.db.executemany(self._COLS, self._parcels)
        if self.has_rtree:
            self.db.executemany(
                "INSERT INTO parcels_rtree(id,min_lon,max_lon,min_lat,max_lat) "
                "VALUES (?,?,?,?,?)", self._rtree)
        self._parcels.clear()
        self._rtree.clear()
        self.db.commit()

    def finalize(self, meta: list):
        self.flush()
        self.db.execute("CREATE INDEX idx_parcels_ko ON parcels(sifko, parcela)")
        self.db.execute("CREATE INDEX idx_parcels_eid ON parcels(eid)")
        self.db.executemany(
            "INSERT INTO meta(k,v) VALUES (?,?)",
            meta + [("rows", str(self.rows)),
                    ("has_rtree", "1" if self.has_rtree else "0")],
        )
        self.db.commit()
        self.db.execute("PRAGMA journal_mode=DELETE")
        self.db.execute("VACUUM")
        self.db.close()


def cmd_build(args: argparse.Namespace) -> None:
    r = _open_reader(args.shp)
    names = [f[0] for f in r.fields if f[0] != "DeletionFlag"]

    ko_field = args.ko_field or _find_field(names, KO_CANDIDATES)
    parc_field = args.parc_field or _find_field(names, PARC_CANDIDATES)
    area_field = args.area_field or _find_field(names, AREA_CANDIDATES)
    eid_field = args.eid_field or _find_field(names, EID_CANDIDATES)

    if not ko_field or not parc_field:
        sys.exit(
            "Could not determine KO/parcel fields. Run `inspect` and pass "
            "--ko-field / --parc-field explicitly.\n"
            f"Available fields: {names}"
        )
    print(f"Mapping: ko={ko_field} parcel={parc_field} area={area_field} "
          f"eid={eid_field}")

    idx = {n: i for i, n in enumerate(names)}
    ko_i = idx[ko_field]
    parc_i = idx[parc_field]
    area_i = idx[area_field] if area_field in idx else None
    eid_i = idx[eid_field] if eid_field in idx else None

    transformer = Transformer.from_crs(SRC_CRS, DST_CRS, always_xy=True)
    transform = transformer.transform

    # Optional region split: assign each parcel (by viewport-centre point) to a
    # statistical region polygon and write one database per region. KOs stay
    # whole — the first parcel of a KO fixes the region for all its parcels.
    regions = None
    region_writers: dict = {}
    ko_region: dict = {}
    outdir = None
    single = None
    if args.regions:
        rcrs = args.regions_crs or (
            "EPSG:3794" if args.regions.lower().endswith(".shp") else "EPSG:4326")
        print(f"Splitting by regions from {args.regions} (CRS {rcrs})")
        regions = RegionIndex(args.regions, args.region_field, rcrs)
        outdir = args.output
        os.makedirs(outdir, exist_ok=True)
    else:
        single = _DbWriter(args.output)

    def writer_for(name: str) -> _DbWriter:
        w = region_writers.get(name)
        if w is None:
            w = _DbWriter(os.path.join(outdir, f"parcels-{_slug(name)}.sqlite"))
            region_writers[name] = w
        return w

    total = len(r)
    t0 = time.time()
    rows = 0
    skipped = 0

    for sr in r.iterShapeRecords():
        rec = list(sr.record)
        enc = _encode_geometry(sr.shape, transform)
        if enc is None:
            skipped += 1
            continue
        blob, mnlon, mxlon, mnlat, mxlat = enc
        try:
            sifko = int(rec[ko_i])
        except (TypeError, ValueError):
            sifko = None
        parcela = str(rec[parc_i]).strip() if rec[parc_i] is not None else None
        area = None
        if area_i is not None:
            try:
                area = float(rec[area_i])
            except (TypeError, ValueError):
                area = None
        eid = None
        if eid_i is not None and rec[eid_i] not in (None, ""):
            eid = str(rec[eid_i]).strip()

        if regions is not None:
            region = ko_region.get(sifko) if sifko is not None else None
            if region is None:
                clon = (mnlon + mxlon) / 2
                clat = (mnlat + mxlat) / 2
                region = regions.region_for(clon, clat) or "unassigned"
                if sifko is not None:
                    ko_region[sifko] = region
            writer = writer_for(region)
        else:
            writer = single
        writer.add(sifko, parcela, area, eid, mnlat, mxlat, mnlon, mxlon, blob)

        rows += 1
        if rows % 100000 == 0:
            dt = time.time() - t0
            rate = rows / dt if dt else 0
            pct = (rows + skipped) / total * 100 if total else 0
            print(f"  {rows:,} parcels ({pct:.1f}%) "
                  f"{rate:,.0f}/s elapsed {dt:.0f}s", flush=True)

    base_meta = [
        ("schema", "1"),
        ("crs", "wgs84"),
        ("blob_version", str(BLOB_VERSION)),
        ("source", args.source or "GURS KN parcele"),
        ("date", args.date or ""),
    ]

    print("  building indexes / finalizing...")
    if regions is not None:
        for name, w in sorted(region_writers.items()):
            w.finalize(base_meta + [("region", name)])
            print(f"    {name}: {w.rows:,} parcels -> {os.path.basename(w.path)}")
    else:
        single.finalize(base_meta)

    dt = time.time() - t0
    print(f"\nDone: {rows:,} parcels ({skipped:,} skipped) in {dt:.0f}s")
    if regions is not None:
        print(f"Output: {outdir}/ ({len(region_writers)} regions)")
    else:
        print(f"Output: {args.output}")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    pi = sub.add_parser("inspect", help="Print shapefile schema and samples")
    pi.add_argument("shp")
    pi.set_defaults(func=cmd_inspect)

    pb = sub.add_parser("build", help="Build parcels.sqlite")
    pb.add_argument("shp")
    pb.add_argument("-o", "--output", default="parcels.sqlite")
    pb.add_argument("--ko-field")
    pb.add_argument("--parc-field")
    pb.add_argument("--area-field")
    pb.add_argument("--eid-field")
    pb.add_argument(
        "--regions",
        help="GeoJSON/SHP of region polygons; splits output into one "
             "parcels-<region>.sqlite per region (in the -o directory).")
    pb.add_argument(
        "--region-field",
        help="Attribute/property holding the region name (auto-detected).")
    pb.add_argument(
        "--regions-crs",
        help="CRS of the regions file (default EPSG:4326 for GeoJSON, "
             "EPSG:3794 for SHP).")
    pb.add_argument("--source")
    pb.add_argument("--date")
    pb.set_defaults(func=cmd_build)

    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
