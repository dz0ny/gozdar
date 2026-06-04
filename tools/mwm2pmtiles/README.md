# `mwm → pmtiles` — Organic Maps data as flutter_map vector tiles

Converts an Organic Maps **`.mwm`** into a **vector PMTiles** file flutter_map
can render via `vector_map_tiles`, plus a **MapLibre style ported from OM's own
cartography**. You keep OM's exact dataset (processed OSM) and its look.

```
Slovenia_{East,West}.mwm ─(mwm_dump, OM C++ reader)─► features.geojsonl ─(tippecanoe)─► *.pmtiles ─► R2 ─► flutter_map
OM drules .txt ───────────(port_style.py)──────────► gozdar.style.json ─────────────────────────────────┘
```

## Why C++ (we tried the easy path first)

OM ships a **Python** `.mwm` reader (`tools/python/mwm`). It reads feature
**attributes** (types, names, metadata) but **not geometry** — `geometry()` is an
explicit stub for lines and areas, and point coords are read then discarded.
Verified on the real `Slovenia_West.mwm` (data version 260503): it iterates
features but emits no line/polygon geometry. Geometry lives only in OM's **C++**
`FeatureType` reader, so the dumper links OM's libs and is built in an OM checkout.

(The current data also bumped the features-section header to `DatSectionHeader`
**V2**; the C++ reader handles it natively. The stale Python reader rejects
anything but V0.)

## Files

| File             | Role                                                            |
|------------------|-----------------------------------------------------------------|
| `mwm_dump.cpp`   | OM C++ tool: every feature → one GeoJSON line (WGS84, OM types)  |
| `CMakeLists.txt` | builds `mwm_dump` in the OM tree (links `generator`)             |
| `build.sh`       | clone OM → drop tool in → build the `mwm_dump` target            |
| `convert.sh`     | `mwm_dump` → `tippecanoe` → `.pmtiles`                           |
| `port_style.py`  | OM drules `.txt` → MapLibre style JSON (fills + lines)           |
| `om_layers.py`   | shared OM-type → source-layer map (mirrors `LayerForType` in C++)|

Everything fetched/generated lives in `work/` (gitignored), like `tools/parcels`.

## 0. The Slovenia maps

Slovenia ships as **two** files: `Slovenia_East.mwm` + `Slovenia_West.mwm`
(grouped under "Slovenia" in `countries.json`). Current data version: `v=260503`.
Already downloaded into `work/` from OM's CDN:

```
https://cdn-us1.organicmaps.app/maps/260503/Slovenia_East.mwm   (155 MB)
https://cdn-us1.organicmaps.app/maps/260503/Slovenia_West.mwm   (127 MB)
```

(Server host comes from `https://meta.omaps.app/servers`; version from
`data/countries.json`'s `v`.)

> **Version coupling:** build `mwm_dump` from an OM ref near the `.mwm` data
> version. `260503` ⇒ a 2026.05+ ref. `OM_REF=<tag> ./build.sh` to pin.

## 1. Build the dumper  (heavy — first run pulls several GB)

```bash
cd tools/mwm2pmtiles
brew install cmake ninja tippecanoe        # macOS also needs Xcode CLT
./build.sh                                 # clone OM + build only mwm_dump
```

## 2. Convert each half

```bash
./convert.sh work/Slovenia_East.mwm        # -> work/Slovenia_East.pmtiles
./convert.sh work/Slovenia_West.mwm        # -> work/Slovenia_West.pmtiles
```

Merge the two into one Slovenia tileset with `tile-join` (ships with tippecanoe):

```bash
tile-join --force -o work/slovenia.pmtiles \
  work/Slovenia_East.pmtiles work/Slovenia_West.pmtiles
```

## 3. Style — ported from OM

PMTiles is data only; the look is a MapLibre **style JSON**, translated from OM's
own compiled drules (`data/drules_proto_<style>_<theme>.txt` — per-type/per-zoom
colors, widths, dashes, priorities). `outdoors_light` = terrain/hiking, best for
forestry.

```bash
curl -sSLo work/drules_outdoors_light.txt \
  https://raw.githubusercontent.com/organicmaps/organicmaps/master/data/drules_proto_outdoors_light.txt
./port_style.py work/drules_outdoors_light.txt -o gozdar_outdoors.style.json
```

Ported: `area`→fills, `lines`→lines (color, per-zoom width, dasharray, cap/join,
draw order by OM `priority`). Deferred (need extra infra): `caption`/`path_text`
labels (glyphs/font endpoint), `symbol`/`shield` icons (OM sprite atlas). Knobs
at the top of `port_style.py`: `WIDTH_SCALE`, `BACKGROUND`, `SOURCE`.

## 4. Host + render

```bash
wrangler r2 object put gozdar-kataster/slovenia.pmtiles --file work/slovenia.pmtiles
```

flutter_map side (deps: `vector_map_tiles`, `vector_map_tiles_pmtiles`):

```dart
final provider = await PmTilesVectorTileProvider.fromSource(
  'https://<your-r2-host>/slovenia.pmtiles',
);
VectorTileLayer(
  tileProviders: TileProviders({'gozdar': provider}),  // key must equal SOURCE
  theme: ThemeReader().read(jsonDecode(styleJson)),
  maximumZoom: 16,
)
```

Put it **below** your EPSG:3794 WMS overlays + parcel polygons.

## Geometry mapping (C++ reader)

| OM geom | dumped as   | note                                              |
|---------|-------------|---------------------------------------------------|
| point   | `Point`     | `GetCenter()`                                     |
| line    | `LineString`| `ParseGeometry` → `GetPoint(i)`                    |
| area    | `Polygon`   | outer-ring outline (clean; holes are separate features) |

## Caveats

- **OM types ≠ OSM tags.** Style against OM's classificator strings; the full
  vocabulary is `data/types.txt` in the checkout.
- `LayerForType` (C++) and `om_layers.py` must stay in sync — same mapping, two
  languages.
- For Slovenia, terrain (ARSO LiDAR hillshade/contours) and authoritative
  addresses (GURS RPE) beat `.mwm`; add them as separate layers.
- The build (`generator` dep) is large/slow. Style work (step 3) needs none of
  it — it only reads a drules `.txt`.
