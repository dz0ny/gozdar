import { test } from 'node:test';
import assert from 'node:assert/strict';
import jpeg from 'jpeg-js';
import { shares } from '../src/shares.js';
import { PREVIEW_W, PREVIEW_H, previewBox, toPixel, drawLine, renderPreview } from '../src/preview.js';

const DAY = 24 * 3600;

function fakeKv() {
  const store = new Map();
  const kv = {
    ttls: [],
    async get(key, type) {
      const v = store.get(key);
      if (v === undefined) return null;
      return type === 'json' ? JSON.parse(v) : v;
    },
    async put(key, value, opts = {}) {
      kv.ttls.push(opts.expirationTtl);
      store.set(key, value);
    },
    async delete(key) {
      store.delete(key);
    },
  };
  return kv;
}

const payload = (points = [{ name: 'Smreka 1', lat: 46.05, lng: 14.5 }]) => ({
  v: 1,
  parcel: { number: '1234/5', koNumber: 1234, polygon: [[46, 14], [46.1, 14], [46.1, 14.1]] },
  points,
  createdAt: '2026-11-02T10:00:00Z',
});

function call(env, method, path, body, token) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const init = { method, headers };
  if (body !== undefined) init.body = typeof body === 'string' ? body : JSON.stringify(body);
  return shares.request(path, init, env);
}

async function create(env, p = payload()) {
  const res = await call(env, 'POST', '/api/s', p);
  return { res, body: await res.json() };
}

test('create returns id, token and expiry', async () => {
  const env = { SHARES: fakeKv() };
  const { res, body } = await create(env);
  assert.equal(res.status, 201);
  assert.match(body.id, /^[A-Za-z0-9]{6}$/);
  assert.equal(body.editToken.length, 43);
  const expires = Date.parse(body.expiresAt) / 1000;
  assert.ok(Math.abs(expires - (Date.now() / 1000 + 30 * DAY)) < 60);
  assert.equal(env.SHARES.ttls[0], 2592000);
});

test('get hides the edit token', async () => {
  const env = { SHARES: fakeKv() };
  const { body } = await create(env);
  const res = await call(env, 'GET', `/api/s/${body.id}`);
  assert.equal(res.status, 200);
  assert.equal(res.headers.get('cache-control'), 'no-store');
  const got = await res.json();
  assert.equal(got.parcel.number, '1234/5');
  assert.ok(got.expiresAt);
  assert.equal(got.editToken, undefined);
});

test('update with right token replaces payload and restarts ttl', async () => {
  const env = { SHARES: fakeKv() };
  const { body } = await create(env);
  const pts = [{ name: 'Bukev 2', lat: 46.06, lng: 14.51 }];
  const res = await call(env, 'PUT', `/api/s/${body.id}`, payload(pts), body.editToken);
  assert.equal(res.status, 200);
  assert.ok((await res.json()).expiresAt);
  assert.equal(env.SHARES.ttls.length, 2);
  const got = await (await call(env, 'GET', `/api/s/${body.id}`)).json();
  assert.deepEqual(got.points, pts);
});

test('update with wrong token is 403', async () => {
  const env = { SHARES: fakeKv() };
  const { body } = await create(env);
  const res = await call(env, 'PUT', `/api/s/${body.id}`, payload(), 'x'.repeat(43));
  assert.equal(res.status, 403);
});

test('update of missing id is 404', async () => {
  const env = { SHARES: fakeKv() };
  const res = await call(env, 'PUT', '/api/s/abcdef', payload(), 'x'.repeat(43));
  assert.equal(res.status, 404);
});

test('delete then get is 404', async () => {
  const env = { SHARES: fakeKv() };
  const { body } = await create(env);
  const del = await call(env, 'DELETE', `/api/s/${body.id}`, undefined, body.editToken);
  assert.equal(del.status, 204);
  const res = await call(env, 'GET', `/api/s/${body.id}`);
  assert.equal(res.status, 404);
});

test('delete with wrong token is 403', async () => {
  const env = { SHARES: fakeKv() };
  const { body } = await create(env);
  const del = await call(env, 'DELETE', `/api/s/${body.id}`, undefined, 'nope');
  assert.equal(del.status, 403);
});

test('rejects payload without points', async () => {
  const env = { SHARES: fakeKv() };
  const res = await call(env, 'POST', '/api/s', { v: 1, parcel: {} });
  assert.equal(res.status, 400);
});

test('rejects invalid json', async () => {
  const env = { SHARES: fakeKv() };
  const res = await call(env, 'POST', '/api/s', '{nope');
  assert.equal(res.status, 400);
});

test('rejects body over 256 KB', async () => {
  const env = { SHARES: fakeKv() };
  const big = payload([{ name: 'x'.repeat(262144), lat: 1, lng: 1 }]);
  const res = await call(env, 'POST', '/api/s', big);
  assert.equal(res.status, 413);
});

test('assetlinks lists the package', async () => {
  const res = await call({}, 'GET', '/.well-known/assetlinks.json');
  const body = await res.json();
  assert.equal(body[0].target.package_name, 'dev.dz0ny.gozdar');
  assert.ok(body[0].target.sha256_cert_fingerprints.some((f) => f.startsWith('1D:6A:FE')), 'release key');
});

test('aasa lists the app id and path', async () => {
  const res = await call({}, 'GET', '/.well-known/apple-app-site-association');
  assert.match(res.headers.get('content-type'), /application\/json/);
  const body = await res.json();
  assert.ok(body.applinks.details[0].appIDs.includes('JND55328G8.dev.dz0ny.gozdar'));
  assert.equal(body.applinks.details[0].components[0]['/'], '/o/*');
});

test('rejects null or array parcel', async () => {
  const env = { SHARES: fakeKv() };
  for (const parcel of [null, []]) {
    const res = await call(env, 'POST', '/api/s', { v: 1, parcel, points: [] });
    assert.equal(res.status, 400);
  }
});

test('rejects parcel without a number', async () => {
  const env = { SHARES: fakeKv() };
  const res = await call(env, 'POST', '/api/s', { v: 1, parcel: { polygon: [] }, points: [] });
  assert.equal(res.status, 400);
});

test('rejects points without name or coordinates', async () => {
  const env = { SHARES: fakeKv() };
  for (const point of [{ lat: 1, lng: 1 }, { name: 'x', lat: '1', lng: 1 }, null]) {
    const res = await call(env, 'POST', '/api/s', payload([point]));
    assert.equal(res.status, 400);
  }
});

test('landing page explains the share and offers Uvozi', async () => {
  const env = { SHARES: fakeKv() };
  const { body } = await create(env);
  const res = await call(env, 'GET', `/o/${body.id}`);
  assert.equal(res.status, 200);
  assert.match(res.headers.get('content-type'), /text\/html/);
  const html = await res.text();
  assert.ok(html.includes('Parcela 1234/5, k.o. 1234'), 'names the parcel and k.o.');
  assert.ok(html.includes('1 drevo'), 'counts the trees');
  assert.ok(html.includes(`gozdar://open/o/${body.id}`), 'Uvozi opens the app');
  assert.ok(html.includes('Uvozi'));
  assert.ok(html.includes('https://apps.apple.com/app/id6756237942'), 'App Store link');
});

test('landing page shows each tree with its location on a map', async () => {
  const env = { SHARES: fakeKv() };
  const points = [
    { name: 'Smreka 1', lat: 46.05, lng: 14.5, species: 'Smreka' },
    { name: 'Bukev 2', lat: 46.06, lng: 14.51 },
  ];
  const { body } = await create(env, {
    ...payload(points),
    parcel: { ...payload().parcel, owner: 'Janez Novak' },
  });
  const html = await (await call(env, 'GET', `/o/${body.id}`)).text();
  assert.ok(html.includes('id="map"'), 'has a map');
  assert.ok(html.includes('leaflet'), 'loads the map library');
  assert.ok(html.includes('Smreka 1') && html.includes('Bukev 2'), 'lists the trees');
  assert.ok(html.includes('46.05000, 14.50000'), 'shows coordinates');
  assert.ok(html.includes('[46.1,14]'), 'draws the parcel outline');
  assert.ok(!html.includes('Janez Novak'), 'hides the owner');
});

test('landing page escapes tree names in the list and the map data', async () => {
  const env = { SHARES: fakeKv() };
  const evil = '</script><img src=x onerror=alert(1)>';
  const { body } = await create(env, payload([{ name: evil, lat: 46.05, lng: 14.5 }]));
  const html = await (await call(env, 'GET', `/o/${body.id}`)).text();
  assert.ok(!html.includes('<img src=x'), 'no raw markup');
  assert.equal(html.split('</script>').length - 1, html.split('<script').length - 1);
});

test('landing page for a missing share says it expired', async () => {
  const env = { SHARES: fakeKv() };
  const res = await call(env, 'GET', '/o/gone00');
  assert.equal(res.status, 404);
  assert.ok((await res.text()).includes('potekla'));
});

test('old /s/ links show the same landing page', async () => {
  const env = { SHARES: fakeKv() };
  const { body } = await create(env);
  const res = await call(env, 'GET', `/s/${body.id}`);
  assert.equal(res.status, 200);
  assert.ok((await res.text()).includes(`gozdar://open/o/${body.id}`));
});

test('landing page carries a social preview', async () => {
  const env = { SHARES: fakeKv() };
  const { body } = await create(env);
  const html = await (await call(env, 'GET', `/o/${body.id}`)).text();
  assert.match(html, /<meta property="og:title" content="[^"]*1234\/5[^"]*1 drevo/);
  assert.ok(html.includes('property="og:description"'));
  assert.ok(html.includes(`content="https://gozdar.dz0ny.dev/o/${body.id}/preview.jpg"`), 'og:image');
  assert.ok(html.includes('name="twitter:card" content="summary_large_image"'));
});

test('preview image draws the parcel and the trees, and skips kataster when the WMS is down', async () => {
  const env = { SHARES: fakeKv() };
  const tree = { name: 'Smreka 1', lat: 46.05, lng: 14.05 };
  const { body } = await create(env, payload([tree]));
  const grey = { width: PREVIEW_W, height: PREVIEW_H, data: new Uint8Array(PREVIEW_W * PREVIEW_H * 4).fill(100) };
  const satellite = jpeg.encode(grey, 90).data;
  const seen = [];
  const realFetch = globalThis.fetch;
  globalThis.fetch = async (url) => {
    seen.push(String(url));
    if (String(url).includes('geoserver')) return new Response('down', { status: 503 });
    return new Response(satellite, { headers: { 'Content-Type': 'image/jpeg' } });
  };
  let res;
  try {
    res = await call(env, 'GET', `/o/${body.id}/preview.jpg`);
  } finally {
    globalThis.fetch = realFetch;
  }
  assert.equal(res.status, 200);
  assert.equal(res.headers.get('content-type'), 'image/jpeg');
  assert.equal(res.headers.get('cache-control'), 'no-store');
  assert.ok(seen.some((u) => /World_Imagery\/MapServer\/export\?bbox=/.test(u)), 'satellite');
  assert.ok(seen.some((u) => u.includes('kn_parcele') && u.includes('EPSG%3A3794')), 'kataster');
  const out = jpeg.decode(new Uint8Array(await res.arrayBuffer()), { useTArray: true });
  const box = previewBox([...payload().parcel.polygon, [tree.lat, tree.lng]]);
  const [x, y] = toPixel([tree.lat, tree.lng], box).map(Math.round);
  // Left of the number, inside the orange disc.
  const i = (y * PREVIEW_W + x - 14) * 4;
  assert.ok(out.data[i] > 200 && out.data[i + 2] < 100, `orange at the tree, got ${out.data.slice(i, i + 3)}`);
});

test('preview image of a missing share is 404', async () => {
  const env = { SHARES: fakeKv() };
  const res = await call(env, 'GET', '/o/gone00/preview.jpg');
  assert.equal(res.status, 404);
});

test('landing page shows the k.o. number and name', async () => {
  const env = { SHARES: fakeKv() };
  const { body } = await create(env, { ...payload(), parcel: { ...payload().parcel, koName: 'PREZID' } });
  const html = await (await call(env, 'GET', `/o/${body.id}`)).text();
  assert.ok(html.includes('Parcela 1234/5, k.o. 1234 PREZID'));
});

test('icon is the app icon as png', async () => {
  const res = await call({ SHARES: fakeKv() }, 'GET', '/icon.png');
  assert.equal(res.status, 200);
  assert.equal(res.headers.get('content-type'), 'image/png');
  const bytes = new Uint8Array(await res.arrayBuffer());
  assert.deepEqual([...bytes.slice(1, 4)], [0x50, 0x4e, 0x47]);
});

test('landing page shows the app icon in the header', async () => {
  const env = { SHARES: fakeKv() };
  const { body } = await create(env);
  const html = await (await call(env, 'GET', `/o/${body.id}`)).text();
  assert.ok(html.includes('<header><img src="/icon.png"'));
  assert.ok(!html.includes('🌲'));
});

test('drawLine paints a see-through line evenly', () => {
  const img = { width: 20, height: 5, data: new Uint8Array(20 * 5 * 4) };
  drawLine(img, [2, 2], [17, 2], 1, [200, 200, 200, 0.5]);
  const row = [];
  for (let x = 3; x < 17; x++) row.push(img.data[(2 * 20 + x) * 4]);
  assert.deepEqual(new Set(row), new Set([100]));
});

test('preview of a share outside Slovenia skips the kataster and stays fast with a huge polygon', async () => {
  const grey = { width: PREVIEW_W, height: PREVIEW_H, data: new Uint8Array(PREVIEW_W * PREVIEW_H * 4).fill(100) };
  const satellite = jpeg.encode(grey, 90).data;
  const seen = [];
  const fetchFn = async (url) => {
    seen.push(String(url));
    return new Response(satellite, { headers: { 'Content-Type': 'image/jpeg' } });
  };
  // A zigzag across 10 degrees: every segment spans the whole image.
  const polygon = Array.from({ length: 20000 }, (_, i) => [i % 2 ? 40 : 50, 5 + (i / 20000) * 10]);
  const points = Array.from({ length: 5000 }, (_, i) => ({ name: `t${i}`, lat: 45, lng: 10 }));
  const started = Date.now();
  const bytes = await renderPreview({ parcel: { number: '1', polygon }, points }, fetchFn);
  assert.ok(bytes.length > 0);
  assert.ok(Date.now() - started < 15000, `took ${Date.now() - started} ms`);
  assert.ok(!seen.some((u) => u.includes('geoserver')), 'no kataster outside Slovenia');
});
