import { Hono } from 'hono';

// Sečnja share links. The owner uploads the marked trees of one parcel.
// The logger gets https://gozdar.dz0ny.dev/s/<id>, and the link opens Gozdar.
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
  if (!payload || typeof payload.parcel !== 'object' || !Array.isArray(payload.points)) {
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
      details: [{ appIDs: [APPLE_APP_ID], components: [{ '/': '/s/*' }] }],
    },
  }),
);
