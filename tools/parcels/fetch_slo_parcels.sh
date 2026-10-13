#!/bin/sh
# Download the whole-Slovenia GURS KN "Parcele za območje Slovenije" package
# from the JGP portal (group 122 "Graphical and attribute data on land parcels",
# composite product 25, filter DRZAVA=1) and extract the parcels shapefile.
#
# The portal hands out a tokenised one-shot download URL (same two-step REST
# call as fetch_public_owners.py). The outer ZIP (~1.5 GB) bundles many CSVs;
# the shapefile sits in the nested KN_SLO_PARCELE_SLO_parcele_<date>.zip.
#
# Usage: ./fetch_slo_parcels.sh [work/slo]
# Result: <dir>/shp/KN_SLO_PARCELE_SLO_PARCELE_poligon.shp  (+ .dbf/.shx/.prj)
set -e
OUT=${1:-work/slo}
mkdir -p "$OUT"
cd "$OUT"
UA="gozdar-data-build/1.0 (forestry app; data build)"
API="https://ipi.eprostor.gov.si/jgp-service-api/display-views/groups/122/composite-products/25/file"
if [ ! -s parcele_slo.zip ]; then
  URL=$(curl -sf -A "$UA" "$API?filterParam=DRZAVA&filterValue=1&format=shape" \
    | python3 -I -c 'import sys,json;print(json.load(sys.stdin)["url"])')
  echo "downloading whole-Slovenia parcels package ($(date +%T))"
  curl -fL --retry 3 -A "$UA" -o parcele_slo.zip.part "$URL"
  mv parcele_slo.zip.part parcele_slo.zip
fi
unzip -t -q parcele_slo.zip
INNER=$(unzip -Z1 parcele_slo.zip | grep -E '^KN_SLO_PARCELE_SLO_parcele_[0-9]{8}\.zip$')
unzip -o -q parcele_slo.zip "$INNER"
rm -rf shp && unzip -o -q "$INNER" -d shp
echo "data date (from package name): $(echo "$INNER" | grep -oE '[0-9]{8}')"
ls -l shp
