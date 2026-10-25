#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Generate the ``regions.json`` manifest the app reads from R2
(``ParcelLookupService.fetchRegions``) from a directory of per-region
``parcels-<slug>.sqlite`` databases built by ``convert.py build --regions``.

Each entry carries the region ``code`` (from ``regije.geojson``), its display
``name`` (from the DB's ``meta.region``), the ``file`` name, size in ``bytes``
and the parcel ``rows`` count. Top-level ``date``/``source`` come from the
databases' ``meta`` table and use the most common value. A region that differs
(for example a Croatian one) gets its own ``date``/``source`` entry.

With ``--public-owners``, the public-owners DB's size and ``meta.built``
timestamp are added under ``public_owners`` so installed apps can tell when a
newer build is on R2 (``KatasterUpdateService``).

Usage:
    ./manifest.py work/regions -o work/regions/regions.json \
        [--regions regije.geojson] [--public-owners work/public_owners.sqlite]
"""

from __future__ import annotations

import argparse
import collections
import json
import sqlite3
import sys
from pathlib import Path


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("dir", help="directory holding parcels-*.sqlite")
    ap.add_argument("-o", "--out", default=None, help="output path (default: <dir>/regions.json)")
    ap.add_argument("--regions", default=str(Path(__file__).with_name("regije.geojson")),
                    help="GeoJSON with region 'code' + 'name' properties")
    ap.add_argument("--public-owners", default=None,
                    help="public_owners.sqlite to describe under 'public_owners'")
    args = ap.parse_args()

    d = Path(args.dir)
    out = Path(args.out) if args.out else d / "regions.json"
    geo = json.loads(Path(args.regions).read_text(encoding="utf-8"))
    code_by_name = {f["properties"]["name"]: f["properties"]["code"] for f in geo["features"]}

    entries, metas = [], []
    for f in sorted(d.glob("parcels-*.sqlite")):
        con = sqlite3.connect(f"file:{f}?mode=ro", uri=True)
        meta = dict(con.execute("SELECT k, v FROM meta"))
        rows = con.execute("SELECT COUNT(*) FROM parcels").fetchone()[0]
        con.close()
        name = meta.get("region")
        if not name:
            sys.exit(f"{f.name}: meta.region missing")
        code = code_by_name.get(name)
        if not code:
            sys.exit(f"{f.name}: region '{name}' not found in {args.regions}")
        if meta.get("rows") and int(meta["rows"]) != rows:
            sys.exit(f"{f.name}: meta.rows={meta['rows']} but COUNT(*)={rows}")
        metas.append((meta.get("date"), meta.get("source")))
        entries.append({"code": code, "name": name, "file": f.name,
                        "bytes": f.stat().st_size, "rows": rows})

    if not entries:
        sys.exit(f"No parcels-*.sqlite in {d}")
    top_date = collections.Counter(d for d, _ in metas).most_common(1)[0][0]
    top_source = collections.Counter(s for _, s in metas).most_common(1)[0][0]
    for entry, (date, source) in zip(entries, metas):
        if date != top_date:
            entry["date"] = date
        if source != top_source:
            entry["source"] = source
    entries.sort(key=lambda e: e["name"])
    manifest = {"date": top_date, "source": top_source, "regions": entries}
    if args.public_owners:
        po = Path(args.public_owners)
        con = sqlite3.connect(f"file:{po}?mode=ro", uri=True)
        meta = dict(con.execute("SELECT k, v FROM meta"))
        con.close()
        if not meta.get("built"):
            sys.exit(f"{po.name}: meta.built missing")
        manifest["public_owners"] = {"file": po.name, "bytes": po.stat().st_size,
                                     "built": meta["built"]}
    out.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    total = sum(e["bytes"] for e in entries)
    print(f"Wrote {out}: {len(entries)} regions, {sum(e['rows'] for e in entries):,} rows, "
          f"{total / 1e6:,.0f} MB, date {manifest['date']}")
    for e in entries:
        print(f"  {e['code']:2}  {e['name']:24} {e['rows']:>9,} rows  {e['bytes'] / 1e6:7.1f} MB")
    if "public_owners" in manifest:
        po = manifest["public_owners"]
        print(f"  public owners: {po['file']} built {po['built']} {po['bytes'] / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
