#!/usr/bin/env -S uv run --quiet --with pyshp --with pyproj --with defusedxml --with shapely python
"""Build a Croatian region parcels database from the open DGU ATOM feed.

The feed is anonymous and holds one zip of GML parcels per cadastral municipality (KO).
The output has the same schema as convert.py, so the app opens it like a Slovenian region.
Column sifko holds the KO matični broj, parcela the BROJ_CESTICE, area the m2 and eid the CESTICA_ID.
Run `./convert_hr.py list --region gorski-kotar` to see the selected KOs.
Run `./convert_hr.py build --region gorski-kotar -o work/regions --cache work/hr-cache` to build.
"""

from __future__ import annotations

import argparse
import io
import json
import os
import re
import sys
import time
import urllib.request
import zipfile
from concurrent.futures import ThreadPoolExecutor

from defusedxml import ElementTree as ET
from pyproj import Transformer

import convert  # same folder: blob encoder and sqlite writer

FEED_URL = "https://oss.uredjenazemlja.hr/oss/public/atom/atom_feed.xml"
SRC_CRS = "EPSG:3765"

GML = "{http://www.opengis.net/gml}"
OSS = "{http://oss}"

# Preset name -> (display name, inclusive ranges of KO matični broj).
# DGU numbers the KOs by cadastral office, then alphabetically.
# Check the result with `list` before you publish.
REGIONS: dict[str, tuple[str, list[tuple[int, int]]]] = {
    "gorski-kotar": (
        "Gorski kotar",
        [
            (304476, 304727),  # Delnice office
            (302694, 302759),  # Čabar, Gerovo, Goreči, Hrib, Plešce, Prezid
            (333352, 333484),  # Gomirje to Vrbovsko
        ],
    ),
}


# geoBoundaries ADM1 name -> (Croatian name, code). The codes extend regije.geojson.
COUNTIES = {
    "Osijek-Baranja": ("Osječko-baranjska", "os"),
    "Vukovar-Syrmia": ("Vukovarsko-srijemska", "vu"),
    "Brod-Posavina": ("Brodsko-posavska", "bp"),
    "Virovitica-Podravina": ("Virovitičko-podravska", "vp"),
    "Požega-Slavonia": ("Požeško-slavonska", "pz"),
    "Sisak-Moslavina": ("Sisačko-moslavačka", "sm"),
    "Bjelovar-Bilogora": ("Bjelovarsko-bilogorska", "bb"),
    "Međimurje": ("Međimurska", "me"),
    "Koprivnica-Križevci": ("Koprivničko-križevačka", "kc"),
    "Varaždin": ("Varaždinska", "vz"),
    "Krapina-Zagorje": ("Krapinsko-zagorska", "kz"),
    "City of Zagreb": ("Grad Zagreb", "zg"),
    "Zagreb County": ("Zagrebačka", "zc"),
    "Karlovac": ("Karlovačka", "ka"),
    "Istria": ("Istarska", "is"),
    "Primorje-Gorski Kotar": ("Primorsko-goranska", "pg"),
    "Lika-Senj": ("Ličko-senjska", "ls"),
    "Zadar County": ("Zadarska", "zd"),
    "Šibenik-Knin": ("Šibensko-kninska", "sk"),
    "Split-Dalmatia": ("Splitsko-dalmatinska", "sd"),
    "Dubrovnik-Neretva": ("Dubrovačko-neretvanska", "dn"),
}


class _Shape:
    """Small stand-in for a pyshp shape, as convert._encode_geometry expects."""

    def __init__(self, rings: list[list[tuple[float, float]]]):
        self.points: list[tuple[float, float]] = []
        self.parts: list[int] = []
        for ring in rings:
            self.parts.append(len(self.points))
            self.points.extend(ring)


def _get(url: str, retries: int = 4) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "gozdar-data-build/1.0"})
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return r.read()
        except Exception as e:  # noqa: BLE001 - retry on any network error
            if attempt == retries - 1:
                raise
            print(f"  retry {attempt + 1} after {e}", file=sys.stderr)
            time.sleep(2 * (attempt + 1))
    raise AssertionError("unreachable")


def fetch_feed(cache: str | None) -> tuple[str, dict[int, tuple[str, str]]]:
    """Return the feed date and {KO matični broj: (name, zip url)}."""
    if cache:
        os.makedirs(cache, exist_ok=True)
    path = os.path.join(cache, "atom_feed.xml") if cache else None
    if path and os.path.exists(path) and time.time() - os.path.getmtime(path) < 86400:
        data = open(path, "rb").read()
    else:
        data = _get(FEED_URL)
        if path:
            open(path, "wb").write(data)
    root = ET.fromstring(data)
    ns = "{http://www.w3.org/2005/Atom}"
    date = (root.findtext(f"{ns}updated") or "")[:10]
    kos: dict[int, tuple[str, str]] = {}
    for e in root.findall(f"{ns}entry"):
        title = e.findtext(f"{ns}title") or ""
        link = e.find(f"{ns}link")
        href = link.get("href", "") if link is not None else ""
        m = re.search(r"ko-(\d+)\.zip", href)
        if m:
            kos[int(m.group(1))] = (title.removeprefix("Cadastral municipality ").strip(), href)
    return date, kos


def select_kos(kos: dict, region: str | None, explicit: list[int]):
    if explicit:
        missing = [k for k in explicit if k not in kos]
        if missing:
            sys.exit(f"KO not in feed: {missing}")
        return "Hrvatska", sorted(explicit)
    if region not in REGIONS:
        sys.exit(f"Unknown region '{region}'. Known: {', '.join(REGIONS)}")
    name, ranges = REGIONS[region]
    return name, sorted(k for k in kos if any(lo <= k <= hi for lo, hi in ranges))


def _ko_zip(url: str, mbr: int, cache: str | None) -> zipfile.ZipFile:
    path = os.path.join(cache, f"ko-{mbr}.zip") if cache else None
    if path and os.path.exists(path):
        return zipfile.ZipFile(path)
    data = _get(url)
    if path:
        open(path, "wb").write(data)
    return zipfile.ZipFile(io.BytesIO(data))


def _coords(el) -> list[tuple[float, float]]:
    pts = []
    for pair in (el.findtext(f"{GML}coordinates") or "").split():
        x, y = pair.split(",")[:2]
        pts.append((float(x), float(y)))
    return pts


def parse_parcels(fh):
    """Yield (parcela, area, eid, rings) for each parcel in the GML."""
    for _, el in ET.iterparse(fh, events=("end",)):
        if el.tag != f"{OSS}CESTICE":
            continue
        rings = [p for p in (_coords(lr) for lr in el.iter(f"{GML}LinearRing")) if len(p) >= 4]
        try:
            area = float(el.findtext(f"{OSS}POVRSINA_GRAFICKA") or "")
        except ValueError:
            area = None
        parcela = (el.findtext(f"{OSS}BROJ_CESTICE") or "").strip()
        eid = (el.findtext(f"{OSS}CESTICA_ID") or "").strip() or None
        yield parcela, area, eid, rings
        el.clear()


def _hull(pts: list[tuple[float, float]]) -> list[tuple[float, float]]:
    """Convex hull (monotone chain) of lon/lat points."""
    pts = sorted(set(pts))
    if len(pts) < 3:
        return pts

    def half(seq):
        h: list[tuple[float, float]] = []
        for p in seq:
            while len(h) >= 2 and (
                (h[-1][0] - h[-2][0]) * (p[1] - h[-2][1])
                - (h[-1][1] - h[-2][1]) * (p[0] - h[-2][0]) <= 0
            ):
                h.pop()
            h.append(p)
        return h[:-1]

    return half(pts) + half(reversed(pts))


def _prefetch(kos: dict, cache: str) -> None:
    """Download every KO zip into the cache with a few parallel workers."""
    todo = [m for m in kos if not os.path.exists(os.path.join(cache, f"ko-{m}.zip"))]
    print(f"Prefetch: {len(todo)} of {len(kos)} zips missing", flush=True)

    def one(m):
        _ko_zip(kos[m][1], m, cache).close()

    done = 0
    with ThreadPoolExecutor(max_workers=6) as ex:
        for _ in ex.map(one, todo):
            done += 1
            if done % 200 == 0:
                print(f"  fetched {done}/{len(todo)}", flush=True)


def cmd_build_all(args):
    """Build one database per county for the whole feed, plus index files."""
    from shapely.geometry import MultiPoint, Polygon, mapping, shape
    from shapely.ops import unary_union

    os.makedirs(args.cache, exist_ok=True)
    os.makedirs(args.output, exist_ok=True)
    date, kos = fetch_feed(args.cache)
    _prefetch(kos, args.cache)
    gk_name, gk_ranges = REGIONS["gorski-kotar"]
    gk_ids = {k for k in kos if any(lo <= k <= hi for lo, hi in gk_ranges)}

    counties = json.load(open(args.counties, encoding="utf-8"))
    rindex = convert.RegionIndex(args.counties, "shapeName", "EPSG:4326")
    transform = Transformer.from_crs(SRC_CRS, convert.DST_CRS, always_xy=True).transform
    meta = [("schema", "1"), ("crs", "wgs84"), ("blob_version", str(convert.BLOB_VERSION)),
            ("source", "DGU DKP (HR)"), ("date", date)]
    writers: dict[str, convert._DbWriter] = {}
    ko_pts: dict[int, list[tuple[float, float]]] = {}
    ko_region: dict[int, str] = {}
    skipped = 0
    t0 = time.time()

    def writer_for(name):
        if name not in writers:
            path = os.path.join(args.output, f"parcels-{convert._slug(name)}.sqlite")
            if os.path.exists(path):
                os.remove(path)
            writers[name] = convert._DbWriter(path)
        return writers[name]

    for n, mbr in enumerate(sorted(kos), 1):
        ko_name, url = kos[mbr]
        z = _ko_zip(url, mbr, args.cache)
        w = None
        with z.open("katastarske_cestice.gml") as fh:
            for parcela, area, eid, rings in parse_parcels(fh):
                enc = convert._encode_geometry(_Shape(rings), transform) if rings else None
                if enc is None:
                    skipped += 1
                    continue
                blob, mnlon, mxlon, mnlat, mxlat = enc
                if w is None:
                    if mbr in gk_ids:
                        region = gk_name
                    else:
                        english = rindex.region_for((mnlon + mxlon) / 2, (mnlat + mxlat) / 2)
                        region = COUNTIES[english][0]
                    ko_region[mbr] = region
                    w = writer_for(region)
                w.add(mbr, parcela, area, eid, mnlat, mxlat, mnlon, mxlon, blob)
                ko_pts.setdefault(mbr, []).extend(
                    [(mnlon, mnlat), (mnlon, mxlat), (mxlon, mnlat), (mxlon, mxlat)])
        if n % 100 == 0:
            print(f"  {n}/{len(kos)} KOs, {sum(x.rows for x in writers.values()):,} parcels, "
                  f"{time.time() - t0:.0f}s", flush=True)

    for name, w in sorted(writers.items()):
        w.finalize(meta + [("region", name)])
        print(f"  {name}: {w.rows:,} parcels, {os.path.getsize(w.path) / 1e6:.0f} MB")
    print(f"Done: {sum(x.rows for x in writers.values()):,} parcels ({skipped:,} skipped)")

    index = [{"s": m, "n": kos[m][0],
              "r": [[[round(x * 1e5), round(y * 1e5)] for x, y in _hull(pts)]]}
             for m, pts in sorted(ko_pts.items())]
    with open(os.path.join(args.output, "ko_index_hr.json"), "w", encoding="utf-8") as fh:
        json.dump(index, fh, ensure_ascii=False, separators=(",", ":"))

    # Region polygons: simplified counties; Gorski kotar is cut out of its county.
    geoms = {}
    for f in counties["features"]:
        english = f["properties"]["shapeName"]
        geoms[english] = shape(f["geometry"]).simplify(0.003)
    gk_hull = MultiPoint([p for m in gk_ids if m in ko_pts for p in ko_pts[m]]).convex_hull
    pg = geoms["Primorje-Gorski Kotar"]
    gk_poly = gk_hull.intersection(pg)
    geoms["Primorje-Gorski Kotar"] = pg.difference(gk_poly)
    feats = []
    for english, g in geoms.items():
        name, code = COUNTIES[english]
        feats.append({"type": "Feature", "geometry": mapping(g.simplify(0.003)),
                      "properties": {"code": code, "name": name, "area": 0}})
    feats.append({"type": "Feature", "geometry": mapping(gk_poly.simplify(0.003)),
                  "properties": {"code": "gk", "name": gk_name, "area": 0}})
    with open(os.path.join(args.output, "regije_hr.json"), "w", encoding="utf-8") as fh:
        json.dump(feats, fh, ensure_ascii=False, separators=(",", ":"))
    print(f"Region polygons: {len(feats)}")


def cmd_list(args):
    date, kos = fetch_feed(args.cache)
    name, ids = select_kos(kos, args.region, args.ko)
    print(f"{name}: {len(ids)} KOs (feed updated {date})")
    for k in ids:
        print(f"  {k}  {kos[k][0]}")


def cmd_build(args):
    if args.cache:
        os.makedirs(args.cache, exist_ok=True)
    date, kos = fetch_feed(args.cache)
    name, ids = select_kos(kos, args.region, args.ko)
    os.makedirs(args.output, exist_ok=True)
    out = os.path.join(args.output, f"parcels-{convert._slug(name)}.sqlite")
    if os.path.exists(out):
        os.remove(out)
    print(f"{name}: {len(ids)} KOs, feed date {date} -> {out}")

    transform = Transformer.from_crs(SRC_CRS, convert.DST_CRS, always_xy=True).transform
    w = convert._DbWriter(out)
    skipped = 0
    ko_pts: dict[int, list[tuple[float, float]]] = {}
    for n, mbr in enumerate(ids, 1):
        ko_name, url = kos[mbr]
        z = _ko_zip(url, mbr, args.cache)
        before = w.rows
        with z.open("katastarske_cestice.gml") as fh:
            for parcela, area, eid, rings in parse_parcels(fh):
                enc = convert._encode_geometry(_Shape(rings), transform) if rings else None
                if enc is None:
                    skipped += 1
                    continue
                blob, mnlon, mxlon, mnlat, mxlat = enc
                w.add(mbr, parcela, area, eid, mnlat, mxlat, mnlon, mxlon, blob)
                ko_pts.setdefault(mbr, []).extend(
                    [(mnlon, mnlat), (mnlon, mxlat), (mxlon, mnlat), (mxlon, mxlat)])
        print(f"  [{n}/{len(ids)}] {mbr} {ko_name}: {w.rows - before:,} parcels", flush=True)

    w.finalize([
        ("schema", "1"), ("crs", "wgs84"), ("blob_version", str(convert.BLOB_VERSION)),
        ("source", "DGU DKP (HR)"), ("date", date), ("region", name),
    ])
    print(f"Done: {w.rows:,} parcels ({skipped:,} skipped), "
          f"{os.path.getsize(out) / 1e6:.1f} MB")

    if args.index_out:
        # KO entries in ko_index.json format, with a coarse hull as boundary.
        index = [{"s": mbr, "n": kos[mbr][0],
                  "r": [[[round(x * 1e5), round(y * 1e5)] for x, y in _hull(ko_pts[mbr])]]}
                 for mbr in ids if mbr in ko_pts]
        with open(args.index_out, "w", encoding="utf-8") as fh:
            json.dump(index, fh, ensure_ascii=False, separators=(",", ":"))
        print(f"KO index: {len(index)} KOs -> {args.index_out}")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    for cmd, fn in (("list", cmd_list), ("build", cmd_build)):
        p = sub.add_parser(cmd)
        p.add_argument("--region", default="gorski-kotar")
        p.add_argument("--ko", type=int, action="append", default=[],
                       help="KO matični broj (repeatable). Overrides --region.")
        p.add_argument("--cache", default=None, help="directory for downloads")
        if cmd == "build":
            p.add_argument("-o", "--output", required=True, help="output directory")
            p.add_argument("--index-out", default=None,
                           help="write KO names and hulls in ko_index.json format")
        p.set_defaults(func=fn)
    pa = sub.add_parser("build-all", help="every KO in the feed, one database per county")
    pa.add_argument("--counties", required=True,
                    help="geoBoundaries HRV ADM1 GeoJSON (shapeName property)")
    pa.add_argument("--cache", required=True, help="directory for downloads")
    pa.add_argument("-o", "--output", required=True, help="output directory")
    pa.set_defaults(func=cmd_build_all)
    args = ap.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
