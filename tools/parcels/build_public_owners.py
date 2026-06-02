#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Build a redistributable ``public_owners.sqlite`` from the per-municipality
GURS KN "Parcele" packages fetched by ``fetch_public_owners.py``.

Only the **public** cadastre subset is present in those packages: owners that are
legal entities (companies, the state, municipalities) and managers (upravljavci).
Natural persons are absent at source, so the output is freely redistributable.

Owner/manager names repeat heavily (most parcels are owned by the state, the
Sklad, SiDG or a municipality), so names are normalised into their own table to
keep the embedded asset small. ``vloga`` distinguishes owner ('L') from
manager/upravljavec ('U'); the (sifko, parcela) index matches the private DB's
lookup key:

    names(id INTEGER PRIMARY KEY, naziv TEXT)
    owners(sifko INTEGER, parcela TEXT, name_id INTEGER, vloga TEXT)
    INDEX owners(sifko, parcela)

Join chain per municipality ZIP:
    parcele.dbf      EID_PARCEL -> (KO_ID, ST_PARCELE)
    osebe_par.csv    OSEBA_ID   -> NAZIV          (legal entities, TIP=2)
    imetniki_*.csv   EID_PARCELA + OSEBA_ID       -> owner
    upravljavci_parc EID via x_parcele, UPRAVLJAVEC_ID -> NAZIV
    upravljavci_x_parcele.csv  EID_PARCELA + UPRAVLJAVEC_ID -> manager

Usage:
    ./build_public_owners.py [--raw work/public_owners/raw] [--out work/public_owners.sqlite]
"""

from __future__ import annotations

import argparse
import csv
import io
import sqlite3
import struct
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path


# ---- minimal DBF reader (no third-party deps) ----------------------------

def read_dbf(data: bytes):
    """Yield dict rows from a .dbf byte buffer (C/N/D fields, latin chars)."""
    hdr = data[:32]
    hsize = struct.unpack("<H", hdr[8:10])[0]
    nfields = (hsize - 33) // 32
    fields = []
    pos = 32
    for _ in range(nfields):
        fd = data[pos:pos + 32]
        name = fd[:11].split(b"\x00")[0].decode("ascii", "replace")
        ftype = chr(fd[11])
        flen = fd[16]
        fields.append((name, ftype, flen))
        pos += 32
    # terminator byte (0x0D) then records
    rec_start = hsize
    rlen = 1 + sum(f[2] for f in fields)
    n = struct.unpack("<I", hdr[4:8])[0]
    off = rec_start
    for _ in range(n):
        rec = data[off:off + rlen]
        off += rlen
        if not rec or rec[:1] == b"*":  # deleted record
            continue
        o = 1
        row = {}
        for name, _t, ln in fields:
            row[name] = rec[o:o + ln].decode("utf-8", "replace").strip()
            o += ln
        yield row


# ---- helpers -------------------------------------------------------------

def _find(names, *needles):
    for n in names:
        low = n.lower()
        if all(x in low for x in needles):
            return n
    return None


def _open_csv(z: zipfile.ZipFile, name: str):
    return csv.DictReader(io.TextIOWrapper(z.open(name), encoding="utf-8-sig"))


def process_zip(path: Path, rows: set):
    """Extract owner/manager rows from one municipality package into ``rows``
    (a set of (sifko, parcela, lastnik, naslov, vloga) tuples)."""
    with zipfile.ZipFile(path) as z:
        names = z.namelist()

        # 1) EID_PARCEL -> (KO_ID, ST_PARCELE) from the nested parcele shapefile.
        eid2kp: dict[str, tuple[int, str]] = {}
        inner = _find(names, "parcele_", ".zip") or _find(names, "_parcele", ".zip")
        if inner:
            with zipfile.ZipFile(io.BytesIO(z.read(inner))) as iz:
                dbf = _find(iz.namelist(), "poligon", ".dbf") or _find(iz.namelist(), ".dbf")
                if dbf:
                    for r in read_dbf(iz.read(dbf)):
                        eid = r.get("EID_PARCEL") or r.get("EID_PARCELA")
                        ko = r.get("KO_ID")
                        st = r.get("ST_PARCELE")
                        if eid and ko and st:
                            try:
                                eid2kp[eid] = (int(ko), st)
                            except ValueError:
                                pass
        if not eid2kp:
            return  # cannot map parcels without the geometry table

        # 2) legal-entity owner names: OSEBA_ID -> NAZIV (TIP=2).
        osebe: dict[str, str] = {}
        f = _find(names, "osebe_par")
        if f:
            for r in _open_csv(z, f):
                if (r.get("TIP") or "").strip() == "2":
                    nz = (r.get("NAZIV") or "").strip()
                    if nz:
                        osebe[r["OSEBA_ID"]] = nz

        # 3) parcel a right refers to: PRAVICA_LASTNISTVA_ID -> EID_PARCELA.
        #    (imetniki rows carry the right id, not the parcel directly.)
        pravica2eid: dict[str, str] = {}
        f = _find(names, "pravice_lastnistva")
        if f:
            for r in _open_csv(z, f):
                if (r.get("DATUM_IZBRISA") or "").strip():
                    continue
                eid = (r.get("EID_PARCELA") or "").strip()
                if eid:
                    pravica2eid[(r.get("PRAVICA_LASTNISTVA_ID") or "").strip()] = eid

        # 4) owner links: legal-entity OSEBA_ID -> parcel via the right (or a
        #    direct EID_PARCELA fallback). Skip deleted and non-legal persons.
        f = _find(names, "imetniki_lastnistva")
        if f:
            for r in _open_csv(z, f):
                if (r.get("DATUM_IZBRISA") or "").strip():
                    continue
                naziv = osebe.get((r.get("OSEBA_ID") or "").strip())
                if not naziv:
                    continue
                eid = pravica2eid.get((r.get("PRAVICA_LASTNISTVA_ID") or "").strip()) \
                    or (r.get("EID_PARCELA") or "").strip()
                kp = eid2kp.get(eid)
                if kp:
                    rows.add((kp[0], kp[1], naziv, "L"))

        # 5) managers: UPRAVLJAVEC_ID -> NAZIV.
        upr: dict[str, str] = {}
        f = _find(names, "upravljavci_parc")
        if f:
            for r in _open_csv(z, f):
                nz = (r.get("NAZIV") or "").strip()
                if nz:
                    upr[r["UPRAVLJAVEC_ID"]] = nz

        # 6) manager links: EID_PARCELA + UPRAVLJAVEC_ID.
        f = _find(names, "upravljavci_x_parcele")
        if f:
            for r in _open_csv(z, f):
                eid = (r.get("EID_PARCELA") or "").strip()
                naziv = upr.get((r.get("UPRAVLJAVEC_ID") or "").strip())
                kp = eid2kp.get(eid)
                if eid and naziv and kp:
                    rows.add((kp[0], kp[1], naziv, "U"))


def build(raw: Path, out: Path) -> int:
    zips = sorted(raw.glob("KN_*_parcele.zip"))
    if not zips:
        print(f"No packages found in {raw}", file=sys.stderr)
        return 1

    rows: set = set()
    for i, zp in enumerate(zips, 1):
        try:
            process_zip(zp, rows)
        except Exception as e:  # noqa: BLE001
            print(f"  ! {zp.name}: {e}", file=sys.stderr)
        if i % 25 == 0 or i == len(zips):
            print(f"  {i}/{len(zips)} packages, {len(rows):,} rows so far", flush=True)

    # Normalise names: assign each distinct owner/manager name an integer id.
    name_id: dict[str, int] = {}
    for (_s, _p, naziv, _v) in rows:
        if naziv not in name_id:
            name_id[naziv] = len(name_id) + 1

    if out.exists():
        out.unlink()
    db = sqlite3.connect(out)
    db.executescript(
        """
        PRAGMA journal_mode=DELETE;
        CREATE TABLE names(
          id    INTEGER PRIMARY KEY,
          naziv TEXT NOT NULL
        );
        CREATE TABLE owners(
          sifko   INTEGER NOT NULL,
          parcela TEXT    NOT NULL,
          name_id INTEGER NOT NULL,        -- -> names.id
          vloga   TEXT    NOT NULL         -- 'L' owner, 'U' manager (upravljavec)
        );
        CREATE TABLE meta(k TEXT PRIMARY KEY, v TEXT);
        """
    )
    db.executemany(
        "INSERT INTO names(id, naziv) VALUES(?,?)",
        [(i, n) for (n, i) in name_id.items()],
    )
    db.executemany(
        "INSERT INTO owners(sifko, parcela, name_id, vloga) VALUES(?,?,?,?)",
        [(s, p, name_id[n], v) for (s, p, n, v) in rows],
    )
    db.execute("CREATE INDEX idx_owners_key ON owners(sifko, parcela)")
    db.execute("INSERT INTO meta(k,v) VALUES('rows',?)", (str(len(rows)),))
    db.execute("INSERT INTO meta(k,v) VALUES('names',?)", (str(len(name_id)),))
    db.execute(
        "INSERT INTO meta(k,v) VALUES('built',?)",
        (datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),),
    )
    db.execute("INSERT INTO meta(k,v) VALUES('source','GURS KN public (legal entities + upravljavci), CC-BY 4.0')")
    db.commit()
    db.execute("VACUUM")
    db.execute("ANALYZE")
    db.commit()

    n_owner = db.execute("SELECT COUNT(*) FROM owners WHERE vloga='L'").fetchone()[0]
    n_mgr = db.execute("SELECT COUNT(*) FROM owners WHERE vloga='U'").fetchone()[0]
    db.close()
    mb = out.stat().st_size / 1_048_576
    print(f"\nWrote {out} — {len(rows):,} rows ({n_owner:,} owner, {n_mgr:,} manager), "
          f"{len(name_id):,} names, {mb:.1f} MB")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--raw", type=Path, default=Path("work/public_owners/raw"))
    ap.add_argument("--out", type=Path, default=Path("work/public_owners.sqlite"))
    args = ap.parse_args()
    return build(args.raw, args.out)


if __name__ == "__main__":
    sys.exit(main())
