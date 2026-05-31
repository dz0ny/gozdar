#!/usr/bin/env bash
#
# Build a compact, indexed SQLite database of cadastral parcel owners from the
# GURS extract CSV, for import into the Gozdar app (hidden "Uvozi bazo lastnikov"
# option in the About screen).
#
# The CSV is a dev-machine artifact (~106 MB, 1.6M rows); the resulting
# owners.sqlite (~30-60 MB) is what you transfer to the device and import.
#
# Usage:
#   tool/build_owners_db.sh [input.csv] [output.sqlite]
#
# Defaults match the current extract on /Volumes/Disk.
set -euo pipefail

CSV="${1:-/Volumes/Disk/kataster_lastniki_SLO_owners_only.csv}"
OUT="${2:-owners.sqlite}"

if [[ ! -f "$CSV" ]]; then
  echo "error: input CSV not found: $CSV" >&2
  exit 1
fi

echo "Building $OUT from $CSV ..."
rm -f "$OUT"

# .import --csv understands RFC-4180 quoting, so owner names containing commas
# (which are quoted in the source) import into a single column correctly.
sqlite3 "$OUT" <<SQL
.mode csv
CREATE TABLE _raw(objectid,sifko,obcina,imeko,parcela,povrsina,naslov,lastnik);
.import --csv --skip 1 "$CSV" _raw

-- OBCINA (administrative municipality) is constant per cadastral municipality
-- (SIFKO) but only filled on ~7% of source rows. Build a per-KO map so it can
-- be backfilled onto every row.
CREATE TABLE _ko_obcina AS
  SELECT CAST(sifko AS INTEGER) AS sifko, MAX(TRIM(obcina)) AS obcina
  FROM _raw
  WHERE TRIM(obcina) <> ''
  GROUP BY CAST(sifko AS INTEGER);

CREATE TABLE owners AS
  SELECT DISTINCT
    CAST(r.sifko AS INTEGER) AS sifko,
    r.parcela,
    r.lastnik,
    r.naslov,
    r.imeko AS imeko,                                    -- cadastral KO name
    COALESCE(NULLIF(TRIM(r.obcina), ''), k.obcina) AS obcina  -- municipality
  FROM _raw r
  LEFT JOIN _ko_obcina k ON CAST(r.sifko AS INTEGER) = k.sifko
  WHERE TRIM(r.lastnik) <> '';
DROP TABLE _raw;
DROP TABLE _ko_obcina;

CREATE INDEX idx_owners ON owners(sifko, parcela);

CREATE TABLE meta(k TEXT PRIMARY KEY, v TEXT);
INSERT INTO meta(k, v) VALUES
  ('rows', (SELECT COUNT(*) FROM owners)),
  ('built', datetime('now'));

VACUUM;
SQL

ROWS=$(sqlite3 "$OUT" "SELECT v FROM meta WHERE k='rows'")
SIZE=$(du -h "$OUT" | cut -f1)
echo "Done: $OUT  ($ROWS owner rows, $SIZE)"
echo "Spot check (KO 1640, parcela 1799/89):"
sqlite3 "$OUT" "SELECT sifko, parcela, lastnik, naslov FROM owners WHERE sifko=1640 AND parcela='1799/89'"

# Optional: enrich with a rough per-parcel bounding box (WGS84) + R-tree so the
# app can resolve a tapped point -> owner OFFLINE. The CSV has no geometry, so
# this reads the Esri mobile geodatabase's R-tree spatial index. Needs python3
# (stdlib sqlite3 with the RTREE module) + `pip install pyproj`, and the
# extracted geodatabase. Skipped automatically when prerequisites are missing.
#   GDB=/Volumes/Disk/karta_slo.geodatabase   (override via env)
GDB="${GDB:-/Volumes/Disk/karta_slo.geodatabase}"
if [[ -f "$GDB" ]] && command -v python3 >/dev/null \
   && python3 -c 'import pyproj' >/dev/null 2>&1; then
  echo "Adding per-parcel bounding boxes from $GDB ..."
  python3 "$(dirname "$0")/add_owner_bbox.py" "$OUT" "$GDB"
else
  echo "Skipping bbox enrichment (need \$GDB geodatabase + python3 + pyproj)." >&2
  echo "  -> run later: python3 tool/add_owner_bbox.py $OUT <geodatabase>" >&2
fi
