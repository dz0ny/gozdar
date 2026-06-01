# Offline parcels — `parcels.sqlite` converter

Converts the GURS **Kataster nepremičnin – Parcele** shapefile into a compact,
offline-queryable SQLite database for the app. Mirrors the design of the
existing `owners.sqlite` (a `meta` table, per-row bounding boxes, optional
R-tree), so the on-device `ParcelLookupService` can reuse the same patterns.

## Setup

None. The script is a [PEP 723](https://peps.python.org/pep-0723/) single-file
script — its dependencies are declared in the header and resolved on the fly by
[`uv`](https://docs.astral.sh/uv/). No venv, no `pip install`.

```bash
cd tools/parcels
./convert.py inspect /path/to/PARCELE.shp     # shebang runs `uv run --script`
# or explicitly:
uv run --script convert.py inspect /path/to/PARCELE.shp
```

## 1. Inspect the shapefile (map the columns)

The GURS attribute names have changed between releases, so check first:

```bash
./convert.py inspect /path/to/PARCELE.shp
```

It prints the geometry type, feature count, every field, an auto-detected
column mapping, and a few sample records. If the auto-detected KO / parcel /
area / owner fields look wrong, pass them explicitly in step 2.

## 2. Build the database

```bash
./convert.py build /path/to/PARCELE.shp -o parcels.sqlite \
    --source "GURS KN parcele" --date 2026-05-31
# override fields if needed (defaults match SI.GURS.KN:PARCELE):
#   --ko-field KO_ID --parc-field ST_PARCELE --area-field POVRSINA --eid-field EID_PARCELA
```

The geometry is reprojected from **EPSG:3794** (D96/TM) to **WGS84** and stored
as a small binary blob. The whole-Slovenia file streams, so memory stays flat.

## Mapping to the GURS `SI.GURS.KN:PARCELE` layer

| app column | GURS field    | notes                                          |
|------------|---------------|------------------------------------------------|
| `sifko`    | `KO_ID`       | cadastral municipality (matches owners.sqlite) |
| `parcela`  | `ST_PARCELE`  | composed parcel number, e.g. `1287/3`          |
| `area`     | `POVRSINA`    | m²                                             |
| `eid`      | `EID_PARCELA` | stable unique parcel key (owner-join key)      |
| geometry   | `GEOM`        | polygon, reprojected 3794 → WGS84              |

**Owners are intentionally not stored here.** PARCELE has no owner attribute —
owners (legal persons only) live in separate GURS tables (`OSEBE_PAR`, joined via
`IMETNIKI_LASTNISTVA_PAR` on `EID_PARCELA`). The app already resolves owners
offline from its `owners.sqlite` via `OwnerLookupService`, keyed on
(`sifko`, `parcela`). So `parcels.sqlite` (geometry) + `owners.sqlite` (owners)
together give the fully-offline experience.

> Verify after `inspect`: `KO_ID` sample values should be the 4-digit KO numbers
> (e.g. `1651` = BABNO POLJE) that `owners.sqlite` uses, and `ST_PARCELE` should
> look like `1287/3`. If `KO_ID` is a surrogate id instead of the KO šifra, say
> so — the lookup join would then need an extra KO mapping.

## Output schema

```sql
meta(k, v)                  -- schema, rows, crs=wgs84, blob_version, source, date, has_rtree
parcels(
  id, sifko, parcela, area, eid,
  min_lat, max_lat, min_lon, max_lon,
  poly BLOB
)
idx_parcels_ko  ON parcels(sifko, parcela)
idx_parcels_eid ON parcels(eid)
parcels_rtree   -- rtree(id, min_lon, max_lon, min_lat, max_lat), when available
```

### `poly` blob layout (little-endian) — keep in sync with the Dart decoder

```
u8   version (= 1)
u32  ringCount
repeat ringCount times:
  u32  pointCount
  repeat pointCount times:
    i32  lon_e7   (round(lon * 1e7))
    i32  lat_e7   (round(lat * 1e7))
```

`lon = lon_e7 / 1e7` gives ~1 cm precision. Rings are stored in shapefile order
(exterior + any interior rings); the renderer draws each as an outline.

## 3. Split by statistical region (recommended for delivery)

The whole-Slovenia DB is ~1.6 GB. Split it into the 12 statistical regions so
the app downloads only the user's region (39–219 MB each):

```bash
./convert.py build work/KN_SLO_PARCELE_SLO_PARCELE_poligon.shp -o work/regions \
  --eid-field EID_PARCEL --source "GURS KN parcele (SLO)" --date 2026-05-31 \
  --regions regije.geojson
```

- `regije.geojson` = Slovenia's 12 statistical regions (GURS RPE 2020, CC-BY),
  from sledilnik `statistical-regions-gurs-simplified.geojson`. Tracked in repo.
- Each parcel is assigned by its viewport-centre to the containing region; whole
  KOs stay together (first parcel of a KO fixes the region) and a nearest-region
  fallback covers border gaps in the simplified boundaries (→ 0 unassigned).
- Output: `work/regions/parcels-<slug>.sqlite` ×12, each carrying `meta.region`.

## 4. Upload to R2 + manifest

Generate a `regions.json` manifest (region → file, bytes, rows) and upload
everything to the `gozdar-kataster` R2 bucket (served at
`https://gozdar-kataster.dz0ny.dev`). Use **rclone** — `wrangler r2 object put`
caps at ~300 MiB (single PUT, no multipart):

```bash
# manifest (see the inline script in git history / regenerate from the *.sqlite meta)
# then:
rclone copy work/regions/ cloudflare:gozdar-kataster/ \
  --transfers 4 --s3-chunk-size 64M --s3-upload-concurrency 4
# owners DB:
rclone copyto owners.sqlite cloudflare:gozdar-kataster/owners.sqlite \
  --s3-chunk-size 64M
```

The `cloudflare:` rclone remote (S3/Cloudflare provider) holds the R2 API
credentials — it lives in the local rclone config, **never in this repo**.

## 5. In-app download

The about/developer screen downloads these straight from R2 into app storage:

- **Owners**: `OwnerLookupService.downloadAndOpen($base/owners.sqlite)`.
- **Parcels**: region picker reads `$base/regions.json`
  (`ParcelLookupService.fetchRegions`) and downloads the chosen
  `parcels-<slug>.sqlite` via `ParcelLookupService.downloadAndOpen`.

Both stream to a `.part` file and only swap the live DB in on success. A `.src`
marker records provenance (`imported` vs `downloaded`) so the dev panel can wipe
selectively. Owners are resolved from `owners.sqlite`; geometry from the region
DB — together they make the kataster fully offline.

## Notes

- **Privacy**: only **legal-person** (pravne osebe) owners are public in this
  dataset; natural-person owners are absent. Don't ship anything else.
- **Updates**: GURS refreshes weekly — re-run the build to refresh, bump the
  `--date`, re-upload, and update `regions.json`. Ship date-stamped data.
