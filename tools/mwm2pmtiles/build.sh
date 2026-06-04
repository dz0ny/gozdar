#!/usr/bin/env bash
# Build the mwm_dump tool inside an Organic Maps checkout.
#
# Needed because OM's Python reader decodes attributes only — geometry lives in
# OM's C++ FeatureType. Clones organicmaps, drops our tool in, wires it into the
# root CMake build, and compiles just the `mwm_dump` target.
#
# Heavy: the clone (+submodules) and the `generator` dependency are large. First
# run pulls several GB and takes a while. macOS needs Xcode CLT + cmake + ninja.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="${HERE}/work"
OM_DIR="${WORK}/organicmaps"
OM_REF="${OM_REF:-master}"   # pin near your .mwm data version (260503 -> a 2026.05+ ref)

mkdir -p "${WORK}"

if [[ ! -d "${OM_DIR}/.git" ]]; then
  echo ">> Cloning organicmaps (${OM_REF}) — large (submodules)…"
  git clone --branch "${OM_REF}" --depth 1 --recurse-submodules --shallow-submodules \
    https://github.com/organicmaps/organicmaps.git "${OM_DIR}"
  ( cd "${OM_DIR}" && ./configure.sh )
else
  echo ">> Reusing checkout at ${OM_DIR}"
fi

# Subdir name MUST differ from the executable name (mwm_dump): CMake's subdir
# build folder would otherwise collide with the output binary at the build root
# ("ld: open() failed, Is a directory").
echo ">> Installing mwm_dump into the OM tree (subdir: gozdar_mwmdump)"
rm -rf "${OM_DIR}/mwm_dump" "${OM_DIR}/gozdar_mwmdump"
mkdir -p "${OM_DIR}/gozdar_mwmdump"
cp "${HERE}/mwm_dump.cpp" "${HERE}/CMakeLists.txt" "${OM_DIR}/gozdar_mwmdump/"

sed -i '' '/add_subdirectory(mwm_dump)/d' "${OM_DIR}/CMakeLists.txt"   # drop stale wiring
if ! grep -q "add_subdirectory(gozdar_mwmdump)" "${OM_DIR}/CMakeLists.txt"; then
  printf '\nadd_subdirectory(gozdar_mwmdump)\n' >> "${OM_DIR}/CMakeLists.txt"
fi

# OM bug: the Qt version check reads Qt6Widgets_VERSION, but Widgets is only
# requested under `NOT SKIP_QT_GUI OR BUILD_TESTING` — with SKIP_QT_GUI=ON and no
# testing it's empty, so configure fatals. Qt6_VERSION is always set once Qt6
# Core is found. Idempotent.
sed -i '' 's/Qt6Widgets_VERSION/Qt6_VERSION/g' "${OM_DIR}/CMakeLists.txt"

echo ">> Configuring + building the mwm_dump target"
BUILD_DIR="${OM_DIR}/build-mwm-dump"
rm -rf "${BUILD_DIR}/mwm_dump"   # stale subdir build folder that collided with the binary
# OM's desktop build hard-requires Qt6 (the platform lib networks through Qt).
# Point CMake at Homebrew's qt. Keep BUILD_TESTING default-ON: OM only requests
# Qt6 Widgets under `NOT SKIP_QT_GUI OR BUILD_TESTING`, and its version check
# reads Qt6Widgets_VERSION — so Widgets must be requested or configure fails.
# SKIP_QT_GUI=ON still avoids Gui/Svg/OpenGL; --target mwm_dump never builds the
# test binaries regardless.
QT_PREFIX="${QT_PATH:-$(brew --prefix qt 2>/dev/null || echo /opt/homebrew/opt/qt)}"
cmake -S "${OM_DIR}" -B "${BUILD_DIR}" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DSKIP_TESTS=ON \
  -DSKIP_QT_GUI=ON \
  -DCMAKE_PREFIX_PATH="${QT_PREFIX}"
cmake --build "${BUILD_DIR}" --target mwm_dump

BIN="$(find "${BUILD_DIR}" -name mwm_dump -type f -perm -u+x | head -1)"
echo ""
echo ">> Built: ${BIN}"
echo ">> OM data/ resources: ${OM_DIR}/data"
echo ""
echo "Next: ./convert.sh work/Slovenia_West.mwm   (set MWM_DUMP_BIN/OM_DATA_DIR if needed)"
