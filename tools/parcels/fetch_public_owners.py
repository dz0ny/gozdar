#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Download the public GURS KN "Parcele za območje občine" packages for every
Slovenian municipality.

These per-municipality ZIPs carry the **public** subset of the cadastre — owners
that are legal entities (companies, the state, municipalities) and managers
(upravljavci). Natural persons are intentionally absent, so the result is freely
redistributable (CC-BY 4.0), unlike the private owners DB.

Source: JGP – Javni geodetski podatki (the same portal as the parcels shapefile).
The download is a two-step REST call discovered from the portal:

    1) GET .../groups/129/composite-products/7/file?filterParam=OBCINE&filterValue=<S>
       -> {"url": "<tokenised one-shot download link>"}
    2) GET <url>  -> the ZIP (0 bytes for a non-existent municipality)

Municipality codes (RPE občine šifre) are not contiguous, so we simply try a
range and keep whatever returns a non-empty, valid ZIP. Resumable: an already
downloaded, valid file is skipped.

Usage:
    ./fetch_public_owners.py [--out DIR] [--min 1] [--max 250] [--workers 6]
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.request
import zipfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

API = "https://ipi.eprostor.gov.si/jgp-service-api"
# group 129 = "Parcele in stavbe za območje občine", product 7 = "Parcele"
# (the descriptive-CSV package that contains owners + upravljavci).
FILE_EP = f"{API}/display-views/groups/129/composite-products/7/file"
UA = "gozdar-public-owners/1.0 (forestry app; data build)"
TIMEOUT = 120


def _get(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        return r.read()


def _download_one(sifra: int, out: Path, retries: int = 3) -> tuple[int, str, int]:
    """Return (sifra, status, bytes). status: ok | skip | empty | error."""
    target = out / f"KN_{sifra:03d}_parcele.zip"
    if target.exists() and target.stat().st_size > 0:
        # Validate the existing file is a real zip; re-fetch if truncated.
        try:
            with zipfile.ZipFile(target) as z:
                if z.testzip() is None:
                    return sifra, "skip", target.stat().st_size
        except zipfile.BadZipFile:
            pass

    last = ""
    for attempt in range(1, retries + 1):
        try:
            meta = json.loads(_get(f"{FILE_EP}?filterParam=OBCINE&filterValue={sifra}"))
            data = _get(meta["url"])
            if not data:
                return sifra, "empty", 0  # municipality code not in use
            # Verify it's a valid zip before committing to disk.
            tmp = target.with_suffix(".part")
            tmp.write_bytes(data)
            with zipfile.ZipFile(tmp) as z:
                if z.testzip() is not None:
                    raise zipfile.BadZipFile("crc mismatch")
            tmp.replace(target)
            return sifra, "ok", len(data)
        except Exception as e:  # noqa: BLE001 - report and retry
            last = str(e)
            time.sleep(1.5 * attempt)
    return sifra, f"error: {last}", 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", type=Path, default=Path("work/public_owners/raw"))
    ap.add_argument("--min", type=int, default=1)
    ap.add_argument("--max", type=int, default=250)
    ap.add_argument("--workers", type=int, default=6)
    args = ap.parse_args()

    args.out.mkdir(parents=True, exist_ok=True)
    codes = range(args.min, args.max + 1)
    ok = empty = skip = err = 0
    total_bytes = 0

    print(f"Fetching municipalities {args.min}..{args.max} -> {args.out} "
          f"({args.workers} workers)", flush=True)
    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        futs = {ex.submit(_download_one, s, args.out): s for s in codes}
        for fut in as_completed(futs):
            sifra, status, nbytes = fut.result()
            if status == "ok":
                ok += 1
                total_bytes += nbytes
                print(f"  [{sifra:3d}] ok    {nbytes/1_048_576:6.1f} MB", flush=True)
            elif status == "skip":
                skip += 1
                total_bytes += nbytes
            elif status == "empty":
                empty += 1
            else:
                err += 1
                print(f"  [{sifra:3d}] {status}", flush=True)

    print(f"\nDone: {ok} downloaded, {skip} already present, {empty} unused codes, "
          f"{err} errors. Total {total_bytes/1_048_576:.0f} MB in {args.out}")
    return 1 if err else 0


if __name__ == "__main__":
    sys.exit(main())
