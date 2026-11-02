import { decode as decodePng } from 'fast-png';
import jpeg from 'jpeg-js';
import proj4 from 'proj4';

proj4.defs(
  'EPSG:3794',
  '+proj=tmerc +lat_0=0 +lon_0=15 +k=0.9999 +x_0=500000 +y_0=-5000000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs +type=crs',
);

// Link preview image of a sečnja share. It shows a satellite crop with
// the cadastral lines, the shared parcel and the numbered trees.

export const PREVIEW_W = 1200;
export const PREVIEW_H = 630;

const R = 6378137;
const ESRI_EXPORT = 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/export';
const KATASTER_WMS = 'https://prostor.zgs.gov.si/geoserver/wms';

const KATASTER = [255, 255, 255, 0.75];
const PARCEL = [212, 165, 116, 1];
const TREE = [255, 87, 34, 1];
const WHITE = [255, 255, 255, 1];

const mercX = (lng) => (R * lng * Math.PI) / 180;
const mercY = (lat) => R * Math.log(Math.tan(Math.PI / 4 + (lat * Math.PI) / 360));
const lngOf = (x) => (x / R) * (180 / Math.PI);
const latOf = (y) => (2 * Math.atan(Math.exp(y / R)) - Math.PI / 2) * (180 / Math.PI);

// Web Mercator box around [lat, lng] pairs with a margin, in the shape of
// the preview image.
export function previewBox(coords) {
  const xs = coords.map(([, lng]) => mercX(lng));
  const ys = coords.map(([lat]) => mercY(lat));
  const cx = (Math.min(...xs) + Math.max(...xs)) / 2;
  const cy = (Math.min(...ys) + Math.max(...ys)) / 2;
  let w = Math.max(Math.max(...xs) - Math.min(...xs), 60) * 1.4;
  let h = Math.max(Math.max(...ys) - Math.min(...ys), 60) * 1.4;
  if (w / h > PREVIEW_W / PREVIEW_H) h = (w * PREVIEW_H) / PREVIEW_W;
  else w = (h * PREVIEW_W) / PREVIEW_H;
  return [cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2];
}

// Pixel of [lat, lng] in an image of the box.
export function toPixel([lat, lng], box) {
  const [x0, y0, x1, y1] = box;
  return [
    ((mercX(lng) - x0) / (x1 - x0)) * PREVIEW_W,
    ((y1 - mercY(lat)) / (y1 - y0)) * PREVIEW_H,
  ];
}

function blend(img, x, y, [r, g, b, a]) {
  x = Math.round(x);
  y = Math.round(y);
  if (x < 0 || y < 0 || x >= img.width || y >= img.height) return;
  const i = (y * img.width + x) * 4;
  img.data[i] = img.data[i] * (1 - a) + r * a;
  img.data[i + 1] = img.data[i + 1] * (1 - a) + g * a;
  img.data[i + 2] = img.data[i + 2] * (1 - a) + b * a;
}

export function fillDisc(img, cx, cy, radius, color) {
  for (let y = Math.floor(cy - radius); y <= Math.ceil(cy + radius); y++) {
    for (let x = Math.floor(cx - radius); x <= Math.ceil(cx + radius); x++) {
      if ((x - cx) ** 2 + (y - cy) ** 2 <= radius * radius) blend(img, x, y, color);
    }
  }
}

// A line of the given width. The loop paints each pixel once, so a
// see-through color stays even along the line.
export function drawLine(img, [ax, ay], [bx, by], width, color) {
  const half = width / 2;
  const minX = Math.floor(Math.min(ax, bx) - half);
  const maxX = Math.ceil(Math.max(ax, bx) + half);
  const minY = Math.floor(Math.min(ay, by) - half);
  const maxY = Math.ceil(Math.max(ay, by) + half);
  if (maxX < 0 || maxY < 0 || minX >= img.width || minY >= img.height) return;
  const dx = bx - ax;
  const dy = by - ay;
  const len2 = dx * dx + dy * dy || 1;
  for (let y = Math.max(0, minY); y <= Math.min(img.height - 1, maxY); y++) {
    for (let x = Math.max(0, minX); x <= Math.min(img.width - 1, maxX); x++) {
      const t = Math.max(0, Math.min(1, ((x - ax) * dx + (y - ay) * dy) / len2));
      const px = ax + t * dx - x;
      const py = ay + t * dy - y;
      if (px * px + py * py <= half * half) blend(img, x, y, color);
    }
  }
}

function drawRing(img, ring, width, color) {
  for (let i = 1; i < ring.length; i++) drawLine(img, ring[i - 1], ring[i], width, color);
}

// 3 by 5 digits, one row per string.
const DIGITS = [
  '111101101101111', '010110010010111', '111001111100111', '111001111001111', '101101111001001',
  '111100111001111', '111100111101111', '111001001001001', '111101111101111', '111101111001111',
];

function drawNumber(img, n, cx, cy, scale, color) {
  const text = String(n);
  const w = text.length * 4 * scale - scale;
  let left = cx - w / 2;
  for (const ch of text) {
    const bits = DIGITS[Number(ch)];
    for (let i = 0; i < 15; i++) {
      if (bits[i] !== '1') continue;
      const x0 = left + (i % 3) * scale;
      const y0 = cy - 2.5 * scale + Math.floor(i / 3) * scale;
      for (let y = 0; y < scale; y++) for (let x = 0; x < scale; x++) blend(img, x0 + x, y0 + y, color);
    }
    left += 4 * scale;
  }
}

// The cadastral layer the app shows, drawn over the image. The WMS
// works in EPSG:3794, so each image pixel maps to a pixel of that layer.
async function drawKataster(img, box, fetchFn) {
  const [x0, y0, x1, y1] = box;
  // Corners: top left, top right, bottom left, bottom right.
  const corners = [[x0, y1], [x1, y1], [x0, y0], [x1, y0]].map(([x, y]) =>
    proj4('EPSG:4326', 'EPSG:3794', [lngOf(x), latOf(y)]),
  );
  const minE = Math.min(...corners.map((c) => c[0]));
  const maxE = Math.max(...corners.map((c) => c[0]));
  const minN = Math.min(...corners.map((c) => c[1]));
  const maxN = Math.max(...corners.map((c) => c[1]));
  const sw = PREVIEW_W;
  const sh = Math.round((PREVIEW_W * (maxN - minN)) / (maxE - minE));
  const params = new URLSearchParams({
    SERVICE: 'WMS',
    VERSION: '1.1.1',
    REQUEST: 'GetMap',
    LAYERS: 'pregledovalnik:kn_parcele',
    STYLES: 'parcele',
    SRS: 'EPSG:3794',
    BBOX: [minE, minN, maxE, maxN].map((v) => v.toFixed(2)).join(','),
    WIDTH: String(sw),
    HEIGHT: String(sh),
    FORMAT: 'image/png',
    TRANSPARENT: 'true',
  });
  let layer;
  try {
    const res = await fetchFn(`${KATASTER_WMS}?${params}`, {
      headers: { 'User-Agent': 'Gozdar/1.0 (Cloudflare Worker)' },
    });
    if (!res.ok || !(res.headers.get('content-type') ?? '').startsWith('image/png')) return;
    layer = decodePng(new Uint8Array(await res.arrayBuffer()));
  } catch {
    // The preview still works without the cadastral lines.
    return;
  }
  if (layer.channels !== 4 || layer.width !== sw || layer.height !== sh) return;
  const [tl, tr, bl, br] = corners;
  const hits = new Uint8Array(PREVIEW_W * PREVIEW_H);
  for (let y = 0; y < PREVIEW_H; y++) {
    const v = y / PREVIEW_H;
    for (let x = 0; x < PREVIEW_W; x++) {
      const u = x / PREVIEW_W;
      // Bilinear between the corners. The box is small, so this is exact enough.
      const e = (1 - v) * ((1 - u) * tl[0] + u * tr[0]) + v * ((1 - u) * bl[0] + u * br[0]);
      const n = (1 - v) * ((1 - u) * tl[1] + u * tr[1]) + v * ((1 - u) * bl[1] + u * br[1]);
      const sx = Math.floor(((e - minE) / (maxE - minE)) * sw);
      const sy = Math.floor(((maxN - n) / (maxN - minN)) * sh);
      if (sx < 0 || sy < 0 || sx >= sw || sy >= sh) continue;
      if (layer.data[(sy * sw + sx) * 4 + 3] > 64) hits[y * PREVIEW_W + x] = 1;
    }
  }
  // The WMS lines are thin and red. Draw them 3 pixels wide in white.
  for (let y = 0; y < PREVIEW_H; y++) {
    for (let x = 0; x < PREVIEW_W; x++) {
      let near = false;
      for (let dy = -1; dy <= 1 && !near; dy++) {
        for (let dx = -1; dx <= 1 && !near; dx++) near = hits[(y + dy) * PREVIEW_W + x + dx] === 1;
      }
      if (near) blend(img, x, y, KATASTER);
    }
  }
}

// Renders the preview as JPEG bytes, or null when the share has no place.
export async function renderPreview({ parcel, points }, fetchFn = fetch) {
  const outline = (Array.isArray(parcel.polygon) ? parcel.polygon : []).filter(
    (p) => Array.isArray(p) && Number.isFinite(p[0]) && Number.isFinite(p[1]),
  );
  const coords = [...outline, ...points.map((p) => [p.lat, p.lng])];
  if (coords.length === 0) return null;
  const box = previewBox(coords);
  const query = new URLSearchParams({
    bbox: box.map((v) => v.toFixed(1)).join(','),
    bboxSR: '3857',
    imageSR: '3857',
    size: `${PREVIEW_W},${PREVIEW_H}`,
    format: 'jpg',
    f: 'image',
  });
  const satellite = await fetchFn(`${ESRI_EXPORT}?${query}`, {
    cf: { cacheTtl: 86400, cacheEverything: true },
  });
  if (!satellite.ok) throw new Error(`Satellite image failed: ${satellite.status}`);
  const img = jpeg.decode(new Uint8Array(await satellite.arrayBuffer()), { useTArray: true });
  if (img.width !== PREVIEW_W || img.height !== PREVIEW_H) {
    throw new Error(`Satellite image is ${img.width}x${img.height}`);
  }

  await drawKataster(img, box, fetchFn);
  if (outline.length > 2) {
    const ring = [...outline, outline[0]].map((p) => toPixel(p, box));
    drawRing(img, ring, 5, PARCEL);
  }
  points.forEach((p, i) => {
    const [x, y] = toPixel([p.lat, p.lng], box);
    fillDisc(img, x, y, 22, WHITE);
    fillDisc(img, x, y, 18, TREE);
    drawNumber(img, i + 1, x, y, i + 1 >= 10 ? 4 : 5, WHITE);
  });

  return new Uint8Array(jpeg.encode(img, 80).data);
}
