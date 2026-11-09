#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Build ``addresses.sqlite`` for the offline address search.

The database holds every Slovenian house number with its street, settlement
and post office. ``AddressLookupService`` in the app reads it.

Source: GURS Register prostorskih enot, CC-BY 4.0. The JGP portal refuses
non-browser clients from some networks. The default inputs are therefore the
mirror at https://github.com/stefanb/gurs-rpe, which refreshes weekly.

Inputs from the mirror's ``data/`` folder:
    HS.csv  house numbers: WGS84 point, number, EIDs (weekly)
    NA.csv  settlement names (NA_MID, NA_UIME, OB_MID)
    UL.csv  street names (UL_MID, UL_UIME, NA_MID)
    PT.csv  post offices (PT_MID, PT_ID, PT_UIME)
    OB.csv  municipality names (OB_MID, OB_UIME)

The house numbers carry new GURS EIDs. The name tables use old MIDs. An EID
embeds its MID: ``1103 00000 10116309 9`` is prefix, pad, MID, check digit.
So ``MID = int(EID[:-1]) % 10**8`` joins them.

The mirror refreshes the names by hand, so they lag behind the numbers. A
house on an unknown street keeps ``street_id`` NULL. The app then shows it
as "<settlement> <number>".

Output tables (keep in sync with lib/services/address_lookup_service.dart):
    meta(k, v): schema=1, rows, built, date, names_date, source, licence
    municipalities(id, name)
    posts(id, code, name)
    settlements(id, name, municipality_id)
    streets(id, name, settlement_id)
    addresses(id, number, street_id, settlement_id, post_id, lat_e7, lon_e7,
              building), indexed on (settlement_id, number) and
              (street_id, number)

All ``id`` columns are GURS MIDs. ``building`` is the building MID
(EID_STAVBA) for a later join with the building cadastre. ``number`` is the
house number with an upper-case letter suffix ("12", "12A").

Usage:
    ./build_addresses.py [-o work/addresses.sqlite] [--raw DIR]
        [--hs HS.csv --na NA.csv --ul UL.csv --pt PT.csv --ob OB.csv]
        [--names-date 2024-02-21]
"""

from __future__ import annotations

import argparse
import csv
import os
import sqlite3
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

MIRROR = "https://raw.githubusercontent.com/stefanb/gurs-rpe/master/data/"
FILES = ("HS", "NA", "UL", "PT", "OB")
UA = "gozdar-data-build/1.0 (forestry app; data build)"
SOURCE = "GURS RPE naslovi (CC-BY 4.0) via github.com/stefanb/gurs-rpe"
LICENCE = "CC-BY 4.0 Geodetska uprava Republike Slovenije"

SCHEMA = [
    "PRAGMA page_size = 4096",
    "CREATE TABLE meta (k TEXT PRIMARY KEY, v TEXT)",
    "CREATE TABLE municipalities (id INTEGER PRIMARY KEY, name TEXT NOT NULL)",
    "CREATE TABLE posts (id INTEGER PRIMARY KEY, code INTEGER NOT NULL, name TEXT NOT NULL)",
    "CREATE TABLE settlements (id INTEGER PRIMARY KEY, name TEXT NOT NULL, municipality_id INTEGER)",
    "CREATE TABLE streets (id INTEGER PRIMARY KEY, name TEXT NOT NULL, settlement_id INTEGER)",
    "CREATE TABLE addresses (id INTEGER PRIMARY KEY, number TEXT NOT NULL, street_id INTEGER,"
    " settlement_id INTEGER NOT NULL, post_id INTEGER, lat_e7 INTEGER NOT NULL,"
    " lon_e7 INTEGER NOT NULL, building INTEGER)",
]


def mid(eid: str) -> int | None:
    """Return the old GURS MID that the EID embeds, or None for an empty value."""
    eid = eid.strip()
    if not eid:
        return None
    return int(eid[:-1]) % 10**8


def fetch(name: str, raw: Path) -> Path:
    """Return ``<raw>/<name>.csv``. Download it from the mirror when it is missing."""
    raw.mkdir(parents=True, exist_ok=True)
    target = raw / f"{name}.csv"
    if target.exists() and target.stat().st_size > 0:
        return target
    url = f"{MIRROR}{name}.csv"
    print(f"downloading {url}", flush=True)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    tmp = target.with_suffix(".part")
    with urllib.request.urlopen(req, timeout=300) as r, tmp.open("wb") as f:
        while chunk := r.read(1 << 20):
            f.write(chunk)
    tmp.replace(target)
    return target


def rows(path: Path):
    """Yield the CSV rows of ``path`` as dicts."""
    with path.open(encoding="utf-8-sig", newline="") as f:
        yield from csv.DictReader(f)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("-o", "--out", default="work/addresses.sqlite")
    ap.add_argument("--raw", default="work/addresses/raw",
                    help="download cache for the mirror CSVs")
    for name in FILES:
        ap.add_argument(f"--{name.lower()}", default=None,
                        help=f"local {name}.csv instead of the mirror copy")
    ap.add_argument("--names-date", default=None,
                    help="data date of the name tables (ISO), stored in meta")
    args = ap.parse_args()

    raw = Path(args.raw)
    paths = {n: Path(getattr(args, n.lower()) or fetch(n, raw)) for n in FILES}

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    if out.exists():
        out.unlink()
    db = sqlite3.connect(out)
    for stmt in SCHEMA:
        db.execute(stmt)

    ob = {int(r["OB_MID"]): r["OB_UIME"] for r in rows(paths["OB"])}
    pt = {int(r["PT_MID"]): (int(r["PT_ID"]), r["PT_UIME"]) for r in rows(paths["PT"])}
    na = {int(r["NA_MID"]): (r["NA_UIME"], int(r["OB_MID"])) for r in rows(paths["NA"])}
    ul = {int(r["UL_MID"]): (r["UL_UIME"], int(r["NA_MID"])) for r in rows(paths["UL"])}
    db.executemany("INSERT INTO municipalities VALUES (?, ?)", ob.items())
    db.executemany("INSERT INTO posts VALUES (?, ?, ?)",
                   ((k, c, n) for k, (c, n) in pt.items()))
    db.executemany("INSERT INTO settlements VALUES (?, ?, ?)",
                   ((k, n, o) for k, (n, o) in na.items()))
    db.executemany("INSERT INTO streets VALUES (?, ?, ?)",
                   ((k, n, s) for k, (n, s) in ul.items()))

    count = unknown_streets = unknown_settlements = 0
    newest = ""
    batch = []
    insert = "INSERT OR REPLACE INTO addresses VALUES (?,?,?,?,?,?,?,?)"
    for r in rows(paths["HS"]):
        hs = mid(r["EID_HISNA_STEVILKA"])
        settlement = mid(r["EID_NASELJE"])
        if hs is None or settlement is None:
            continue
        if settlement not in na:
            unknown_settlements += 1
            continue
        street = mid(r["EID_ULICA"])
        if street is not None and street not in ul:
            unknown_streets += 1
            street = None
        post = mid(r["EID_POSTNI_OKOLIS"])
        if post not in pt:
            post = None
        number = f"{r['HS_STEVILKA'].strip()}{r['HS_DODATEK'].strip().upper()}"
        if not number:
            continue
        newest = max(newest, r.get("DATUM_SYS", "")[:10])
        batch.append((hs, number, street, settlement, post,
                      round(float(r["Y"]) * 1e7), round(float(r["X"]) * 1e7),
                      mid(r["EID_STAVBA"])))
        count += 1
        if len(batch) >= 50_000:
            db.executemany(insert, batch)
            batch.clear()
    if batch:
        db.executemany(insert, batch)

    db.execute("CREATE INDEX idx_addr_settlement ON addresses(settlement_id, number)")
    db.execute("CREATE INDEX idx_addr_street ON addresses(street_id, number)")
    meta = {
        "schema": "1",
        "rows": str(count),
        "built": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "date": newest or None,
        "names_date": args.names_date,
        "source": SOURCE,
        "licence": LICENCE,
    }
    db.executemany("INSERT INTO meta VALUES (?, ?)",
                   ((k, v) for k, v in meta.items() if v is not None))
    db.commit()
    db.execute("VACUUM")
    db.close()

    size = os.path.getsize(out) / 1e6
    print(f"Wrote {out}: {count:,} addresses, {len(na):,} settlements, "
          f"{len(ul):,} streets, {len(pt):,} post offices, {size:.1f} MB")
    print(f"  newest house-number change {newest}; names dated {args.names_date or '?'}")
    if unknown_streets or unknown_settlements:
        print(f"  {unknown_streets:,} houses on streets the name tables do not know "
              f"(kept without a street), {unknown_settlements:,} in unknown settlements "
              f"(dropped)", file=sys.stderr)


if __name__ == "__main__":
    main()
