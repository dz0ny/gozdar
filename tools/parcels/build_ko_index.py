#!/usr/bin/env python3
"""Build assets/ko_index.json: every katastrska občina (KO) with its code,
name and a coarse outer boundary, for offline "which KO is this point in" and
KO-name autocomplete in the parcel search.

Source: GURS layer pregledovalnik:KN_KATASTRSKE_OBCINE on prostor.zgs.gov.si.
Format: [{"s": SIFKO, "n": NAZIV, "r": [[[lon*1e5, lat*1e5], ...], ...]}]
(outer rings only, Douglas-Peucker at ~50 m, ~2 MB).

Usage: ./build_ko_index.py [../../assets/ko_index.json]
"""
import json, math, os, sys, urllib.request

URL = ("https://prostor.zgs.gov.si/geoserver/wfs?service=WFS&version=1.1.0"
       "&request=GetFeature&typeName=pregledovalnik:KN_KATASTRSKE_OBCINE"
       "&outputFormat=application/json&srsName=EPSG:4326")
TOLERANCE = 0.0005  # degrees


def rdp(pts, eps):
    if len(pts) < 3:
        return pts
    keep = [False] * len(pts)
    keep[0] = keep[-1] = True
    stack = [(0, len(pts) - 1)]
    while stack:
        s, e = stack.pop()
        if e <= s + 1:
            continue
        ax, ay = pts[s]
        bx, by = pts[e]
        dx, dy = bx - ax, by - ay
        length = math.hypot(dx, dy)
        far, idx = -1.0, -1
        for i in range(s + 1, e):
            px, py = pts[i]
            d = (abs(dy * px - dx * py + bx * ay - by * ax) / length
                 if length else math.hypot(px - ax, py - ay))
            if d > far:
                far, idx = d, i
        if far > eps:
            keep[idx] = True
            stack += [(s, idx), (idx, e)]
    return [p for p, k in zip(pts, keep) if k]


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else "../../assets/ko_index.json"
    req = urllib.request.Request(URL, headers={"User-Agent": "gozdar-data-build/1.0"})
    data = json.load(urllib.request.urlopen(req, timeout=300))
    out = []
    for f in data["features"]:
        p, g = f["properties"], f["geometry"]
        polys = [g["coordinates"]] if g["type"] == "Polygon" else g["coordinates"]
        rings = []
        for poly in polys:
            ring = rdp(poly[0], TOLERANCE)
            if len(ring) >= 4:
                rings.append([[round(x * 1e5), round(y * 1e5)] for x, y in ring])
        out.append({"s": p["SIFKO"], "n": p["NAZIV"], "r": rings})
    hr_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ko_index_hr.json")
    if os.path.exists(hr_path):
        with open(hr_path, encoding="utf-8") as fh:
            out += json.load(fh)
    out.sort(key=lambda k: k["s"])
    with open(out_path, "w", encoding="utf-8") as fh:
        json.dump(out, fh, ensure_ascii=False, separators=(",", ":"))
    print(f"{len(out)} KOs -> {out_path}")


if __name__ == "__main__":
    main()
