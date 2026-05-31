#!/usr/bin/env python3
"""
Enrich an owners.sqlite (built by tool/build_owners_db.sh) with a rough per-parcel
bounding box in WGS84, so the app can resolve a tapped map point -> owner offline.

The owner CSV has no geometry; the geometry lives in the Esri mobile geodatabase
inside the MMPK. We don't decode the proprietary ST_Geometry blobs — the
geodatabase already ships an R-tree spatial index that stores each feature's
real-world bbox (EPSG:3912 / D48 GK meters). We aggregate it per (SIFKO, PARCELA),
reproject to WGS84, and write it onto owners.sqlite plus an R-tree for fast lookup.

  <geodatabase>  (extract p14/karta_slo.geodatabase from Karta_Slovenije_33.mmpk)
    Kataster_KO_Erase_Merge(OBJECTID, SIFKO, PARCELA, Lastnik, Shape, ...)
    st_spindex__Kataster_KO_Erase_Merge_Shape = RTREE(pkid, minx, maxx, miny, maxy)
        pkid == OBJECTID

Adds to owners.sqlite:
  * columns min_lon, max_lon, min_lat, max_lat (REAL, EPSG:4326) on `owners`
  * `owners_bbox` = rtree(id, min_lon, max_lon, min_lat, max_lat), id = owners.rowid
  * B-tree fallback indexes idx_owners_lon / idx_owners_lat
  * meta rows: bbox_crs, bbox_matched, bbox_missing

Requirements: python3 with the rtree-enabled stdlib sqlite3 (the macOS Android
CLI sqlite3 lacks RTREE — use the python interpreter), and `pip install pyproj`.

Usage:
  python3 tool/add_owner_bbox.py [owners.sqlite] [karta_slo.geodatabase]
Defaults match the current artifacts on /Volumes/Disk.
"""
import sqlite3, sys, time
from pyproj import Transformer

OWN = sys.argv[1] if len(sys.argv) > 1 else "owners.sqlite"
GDB = sys.argv[2] if len(sys.argv) > 2 else "/Volumes/Disk/karta_slo.geodatabase"

t0 = time.time()

# 1) Per-(sifko,parcela) bbox in EPSG:3912 meters, straight from the geodatabase rtree.
print(f"reading {GDB} ...", flush=True)
g = sqlite3.connect(GDB)
g.text_factory = bytes  # ICUFOLDCASE collation chokes on text comparisons otherwise
cur = g.execute("""
    SELECT k.SIFKO, k.PARCELA,
           MIN(r.minx), MAX(r.maxx), MIN(r.miny), MAX(r.maxy)
    FROM Kataster_KO_Erase_Merge k
    JOIN st_spindex__Kataster_KO_Erase_Merge_Shape r ON r.pkid = k.OBJECTID
    WHERE k.Lastnik IS NOT NULL AND k.Lastnik <> ''
    GROUP BY k.SIFKO, k.PARCELA
""")
keys, minx, maxx, miny, maxy = [], [], [], [], []
for sifko, parcela, mnx, mxx, mny, mxy in cur:
    if mnx is None or sifko is None or parcela is None:
        continue
    p = parcela.decode("utf-8") if isinstance(parcela, bytes) else parcela
    keys.append((int(sifko), p))
    minx.append(mnx); maxx.append(mxx); miny.append(mny); maxy.append(mxy)
g.close()
n = len(keys)
print(f"  {n:,} distinct parcel bboxes  ({time.time()-t0:.1f}s)", flush=True)

# 2) Bulk reproject the SW and NE corners EPSG:3912 (D48/GK) -> EPSG:4326 (lon/lat).
tr = Transformer.from_crs("EPSG:3912", "EPSG:4326", always_xy=True)
lon_sw, lat_sw = tr.transform(minx, miny)
lon_ne, lat_ne = tr.transform(maxx, maxy)
boxes = {}
for i in range(n):
    mnlon, mxlon = (lon_sw[i], lon_ne[i]) if lon_sw[i] <= lon_ne[i] else (lon_ne[i], lon_sw[i])
    mnlat, mxlat = (lat_sw[i], lat_ne[i]) if lat_sw[i] <= lat_ne[i] else (lat_ne[i], lat_sw[i])
    boxes[keys[i]] = (mnlon, mxlon, mnlat, mxlat)

# 3) Write onto owners.sqlite.
o = sqlite3.connect(OWN)
o.execute("PRAGMA journal_mode=WAL")
for col in ("min_lon", "max_lon", "min_lat", "max_lat"):
    try:
        o.execute(f"ALTER TABLE owners ADD COLUMN {col} REAL")
    except sqlite3.OperationalError:
        pass  # already present on a rerun
o.execute("DROP TABLE IF EXISTS owners_bbox")
o.execute("CREATE VIRTUAL TABLE owners_bbox USING rtree(id, min_lon, max_lon, min_lat, max_lat)")

rows = o.execute("SELECT rowid, sifko, parcela FROM owners").fetchall()
matched = missing = 0
upd, rt = [], []
for rowid, sifko, parcela in rows:
    box = boxes.get((sifko, parcela))
    if box is None:
        missing += 1
        continue
    mnlon, mxlon, mnlat, mxlat = box
    upd.append((mnlon, mxlon, mnlat, mxlat, rowid))
    rt.append((rowid, mnlon, mxlon, mnlat, mxlat))
    matched += 1
print(f"  matched {matched:,}  missing {missing:,}  ({time.time()-t0:.1f}s)", flush=True)

o.executemany("UPDATE owners SET min_lon=?, max_lon=?, min_lat=?, max_lat=? WHERE rowid=?", upd)
o.executemany("INSERT INTO owners_bbox(id, min_lon, max_lon, min_lat, max_lat) VALUES (?,?,?,?,?)", rt)
o.execute("CREATE INDEX IF NOT EXISTS idx_owners_lon ON owners(min_lon, max_lon)")
o.execute("CREATE INDEX IF NOT EXISTS idx_owners_lat ON owners(min_lat, max_lat)")
o.execute("INSERT OR REPLACE INTO meta(k,v) VALUES('bbox_crs','EPSG:4326 (reprojected from EPSG:3912 parcel rtree)')")
o.execute("INSERT OR REPLACE INTO meta(k,v) VALUES('bbox_matched', ?)", (str(matched),))
o.execute("INSERT OR REPLACE INTO meta(k,v) VALUES('bbox_missing', ?)", (str(missing),))
o.commit()
o.execute("PRAGMA wal_checkpoint(TRUNCATE)")
o.close()
print(f"done in {time.time()-t0:.1f}s -> {OWN}", flush=True)
