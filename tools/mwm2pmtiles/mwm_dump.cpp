// mwm_dump — dump every feature of an Organic Maps .mwm to newline-delimited
// GeoJSON (one Feature per line), ready for `tippecanoe`.
//
// WHY C++: OM's in-tree *Python* reader (tools/python/mwm) decodes attributes
// only — geometry() is an explicit stub for lines and areas (verified on real
// Slovenia data). Geometry lives solely in OM's C++ FeatureType reader, so this
// tool builds INSIDE an organicmaps checkout (see build.sh) and links OM's libs.
//
// Output: GeoJSON-seq on stdout. Each line:
//   {"type":"Feature","tippecanoe":{"layer":"..."},"properties":{...},"geometry":{...}}
//
// Coordinates are converted from OM's Mercator to WGS84 lon/lat.
//
// API notes for the current (libs/-restructured) tree:
//   feature::ForEachFeature(path, fn)   // libs/indexer/feature_processor.hpp
//                                       // fn = (FeatureType &, uint32_t)
//   feature::TypesHolder(ft)            // libs/indexer/feature_data.hpp
//   classif().GetReadableObjectName(t)  // libs/indexer/classificator.hpp
//   ft.GetGeomType()/GetCenter()/ParseGeometry()/GetPointsCount()/GetPoint()
//                                       // libs/indexer/feature.hpp

#include "indexer/classificator.hpp"
#include "indexer/classificator_loader.hpp"
#include "indexer/feature.hpp"
#include "indexer/feature_data.hpp"        // feature::TypesHolder
#include "indexer/feature_processor.hpp"   // feature::ForEachFeature
#include "indexer/scales.hpp"              // scales::GetUpperScale

#include "geometry/mercator.hpp"
#include "geometry/point2d.hpp"

#include "platform/platform.hpp"

#include <cstdio>
#include <cstdint>
#include <string>
#include <vector>

namespace
{
std::string JsonEscape(std::string const & s)
{
  std::string out;
  out.reserve(s.size() + 8);
  for (char const c : s)
  {
    switch (c)
    {
    case '"': out += "\\\""; break;
    case '\\': out += "\\\\"; break;
    case '\n': out += "\\n"; break;
    case '\r': out += "\\r"; break;
    case '\t': out += "\\t"; break;
    default:
      if (static_cast<unsigned char>(c) < 0x20)
      {
        char buf[8];
        std::snprintf(buf, sizeof(buf), "\\u%04x", c);
        out += buf;
      }
      else
        out += c;
    }
  }
  return out;
}

// Coarse tippecanoe layer from the first OM readable type. MUST stay in sync
// with om_layers.py (same mapping). Tune freely — the style keys on this.
std::string LayerForType(std::string const & t)
{
  auto const dash = t.find('-');
  std::string const head = dash == std::string::npos ? t : t.substr(0, dash);

  if (head == "highway" || head == "railway" || head == "aeroway" ||
      head == "route" || head == "aerialway")
    return "transportation";
  if (head == "building")
    return "building";
  if (head == "waterway")
    return "water";
  if (head == "isoline")
    return "contour";   // elevation contour lines — valued for forestry/terrain
  if (head == "natural")
  {
    if (t.rfind("natural-water", 0) == 0 || t.rfind("natural-coastline", 0) == 0)
      return "water";
    if (t.rfind("natural-peak", 0) == 0 || t.rfind("natural-volcano", 0) == 0 ||
        t.rfind("natural-saddle", 0) == 0 || t.rfind("natural-spring", 0) == 0 ||
        t.rfind("natural-cave", 0) == 0)
      return "poi";
    return "landcover";
  }
  if (head == "landuse" || head == "leisure")
    return "landcover";
  if (head == "place")
    return "place";
  if (head == "boundary")
    return "boundary";
  if (head == "amenity" || head == "shop" || head == "tourism" ||
      head == "office" || head == "historic" || head == "man_made" ||
      head == "emergency")
    return "poi";
  return "other";
}

// Per-feature minimum zoom, matching OM's drules so we don't store geometry the
// style never draws. Contours (isolines) dominate the byte budget and OM only
// draws fine steps when zoomed in — stamping minzoom here ~halves the tileset
// and stops dense low-zoom contours from crowding out other features.
int MinZoomForType(std::string const & t)
{
  if (t.rfind("isoline-", 0) != 0)
    return -1;  // no constraint
  if (t == "isoline-step_10" || t == "isoline-zero")
    return 15;
  if (t == "isoline-step_50")
    return 13;
  if (t == "isoline-step_100")
    return 11;
  if (t == "isoline-step_500" || t == "isoline-step_1000")
    return 10;
  return 11;  // any other isoline step
}

std::string PtJson(m2::PointD const & merc)
{
  char buf[64];
  std::snprintf(buf, sizeof(buf), "[%.6f,%.6f]",
                mercator::XToLon(merc.x), mercator::YToLat(merc.y));
  return buf;
}

void EmitFeature(std::string const & geomType, std::string const & coordsJson,
                 std::vector<std::string> const & types,
                 std::string const & name, std::string const & houseNumber)
{
  if (coordsJson.empty() || types.empty())
    return;

  std::string out = "{\"type\":\"Feature\",\"tippecanoe\":{\"layer\":\"";
  out += LayerForType(types.front());
  out += '"';
  int const minZoom = MinZoomForType(types.front());
  if (minZoom >= 0)
  {
    out += ",\"minzoom\":";
    out += std::to_string(minZoom);
  }
  out += "},\"properties\":{\"t\":[";
  for (size_t i = 0; i < types.size(); ++i)
  {
    if (i) out += ',';
    out += '"'; out += JsonEscape(types[i]); out += '"';
  }
  out += ']';
  if (!name.empty())        { out += ",\"name\":\""; out += JsonEscape(name); out += '"'; }
  if (!houseNumber.empty()) { out += ",\"housenumber\":\""; out += JsonEscape(houseNumber); out += '"'; }
  out += "},\"geometry\":{\"type\":\"";
  out += geomType;
  out += "\",\"coordinates\":";
  out += coordsJson;
  out += "}}\n";
  std::fputs(out.c_str(), stdout);
}
}  // namespace

int main(int argc, char ** argv)
{
  if (argc < 3)
  {
    std::fprintf(stderr,
                 "usage: %s <path-to.mwm> <OM-resources-dir (the data/ folder)>\n"
                 "  writes newline-delimited GeoJSON to stdout.\n", argv[0]);
    return 2;
  }
  std::string const mwmPath = argv[1];
  std::string const dataDir = argv[2];

  Platform & platform = GetPlatform();
  platform.SetResourceDir(dataDir);
  classificator::Load();
  Classificator const & c = classif();

  int const scale = scales::GetUpperScale();  // most detailed geometry
  uint64_t emitted = 0;

  feature::ForEachFeature(mwmPath, [&](FeatureType & ft, uint32_t /*index*/) {
    std::vector<std::string> types;
    feature::TypesHolder th(ft);
    for (uint32_t const t : th)
      types.push_back(c.GetReadableObjectName(t));
    if (types.empty())
      return;

    // OM encodes road attributes (surface, foot/lit/oneway access) as separate
    // overlapping features with no draw rules — non-renderable, but ~67% of
    // output bytes. Skip them.
    std::string const & t0 = types.front();
    if (t0.rfind("hwtag-", 0) == 0 || t0.rfind("psurface-", 0) == 0 ||
        t0.rfind("sponsored-", 0) == 0 || t0.rfind("internet_access", 0) == 0)
      return;

    std::string const name{ft.GetReadableName()};  // 0-arg → string_view
    std::string const houseNumber = ft.GetHouseNumber();

    switch (ft.GetGeomType())
    {
    case feature::GeomType::Point:
      EmitFeature("Point", PtJson(ft.GetCenter()), types, name, houseNumber);
      break;

    case feature::GeomType::Line:
    {
      ft.ParseGeometry(scale);
      size_t const n = ft.GetPointsCount();
      if (n < 2) break;
      std::string coords = "[";
      for (size_t i = 0; i < n; ++i)
      { if (i) coords += ','; coords += PtJson(ft.GetPoint(i)); }
      coords += ']';
      EmitFeature("LineString", coords, types, name, houseNumber);
      break;
    }

    case feature::GeomType::Area:
    {
      // Outer-ring outline (clean polygon; OM keeps holes/multipolygons as
      // separate features). Triangles are available via GetTrianglesAsPoints
      // if a triangulated fill is ever preferred.
      ft.ParseGeometry(scale);
      size_t const n = ft.GetPointsCount();
      if (n < 3) break;
      std::string ring = "[";
      for (size_t i = 0; i < n; ++i)
      { if (i) ring += ','; ring += PtJson(ft.GetPoint(i)); }
      ring += ','; ring += PtJson(ft.GetPoint(0));  // close ring
      ring += ']';
      EmitFeature("Polygon", "[" + ring + "]", types, name, houseNumber);
      break;
    }
    default: break;
    }
    ++emitted;
  });

  std::fprintf(stderr, "mwm_dump: emitted %llu features from %s\n",
               static_cast<unsigned long long>(emitted), mwmPath.c_str());
  return 0;
}
