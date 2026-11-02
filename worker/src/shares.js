import { Hono } from 'hono';

// Sečnja share links. The owner uploads the marked trees of one parcel.
// The logger gets https://gozdar.dz0ny.dev/o/<id>, and the link opens Gozdar.
// Without the app, the same address shows a landing page with an Uvozi button.
// KV keeps each share for 30 days after the last upload.

const TTL_SECONDS = 30 * 24 * 3600;
const MAX_BYTES = 262144;
const ID_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

// Fingerprints of the keys that sign the Android app.
// Only the debug key is here now. Add the release key later.
const ANDROID_SHA256 = [
  '85:69:C5:31:8C:05:13:3D:2B:11:D5:07:E4:6C:BE:DB:06:B4:08:EE:DC:ED:44:77:E5:0B:C5:1E:EA:AA:E0:AF',
];

const APPLE_APP_ID = 'JND55328G8.dev.dz0ny.gozdar';

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
shares.get('/s/:id', landing);

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
  const ko = parcel.koName ?? (parcel.koNumber != null ? `k.o. ${parcel.koNumber}` : '');
  const title = `Parcela ${escapeHtml(parcel.number)}${ko ? `, ${escapeHtml(ko)}` : ''}`;
  return c.html(
    page(`
  <p class="lead">Lastnik ti je poslal drevesa, označena za posek.</p>
  <div class="card">
    <strong>🪓 ${title}</strong>
    <span>${trees(points.length)} za posek</span>
  </div>
  <a class="primary" href="gozdar://open/o/${escapeHtml(id)}">Uvozi v Gozdar</a>
  <p class="small">Gozdar doda parcelo in drevesa v Moj gozd. Na terenu jih najdeš
  na karti in do njih navigiraš, tudi brez signala.</p>
  <p class="small">Nimaš Gozdarja? Namesti ga, nato znova odpri to povezavo.</p>
  <a class="secondary" href="${IOS_URL}">iPhone</a>
  <a class="secondary" href="${ANDROID_URL}">Android</a>`),
  );
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

function page(body) {
  return `<!doctype html>
<html lang="sl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Sečnja · Gozdar</title>
<style>
  body { margin: 0; min-height: 100vh; display: flex; align-items: center; justify-content: center;
         font-family: -apple-system, system-ui, sans-serif; background: #1c2a1f; color: #eee; }
  main { max-width: 360px; padding: 24px; }
  h1 { color: #d4a574; margin: 0 0 8px; font-size: 22px; }
  .lead { font-size: 17px; }
  .card { display: flex; flex-direction: column; gap: 4px; padding: 16px; border-radius: 12px;
          background: #2d3b2f; margin: 16px 0; }
  .card span { color: #ff8a50; font-weight: 600; }
  a { display: block; text-align: center; text-decoration: none; border-radius: 12px; padding: 14px;
      margin: 10px 0; font-weight: 600; }
  a.primary { background: #ff5722; color: #fff; font-size: 17px; }
  a.secondary { border: 1px solid #d4a574; color: #d4a574; }
  .small { color: #aab; font-size: 14px; line-height: 1.4; }
</style>
</head>
<body>
<main>
  <h1>🌲 Gozdar</h1>
${body}
</main>
</body>
</html>`;
}
