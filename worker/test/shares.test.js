import { test } from 'node:test';
import assert from 'node:assert/strict';
import { shares } from '../src/shares.js';

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
  assert.ok(body[0].target.sha256_cert_fingerprints.length >= 1);
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
  assert.ok(html.includes('1234/5'), 'names the parcel');
  assert.ok(html.includes('1 drevo'), 'counts the trees');
  assert.ok(html.includes(`gozdar://open/o/${body.id}`), 'Uvozi opens the app');
  assert.ok(html.includes('Uvozi'));
  assert.ok(!html.includes('46.05'), 'no coordinates');
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
