import { Hono } from 'hono';
import { ICON_PNG } from './icon.js';

// Sečnja share links. The owner uploads the marked trees of one parcel.
// The logger gets https://gozdar.dz0ny.dev/o/<id>, and the link opens Gozdar.
// Without the app, the same address shows a landing page with an Uvozi button.
// KV keeps each share for 30 days after the last upload.

const TTL_SECONDS = 30 * 24 * 3600;
const MAX_BYTES = 262144;
const ID_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

// Fingerprints of the keys that sign the Android app: the key of the
// GitHub release APKs (read from v2026.1031.2) and the local debug key.
const ANDROID_SHA256 = [
  '1D:6A:FE:1B:3A:FA:68:86:E4:58:59:02:BD:95:4E:F8:F0:51:FF:A9:6F:99:A6:6A:E9:7E:3D:94:AC:C4:98:75',
  '85:69:C5:31:8C:05:13:3D:2B:11:D5:07:E4:6C:BE:DB:06:B4:08:EE:DC:ED:44:77:E5:0B:C5:1E:EA:AA:E0:AF',
];

const APPLE_APP_ID = 'JND55328G8.dev.dz0ny.gozdar';

const SITE = 'https://gozdar.dz0ny.dev';
const IOS_URL = 'https://apps.apple.com/app/id6756237942';
const ANDROID_URL = 'https://github.com/dz0ny/gozdar/releases/latest';

function randomId() {
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  return Array.from(bytes, (b) => ID_ALPHABET[b % ID_ALPHABET.length]).join('');
}

function randomToken() {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

function sameToken(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || a.length !== b.length) {
    return false;
  }
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

function bearer(c) {
  const header = c.req.header('Authorization') ?? '';
  return header.startsWith('Bearer ') ? header.slice(7) : null;
}

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

// The app must be able to read every share. Check the fields it needs.
function validPayload(payload) {
  if (!isObject(payload) || !isObject(payload.parcel)) return false;
  if (typeof payload.parcel.number !== 'string') return false;
  if (!Array.isArray(payload.points)) return false;
  return payload.points.every(
    (p) =>
      isObject(p) &&
      typeof p.name === 'string' &&
      Number.isFinite(p.lat) &&
      Number.isFinite(p.lng),
  );
}

// Reads and checks the request body. Returns [payload] or [null, response].
async function readPayload(c) {
  const text = await c.req.text();
  if (new TextEncoder().encode(text).length > MAX_BYTES) {
    return [null, c.json({ error: 'Payload too large' }, 413)];
  }
  let payload;
  try {
    payload = JSON.parse(text);
  } catch {
    return [null, c.json({ error: 'Invalid JSON' }, 400)];
  }
  if (!validPayload(payload)) {
    return [null, c.json({ error: 'Missing parcel or points' }, 400)];
  }
  return [payload];
}

async function store(env, id, payload, editToken) {
  const expiresAt = new Date(Date.now() + TTL_SECONDS * 1000).toISOString();
  await env.SHARES.put(id, JSON.stringify({ payload, editToken, expiresAt }), {
    expirationTtl: TTL_SECONDS,
  });
  return expiresAt;
}

// Loads a share and checks the token. Returns [record] or [null, response].
async function authorized(c) {
  const record = await c.env.SHARES.get(c.req.param('id'), 'json');
  if (!record) return [null, c.json({ error: 'Not Found' }, 404)];
  if (!sameToken(bearer(c), record.editToken)) {
    return [null, c.json({ error: 'Forbidden' }, 403)];
  }
  return [record];
}

export const shares = new Hono();

shares.post('/api/s', async (c) => {
  const [payload, error] = await readPayload(c);
  if (error) return error;
  let id = randomId();
  for (let i = 0; i < 5 && (await c.env.SHARES.get(id)); i++) id = randomId();
  const editToken = randomToken();
  const expiresAt = await store(c.env, id, payload, editToken);
  return c.json({ id, editToken, expiresAt }, 201);
});

shares.put('/api/s/:id', async (c) => {
  const [record, denied] = await authorized(c);
  if (denied) return denied;
  const [payload, error] = await readPayload(c);
  if (error) return error;
  const expiresAt = await store(c.env, c.req.param('id'), payload, record.editToken);
  return c.json({ expiresAt });
});

shares.delete('/api/s/:id', async (c) => {
  const [, denied] = await authorized(c);
  if (denied) return denied;
  await c.env.SHARES.delete(c.req.param('id'));
  return c.body(null, 204);
});

shares.get('/api/s/:id', async (c) => {
  const record = await c.env.SHARES.get(c.req.param('id'), 'json');
  c.header('Cache-Control', 'no-store');
  if (!record) return c.json({ error: 'Not Found' }, 404);
  return c.json({ ...record.payload, expiresAt: record.expiresAt });
});

// Landing page. Safari does not open the app from a link to its own
// domain, so Uvozi uses the app scheme. Old /s/ links show it too.
shares.get('/o/:id', landing);
shares.get('/o/:id/preview.jpg', previewImage);
shares.get('/s/:id', landing);

shares.get('/icon.png', (c) =>
  c.body(Uint8Array.from(atob(ICON_PNG), (ch) => ch.charCodeAt(0)), 200, {
    'Content-Type': 'image/png',
    'Cache-Control': 'public, max-age=604800',
  }),
);

shares.get('/.well-known/assetlinks.json', (c) =>
  c.json([
    {
      relation: ['delegate_permission/common.handle_all_urls'],
      target: {
        namespace: 'android_app',
        package_name: 'dev.dz0ny.gozdar',
        sha256_cert_fingerprints: ANDROID_SHA256,
      },
    },
  ]),
);

shares.get('/.well-known/apple-app-site-association', (c) =>
  c.json({
    applinks: {
      details: [{ appIDs: [APPLE_APP_ID], components: [{ '/': '/o/*' }] }],
    },
  }),
);

async function landing(c) {
  const id = c.req.param('id');
  const record = await c.env.SHARES.get(id, 'json');
  c.header('Cache-Control', 'no-store');
  if (!record) {
    return c.html(page('<p>Ta povezava je potekla ali jo je lastnik preklical.</p>'), 404);
  }
  const { parcel, points } = record.payload;
  // Number and name of the k.o., e.g. "k.o. 1717 PREZID".
  const ko = [parcel.koNumber != null ? `k.o. ${parcel.koNumber}` : '', parcel.koName ?? '']
    .filter(Boolean)
    .join(' ');
  const title = `Parcela ${escapeHtml(parcel.number)}${ko ? `, ${escapeHtml(ko)}` : ''}`;
  // The map gets the outline and the trees only. The owner stays out of the page.
  const mapData = {
    polygon: Array.isArray(parcel.polygon) ? parcel.polygon : [],
    points: points.map((p) => ({ name: p.name, lat: p.lat, lng: p.lng, species: p.species })),
  };
  const rows = points.map((p, i) => {
    const at = `${p.lat.toFixed(5)}, ${p.lng.toFixed(5)}`;
    const species = p.species && !p.name.startsWith(p.species) ? ` · ${escapeHtml(p.species)}` : '';
    return `<li data-i="${i}"><b>${i + 1}</b><span>${escapeHtml(p.name)}${species}</span>
      <a class="geo" href="https://www.google.com/maps/search/?api=1&amp;query=${p.lat},${p.lng}">${at}</a></li>`;
  });
  return c.html(
    page(
      `
  <p class="lead">Lastnik ti je poslal drevesa, označena za posek.</p>
  <div class="card">
    <strong>🪓 ${title}</strong>
    <span>${trees(points.length)} za posek</span>
  </div>
  <div id="map"></div>
  <ol class="trees">${rows.join('')}</ol>
  <a class="primary" href="gozdar://open/o/${escapeHtml(id)}">Uvozi v Gozdar</a>
  <p class="small">Gozdar doda parcelo in drevesa v Moj gozd. Na terenu jih najdeš
  na karti in do njih navigiraš, tudi brez signala.</p>
  <p class="small">Nimaš Gozdarja? Namesti ga, nato znova odpri to povezavo.</p>
  <a class="secondary" href="${IOS_URL}">iPhone</a>
  <a class="secondary" href="${ANDROID_URL}">Android</a>
  <script type="application/json" id="data">${jsonForScript(mapData)}</script>
  <script src="${LEAFLET}/leaflet.js"></script>
  <script>${MAP_SCRIPT}</script>`,
      `<link rel="stylesheet" href="${LEAFLET}/leaflet.css">
${socialTags(id, `🪓 ${title} · ${trees(points.length)} za posek`)}`,
    ),
  );
}

const LEAFLET = 'https://unpkg.com/leaflet@1.9.4/dist';

// Draws the parcel and numbered trees. A tap on a list row zooms to that tree.
const MAP_SCRIPT = `
const data = JSON.parse(document.getElementById('data').textContent);
const map = L.map('map', { scrollWheelZoom: false, zoomControl: false });
map.attributionControl.setPrefix(false);
L.tileLayer(
  'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
  { maxZoom: 19, attribution: 'Esri' }).addTo(map);
const bounds = L.latLngBounds([]);
if (data.polygon.length > 2) {
  const outline = L.polygon(data.polygon, { color: '#d4a574', weight: 2, fillOpacity: 0.1 }).addTo(map);
  bounds.extend(outline.getBounds());
}
const markers = data.points.map((p, i) => {
  const icon = L.divIcon({ className: 'tree', html: String(i + 1), iconSize: [24, 24] });
  const marker = L.marker([p.lat, p.lng], { icon }).addTo(map);
  const label = document.createElement('div');
  label.textContent = p.species && !p.name.startsWith(p.species) ? p.name + ' · ' + p.species : p.name;
  marker.bindPopup(label);
  bounds.extend([p.lat, p.lng]);
  return marker;
});
if (bounds.isValid()) map.fitBounds(bounds, { padding: [24, 24], maxZoom: 18 });
else map.setView([46.1, 14.8], 8);
document.querySelectorAll('.trees li').forEach((row) => row.addEventListener('click', (e) => {
  if (e.target.closest('a')) return;
  const marker = markers[Number(row.dataset.i)];
  map.setView(marker.getLatLng(), 18);
  marker.openPopup();
  document.getElementById('map').scrollIntoView({ behavior: 'smooth', block: 'center' });
}));
`;

// Link preview for chat apps. The title is already escaped.
function socialTags(id, title) {
  const description = 'Lastnik ti je poslal drevesa, označena za posek. Odpri jih v Gozdarju.';
  const image = `${SITE}/o/${escapeHtml(id)}/preview.jpg`;
  return [
    `<meta property="og:type" content="website">`,
    `<meta property="og:site_name" content="Gozdar">`,
    `<meta property="og:title" content="${title}">`,
    `<meta property="og:description" content="${description}">`,
    `<meta property="og:url" content="${SITE}/o/${escapeHtml(id)}">`,
    `<meta property="og:image" content="${image}">`,
    `<meta property="og:image:width" content="1200">`,
    `<meta property="og:image:height" content="630">`,
    `<meta name="twitter:card" content="summary_large_image">`,
    `<meta name="description" content="${description}">`,
  ].join('\n');
}

const PREVIEW_W = 1200;
const PREVIEW_H = 630;

// Satellite crop around the parcel and its trees, for the link preview.
async function previewImage(c) {
  const record = await c.env.SHARES.get(c.req.param('id'), 'json');
  if (!record) return c.body(null, 404);
  const { parcel, points } = record.payload;
  const coords = [...(Array.isArray(parcel.polygon) ? parcel.polygon : []), ...points.map((p) => [p.lat, p.lng])]
    .filter((p) => Array.isArray(p) && Number.isFinite(p[0]) && Number.isFinite(p[1]));
  if (coords.length === 0) return c.body(null, 404);
  const query = new URLSearchParams({
    bbox: previewBox(coords).join(','),
    bboxSR: '3857',
    imageSR: '3857',
    size: `${PREVIEW_W},${PREVIEW_H}`,
    format: 'jpg',
    f: 'image',
  });
  const res = await fetch(
    `https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/export?${query}`,
    { cf: { cacheTtl: 86400, cacheEverything: true } },
  );
  if (!res.ok) return c.body(null, 502);
  return c.body(res.body, 200, {
    'Content-Type': 'image/jpeg',
    'Cache-Control': 'no-store',
  });
}

// Web Mercator box around [lat, lng] pairs with a margin, in the shape of
// the preview image.
function previewBox(coords) {
  const R = 6378137;
  const xs = coords.map(([, lng]) => (R * lng * Math.PI) / 180);
  const ys = coords.map(([lat]) => R * Math.log(Math.tan(Math.PI / 4 + (lat * Math.PI) / 360)));
  const cx = (Math.min(...xs) + Math.max(...xs)) / 2;
  const cy = (Math.min(...ys) + Math.max(...ys)) / 2;
  let w = Math.max(Math.max(...xs) - Math.min(...xs), 60) * 1.4;
  let h = Math.max(Math.max(...ys) - Math.min(...ys), 60) * 1.4;
  if (w / h > PREVIEW_W / PREVIEW_H) h = (w * PREVIEW_H) / PREVIEW_W;
  else w = (h * PREVIEW_W) / PREVIEW_H;
  return [cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2].map((v) => v.toFixed(1));
}

// JSON inside a script tag. Escaping < keeps a name like </script> inert.
function jsonForScript(value) {
  return JSON.stringify(value).replace(/</g, '\\u003c');
}

// Slovenian plural: 1 drevo, 2 drevesi, 3 in 4 drevesa, 5 in več dreves.
function trees(n) {
  const mod = n % 100;
  if (mod === 1) return `${n} drevo`;
  if (mod === 2) return `${n} drevesi`;
  if (mod === 3 || mod === 4) return `${n} drevesa`;
  return `${n} dreves`;
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (ch) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[ch]);
}

function page(body, head = '') {
  return `<!doctype html>
<html lang="sl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sečnja · Gozdar</title>
<link rel="icon" href="/icon.png">
<link rel="apple-touch-icon" href="/icon.png">
${head}
<style>
  body { margin: 0; min-height: 100vh; display: flex; justify-content: center;
         font-family: -apple-system, system-ui, sans-serif; background: #1c2a1f; color: #eee; }
  main { width: 100%; max-width: 480px; padding: 24px 16px; box-sizing: border-box; }
  header { text-align: center; margin-bottom: 8px; }
  header img { display: block; margin: 0 auto 8px; border-radius: 16px; }
  h1 { color: #d4a574; margin: 0; font-size: 22px; }
  .lead { font-size: 17px; }
  .card { display: flex; flex-direction: column; gap: 4px; padding: 16px; border-radius: 12px;
          background: #2d3b2f; margin: 16px 0; }
  .card span { color: #ff8a50; font-weight: 600; }
  a.primary, a.secondary { display: block; text-align: center; text-decoration: none;
      border-radius: 12px; padding: 14px; margin: 10px 0; font-weight: 600; }
  a.primary { background: #ff5722; color: #fff; font-size: 17px; }
  a.secondary { border: 1px solid #d4a574; color: #d4a574; }
  .small { color: #aab; font-size: 14px; line-height: 1.4; }
  #map { height: 300px; border-radius: 12px; margin: 16px 0 8px; background: #2d3b2f; }
  .tree { background: #ff5722; color: #fff; border: 2px solid #fff; border-radius: 50%;
          font: 600 12px/20px -apple-system, system-ui, sans-serif; text-align: center; }
  .trees { list-style: none; padding: 0; margin: 0 0 16px; }
  .trees li { display: flex; align-items: center; gap: 10px; padding: 10px 4px;
              border-bottom: 1px solid #2d3b2f; cursor: pointer; }
  .trees li b { flex: none; width: 24px; height: 24px; border-radius: 50%; background: #ff5722;
                color: #fff; font-size: 12px; line-height: 24px; text-align: center; }
  .trees li span { flex: 1; }
  .trees a.geo { font-size: 13px; color: #aab; }
</style>
</head>
<body>
<main>
  <header><img src="/icon.png" alt="" width="72" height="72"><h1>Gozdar</h1></header>
${body}
</main>
</body>
</html>`;
}
