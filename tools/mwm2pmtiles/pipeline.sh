#!/usr/bin/env bash
# Full pipeline: dump both Slovenia halves -> ONE tippecanoe pass -> port style.
# Single-pass tiling (not per-half + tile-join): tile-join enforces its own
# 500 KB tile cap and silently drops oversized tiles, leaving gaps. One pass with
# --drop-densest/--extend-zooms keeps every area covered and tiles bounded.
#
# Run after build.sh. Idempotent. Stops before the R2 upload (publishing).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${HERE}"
export PATH="/opt/homebrew/bin:${PATH}"
WORK="${HERE}/work"
OM_DIR="${WORK}/organicmaps"
DRULES="${WORK}/drules_outdoors_light.txt"

BIN="$(find "${OM_DIR}/build-mwm-dump" -name mwm_dump -type f -perm -u+x 2>/dev/null | head -1)"
DATA_DIR="${OM_DIR}/data"
[[ -x "${BIN:-}" ]] || { echo "mwm_dump not built — run ./build.sh"; exit 1; }

echo ">> [1/4] dump East"
"${BIN}" "${WORK}/Slovenia_East.mwm" "${DATA_DIR}" > "${WORK}/Slovenia_East.geojsonl"
echo ">> [2/4] dump West"
"${BIN}" "${WORK}/Slovenia_West.mwm" "${DATA_DIR}" > "${WORK}/Slovenia_West.geojsonl"
wc -l "${WORK}/Slovenia_East.geojsonl" "${WORK}/Slovenia_West.geojsonl"

echo ">> [3/4] tile (single pass) -> slovenia.pmtiles"
tippecanoe \
  --force \
  --output="${WORK}/slovenia.pmtiles" \
  --minimum-zoom=4 \
  --maximum-zoom=16 \
  --drop-densest-as-needed \
  --extend-zooms-if-still-dropping \
  --coalesce-densest-as-needed \
  --simplification=4 \
  --maximum-tile-bytes=1000000 \
  --read-parallel \
  "${WORK}/Slovenia_East.geojsonl" "${WORK}/Slovenia_West.geojsonl"

echo ">> [4/4] port OM outdoors style"
[[ -f "${DRULES}" ]] || curl -sSLo "${DRULES}" \
  https://raw.githubusercontent.com/organicmaps/organicmaps/master/data/drules_proto_outdoors_light.txt
./port_style.py "${DRULES}" -o "${HERE}/gozdar_outdoors.style.json"

echo ""
echo ">> DONE"
ls -lh "${WORK}/slovenia.pmtiles" "${HERE}/gozdar_outdoors.style.json" 2>/dev/null | awk '{print "   "$5"  "$9}'
echo "   upload when ready: wrangler r2 object put gozdar-kataster/slovenia.pmtiles --file ${WORK}/slovenia.pmtiles"
