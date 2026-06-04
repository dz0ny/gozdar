#!/usr/bin/env bash
# Convert an Organic Maps .mwm into a vector PMTiles file.
#
#   .mwm --(mwm_dump, OM C++ reader)--> features.geojsonl --(tippecanoe)--> out.pmtiles
#
# Prereqs:
#   - ./build.sh has been run (builds mwm_dump inside an OM checkout)
#   - tippecanoe >= 2.17 (writes .pmtiles directly)   brew install tippecanoe
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="${HERE}/work"
OM_DIR="${WORK}/organicmaps"

MWM="${1:?usage: ./convert.sh <path-to.mwm> [out.pmtiles]}"
OUT="${2:-${WORK}/$(basename "${MWM%.mwm}").pmtiles}"
GEOJSONL="${WORK}/$(basename "${MWM%.mwm}").geojsonl"

BIN="${MWM_DUMP_BIN:-$(find "${OM_DIR}/build-mwm-dump" -name mwm_dump -type f -perm -u+x 2>/dev/null | head -1)}"
DATA_DIR="${OM_DATA_DIR:-${OM_DIR}/data}"

[[ -x "${BIN:-}" ]] || { echo "mwm_dump not built — run ./build.sh first"; exit 1; }
[[ -d "${DATA_DIR}" ]] || { echo "OM data/ dir not found: ${DATA_DIR}"; exit 1; }
command -v tippecanoe >/dev/null || { echo "tippecanoe not found — brew install tippecanoe"; exit 1; }

echo ">> Dumping features (C++): ${MWM}"
"${BIN}" "${MWM}" "${DATA_DIR}" > "${GEOJSONL}"
wc -l < "${GEOJSONL}" | xargs echo ">> features:"

echo ">> Tiling -> ${OUT}"
# Per-feature tippecanoe.layer is set by the dumper, so no -l/-L here.
tippecanoe \
  --force \
  --output="${OUT}" \
  --minimum-zoom=4 \
  --maximum-zoom=16 \
  --drop-densest-as-needed \
  --extend-zooms-if-still-dropping \
  --coalesce-densest-as-needed \
  --simplification=4 \
  --maximum-tile-bytes=1000000 \
  --read-parallel \
  "${GEOJSONL}"

echo ""
echo ">> Done: ${OUT}"
echo "   Upload: wrangler r2 object put gozdar-kataster/$(basename "${OUT}") --file ${OUT}"
