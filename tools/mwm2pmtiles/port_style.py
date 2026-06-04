#!/usr/bin/env python3
"""Port an Organic Maps drules style -> a MapLibre GL style JSON.

OM's cartography lives in `data/drules_proto_<style>_<theme>.txt` — the COMPILED,
resolved draw rules (per type, per zoom), in protobuf TextFormat. That's far
easier to port than re-interpreting the MapCSS cascade: every rule is already
flattened to a concrete color / width / priority at a concrete zoom.

This translates the **area** (fills) and **lines** rules into MapLibre layers,
keyed to the source-layers our dumper emits and filtered on the per-feature `t`
(OM type) array. The result reproduces OM's *look* for polygons + lines.

Deferred (phase 2 — need extra infra, not just JSON):
  - caption / path_text  -> text labels   (need a glyphs/font endpoint)
  - symbol / shield      -> POI icons      (need OM's sprite atlas)

Usage:
  ./port_style.py work/drules_outdoors_light.txt -o gozdar_outdoors.style.json
  # download a drules file first, e.g.:
  #   curl -sSLo work/drules_outdoors_light.txt \\
  #     https://raw.githubusercontent.com/organicmaps/organicmaps/master/data/drules_proto_outdoors_light.txt
"""
import argparse
import json
import sys

from om_layers import layer_for

# OM line widths are in px at visualScale 1; bump so roads aren't hairlines.
WIDTH_SCALE = 1.6
# Approximate map background for the outdoors-light theme (engine constant, not
# in drules). Tune to taste; under WMS overlays it's rarely visible.
BACKGROUND = "#f4f1ea"
SOURCE = "gozdar"   # must match the vector_map_tiles provider key

CAP = {"BUTTCAP": "butt", "ROUNDCAP": "round", "SQUARECAP": "square"}
JOIN = {"BEVELJOIN": "bevel", "ROUNDJOIN": "round", "MITERJOIN": "miter"}


# --------------------------------------------------------------------------- #
# protobuf TextFormat parser (the files are pretty-printed, one token per line)
# --------------------------------------------------------------------------- #
def parse_textproto(path):
    """Parse pretty-printed TextFormat into nested dicts. Repeated fields become
    lists. Good enough for OM's drules dumps (one field/brace per line)."""
    root = {}
    stack = [root]

    def put(d, key, val):
        if key in d:
            if not isinstance(d[key], list):
                d[key] = [d[key]]
            d[key].append(val)
        else:
            d[key] = val

    with open(path, encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            if line == "}":
                stack.pop()
                continue
            if line.endswith("{"):                       # "key {"
                key = line[:-1].strip()
                child = {}
                put(stack[-1], key, child)
                # put() may have wrapped into a list; descend into the object
                # we just appended.
                cur = stack[-1][key]
                stack.append(cur[-1] if isinstance(cur, list) else cur)
                continue
            if ":" in line:                              # "key: value"
                key, _, val = line.partition(":")
                put(stack[-1], key.strip(), _coerce(val.strip()))
    return root


def _coerce(v):
    if v.startswith('"') and v.endswith('"'):
        return v[1:-1]
    try:
        return int(v)
    except ValueError:
        pass
    try:
        return float(v)
    except ValueError:
        return v          # bare enum identifier (BEVELJOIN, ...)


def as_list(x):
    if x is None:
        return []
    return x if isinstance(x, list) else [x]


# --------------------------------------------------------------------------- #
# color helpers
# --------------------------------------------------------------------------- #
def color_rgba(v):
    """OM color int -> (#rrggbb, alpha 0..1). Opaque colors are stored 24-bit
    (<= 0xFFFFFF); wider values carry alpha in the top byte (0xAARRGGBB)."""
    v = int(v)
    if v > 0xFFFFFF:
        a = (v >> 24) & 0xFF
        rgb = v & 0xFFFFFF
        return f"#{rgb:06x}", round(a / 255, 3)
    return f"#{v:06x}", 1.0


def zoom_expr(stops, default):
    """stops: list of (zoom, value). Constant -> the value; else an interpolate
    expression. Used for width/opacity; for colors we use a step expression."""
    vals = {v for _, v in stops}
    if len(vals) <= 1:
        return stops[0][1] if stops else default
    expr = ["interpolate", ["linear"], ["zoom"]]
    for z, val in sorted(stops):
        expr += [z, val]
    return expr


def color_expr(stops, default):
    """stops: list of (zoom, '#hex'). Constant -> hex; else a step expression."""
    vals = {c for _, c in stops}
    if len(vals) <= 1:
        return stops[0][1] if stops else default
    stops = sorted(stops)
    expr = ["step", ["zoom"], stops[0][1]]
    for z, c in stops[1:]:
        expr += [z, c]
    return expr


# --------------------------------------------------------------------------- #
# build MapLibre layers from drules conts
# --------------------------------------------------------------------------- #
def build_layers(conts):
    fills, lines = [], []

    for cont in conts:
        name = cont.get("name")
        if not name:
            continue
        src_layer = layer_for(name)
        type_filter = ["in", name, ["get", "t"]]

        area_stops_c, area_stops_o, area_prio = [], [], []
        line_w, line_c, line_o, line_prio = [], [], [], []
        line_dash = None
        line_cap = line_join = None

        for el in as_list(cont.get("element")):
            scale = el.get("scale")
            if scale is None:
                continue

            area = el.get("area")
            if isinstance(area, dict):
                col, alpha = color_rgba(area.get("color", 0))
                area_stops_c.append((scale, col))
                area_stops_o.append((scale, alpha))
                area_prio.append(area.get("priority", 0))

            ln = el.get("lines")
            # a type can have multiple line rules (e.g. casing); take the first
            ln = as_list(ln)[0] if ln else None
            if isinstance(ln, dict):
                col, alpha = color_rgba(ln.get("color", 0))
                line_w.append((scale, round(float(ln.get("width", 1)) * WIDTH_SCALE, 2)))
                line_c.append((scale, col))
                line_o.append((scale, alpha))
                line_prio.append(ln.get("priority", 0))
                if "dashdot" in ln and line_dash is None:
                    dd = [float(x) for x in as_list(ln["dashdot"].get("dd"))]
                    if dd:
                        line_dash = dd
                line_cap = line_cap or CAP.get(ln.get("cap"))
                line_join = line_join or JOIN.get(ln.get("join"))

        if area_stops_c:
            zs = [s for s, _ in area_stops_c]
            paint = {
                "fill-color": color_expr(area_stops_c, "#cccccc"),
                "fill-antialias": False,
            }
            op = zoom_expr(area_stops_o, 1.0)
            if op != 1.0:
                paint["fill-opacity"] = op
            fills.append({
                "_prio": max(area_prio) if area_prio else 0,
                "id": f"area/{name}",
                "type": "fill",
                "source": SOURCE,
                "source-layer": src_layer,
                "filter": type_filter,
                "minzoom": min(zs),
                "paint": paint,
            })

        if line_w:
            zs = [s for s, _ in line_w]
            paint = {
                "line-color": color_expr(line_c, "#888888"),
                "line-width": zoom_expr(line_w, 1.0),
            }
            op = zoom_expr(line_o, 1.0)
            if op != 1.0:
                paint["line-opacity"] = op
            if line_dash:
                paint["line-dasharray"] = line_dash
            layout = {}
            if line_cap:
                layout["line-cap"] = line_cap
            if line_join:
                layout["line-join"] = line_join
            lines.append({
                "_prio": max(line_prio) if line_prio else 0,
                "id": f"line/{name}",
                "type": "line",
                "source": SOURCE,
                "source-layer": src_layer,
                "filter": type_filter,
                "minzoom": min(zs),
                **({"layout": layout} if layout else {}),
                "paint": paint,
            })

    # OM: higher priority renders on top. MapLibre: later in the array is on top.
    # Fills below lines; within each, sort by priority ascending.
    fills.sort(key=lambda l: l["_prio"])
    lines.sort(key=lambda l: l["_prio"])
    ordered = fills + lines
    for l in ordered:
        l.pop("_prio", None)
    return ordered


def main():
    ap = argparse.ArgumentParser(description="OM drules -> MapLibre style JSON")
    ap.add_argument("drules", help="path to drules_proto_<style>_<theme>.txt")
    ap.add_argument("-o", "--out", default="gozdar.style.json")
    ap.add_argument("--name", default="Gozdar (Organic Maps port)")
    args = ap.parse_args()

    root = parse_textproto(args.drules)
    conts = as_list(root.get("cont"))
    sys.stderr.write(f"parsed {len(conts)} type containers\n")

    layers = build_layers(conts)
    n_fill = sum(1 for l in layers if l["type"] == "fill")
    n_line = sum(1 for l in layers if l["type"] == "line")

    style = {
        "version": 8,
        "name": args.name,
        "sources": {
            SOURCE: {"type": "vector"}   # provided at runtime by vector_map_tiles
        },
        "layers": [
            {"id": "background", "type": "background",
             "paint": {"background-color": BACKGROUND}},
            *layers,
        ],
    }

    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(style, f, ensure_ascii=False, indent=1)
    sys.stderr.write(f"wrote {args.out}: {n_fill} fill + {n_line} line layers\n")


if __name__ == "__main__":
    main()
