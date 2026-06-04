"""Single source of truth: OM readable-type -> tippecanoe/MVT source-layer.

Used by both the dumper (mwm2geojson.py, to tag each feature) and the style
porter (port_style.py, to point each MapLibre layer at the right source-layer).
Keep them in sync by importing from here."""


def layer_for(t: str) -> str:
    """Map an OM readable type (e.g. 'natural-forest') to a source-layer."""
    head = t.split("-", 1)[0]
    if head in ("highway", "railway", "aeroway", "route", "aerialway"):
        return "transportation"
    if head == "building":
        return "building"
    if head == "waterway":
        return "water"
    if head == "isoline":
        return "contour"   # elevation contour lines — valued for forestry/terrain
    if head == "natural":
        if t.startswith(("natural-water", "natural-coastline")):
            return "water"
        if t.startswith(("natural-peak", "natural-volcano", "natural-saddle",
                         "natural-spring", "natural-cave")):
            return "poi"
        return "landcover"  # forest, wood, scrub, wetland, glacier, ...
    if head in ("landuse", "leisure"):
        return "landcover"
    if head == "place":
        return "place"
    if head == "boundary":
        return "boundary"
    if head in ("amenity", "shop", "tourism", "office", "historic",
                "man_made", "emergency"):
        return "poi"
    return "other"
