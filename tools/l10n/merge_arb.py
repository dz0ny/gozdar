#!/usr/bin/env python3
"""Merge lib/l10n/parts/<group>.{sl,hr}.json into app_sl.arb / app_hr.arb.

Parts: <group>.sl.json holds full ARB entries (message + "@key" metadata);
<group>.hr.json holds only key -> Croatian message. Fails on duplicate keys,
keys missing in hr, or placeholder mismatch between sl and hr.
Run: python3 tools/l10n/merge_arb.py && flutter gen-l10n
"""
import json, re, sys
from pathlib import Path

root = Path(__file__).resolve().parents[2] / "lib" / "l10n"
parts = root / "parts"
sl, hr, errors = {"@@locale": "sl", "appTitle": "Gozdar"}, {"@@locale": "hr", "appTitle": "Gozdar"}, []

def load(p):
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception as e:
        errors.append(f"{p.name}: invalid JSON ({e})")
        return {}

ph = lambda s: sorted(set(re.findall(r"\{(\w+)[,}]", s)))
for f in sorted(parts.glob("*.sl.json")):
    group = f.name[: -len(".sl.json")]
    s, h = load(f), load(parts / f"{group}.hr.json")
    for k, v in s.items():
        if k in sl:
            errors.append(f"duplicate key {k} ({group})")
        sl[k] = v
    for k, v in s.items():
        if k.startswith("@"):
            continue
        if k not in h:
            errors.append(f"{group}: {k} missing in hr")
            continue
        if ph(v) != ph(h[k]):
            errors.append(f"{group}: {k} placeholders differ {ph(v)} vs {ph(h[k])}")
        hr[k] = h[k]
    for k in h:
        if k not in s:
            errors.append(f"{group}: {k} in hr but not in sl")
if errors:
    print("\n".join(errors)); sys.exit(1)
for name, d in (("app_sl.arb", sl), ("app_hr.arb", hr)):
    (root / name).write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"merged {len([k for k in sl if not k.startswith('@')])} keys")
