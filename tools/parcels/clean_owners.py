#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Clean an imported owners SQLite (lastnik/naslov/imeko/obcina):

- Repair the GURS encoding mojibake where an UPPERCASE accented letter became
  '?' + a hint char (e.g. "JASI?ć" -> "JASIĆ").
- Strip leading zeros from house numbers in addresses ("ROVTE 063" -> "ROVTE 63").

Keeps the same logic as lib/services/owner_lookup_service.dart so DB cleanup and
runtime display agree. Writes to a NEW file (input left untouched).

Usage:
  ./clean_owners.py owners.sqlite work/owners_clean.sqlite
"""

import re
import shutil
import sqlite3
import sys

# '?' + hint char  ->  correct uppercase letter.
ENC_MAP = {
    "?ć": "Ć",  # ?ć -> Ć
    "?î": "Č",  # ?î -> Č
    "?á": "Š",  # ?á -> Š
    "?Ż": "Ž",  # ?Ż -> Ž
    "?É": "Đ",  # ?É -> Đ
    "?ä": "Ä",  # ?ä -> Ä
    "?ë": "É",  # ?ë -> É
    "?ö": "Ô",  # ?ö -> Ô
    "?ü": "Ü",  # ?ü -> Ü
    "?ľ": "Ü",  # ?ľ -> Ü
    "?ť": "Ü",  # ?ť -> Ü
    "?č": "ß",  # ?č -> ß
}
_STRAY = re.compile(r"\?(?=[^\x00-\x7F])")        # stray '?' before non-ASCII
_LEADING_ZERO = re.compile(r"(?<![\w.])0+(\d)")   # 097 -> 97


def repair_encoding(s):
    if s is None or "?" not in s:
        return s
    for bad, good in ENC_MAP.items():
        s = s.replace(bad, good)
    return _STRAY.sub("", s)


def clean_name(s):
    return repair_encoding(s)


def clean_addr(s):
    s = repair_encoding(s)
    if s:
        s = _LEADING_ZERO.sub(lambda m: m.group(1), s)
    return s


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: clean_owners.py <input.sqlite> <output.sqlite>")
    src, dst = sys.argv[1], sys.argv[2]
    shutil.copyfile(src, dst)

    db = sqlite3.connect(dst)
    db.create_function("clean_name", 1, clean_name, deterministic=True)
    db.create_function("clean_addr", 1, clean_addr, deterministic=True)

    before = db.execute(
        "SELECT COUNT(*) FROM owners WHERE lastnik LIKE '%?%' "
        "OR naslov LIKE '%?%' OR imeko LIKE '%?%' OR obcina LIKE '%?%'"
    ).fetchone()[0]

    db.execute(
        "UPDATE owners SET "
        "lastnik = clean_name(lastnik), "
        "naslov  = clean_addr(naslov), "
        "imeko   = clean_addr(imeko), "
        "obcina  = clean_addr(obcina)"
    )
    db.commit()

    after = db.execute(
        "SELECT COUNT(*) FROM owners WHERE lastnik LIKE '%?%' "
        "OR naslov LIKE '%?%' OR imeko LIKE '%?%' OR obcina LIKE '%?%'"
    ).fetchone()[0]

    db.execute("VACUUM")
    db.close()
    print(f"Rows with '?' before: {before:,}  after: {after:,}")
    print(f"Cleaned -> {dst}")


if __name__ == "__main__":
    main()
