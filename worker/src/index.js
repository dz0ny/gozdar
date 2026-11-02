import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { BASE_LAYERS, OVERLAY_LAYERS } from './layers.js';
import { handleTileRequest } from './tiles.js';
import { cache } from './middleware/cache.js';
import { getParcelByPoint, getParcelById, getParcelsByBbox, getCadastralZoning, getParcelByKoAndNumber } from './wfs.js';
import { debugOffer, getOffers, refreshOffers } from './offers.js';
import { shares } from './shares.js';

// Create Hono app
const app = new Hono();

// Global middleware
app.use('*', logger());
app.use('*', cors({
  origin: '*',
  allowMethods: ['GET', 'HEAD', 'OPTIONS', 'POST', 'PUT', 'DELETE'],
  allowHeaders: ['Content-Type', 'Authorization'],
}));

// Apply cache middleware to tile routes
app.use('/tiles/*', cache());

// Routes

// Tile proxy endpoint - matches /tiles/:layer/:z/:x/:y with optional .png/.jpg/.jpeg extension
app.get('/tiles/:layer/:z/:x/:filename', handleTileRequest);

// The root and every other page path are the marketing site in ../site,
// served by Workers Static Assets (see [assets] in wrangler.toml). A request
// reaches this app only when no static file matches its path.

// API: List layers
app.get('/layers', (c) => {
  return c.json({
    base: BASE_LAYERS,
    overlays: OVERLAY_LAYERS
  });
});

app.get('/api/layers', (c) => {
  return c.json({
    base: BASE_LAYERS,
    overlays: OVERLAY_LAYERS
  });
});

// WFS API endpoints
app.get('/api/wfs/parcel/point', getParcelByPoint);
app.get('/api/wfs/parcel/ko/:koNumber/:parcelNumber', getParcelByKoAndNumber);
app.get('/api/wfs/parcel/:id', getParcelById);
app.get('/api/wfs/parcels/bbox', getParcelsByBbox);
app.get('/api/wfs/zoning', getCadastralZoning);

// Sale offers for farmland and forest (e-uprava), read by the cron job.
app.get('/api/offers', getOffers);

// Read one offer now. This uses Workers AI, so only local dev may call it.
app.get('/api/offers/debug/:id', (c) => {
  const host = new URL(c.req.url).hostname;
  if (host !== 'localhost' && host !== '127.0.0.1') return c.notFound();
  return debugOffer(c);
});

// Sečnja share links and app-link files.
app.route('/', shares);

// 404 handler: API clients keep the JSON body; a browser gets the site's 404 page.
app.notFound(async (c) => {
  const wantsHtml = (c.req.header('accept') || '').includes('text/html');
  if (wantsHtml && c.env?.ASSETS) {
    const page = await c.env.ASSETS.fetch(new URL('/404/', c.req.url));
    if (page.ok) {
      return new Response(page.body, {
        status: 404,
        headers: { 'content-type': 'text/html; charset=utf-8' },
      });
    }
  }
  return c.json({ error: 'Not Found' }, 404);
});

// Error handler
app.onError((err, c) => {
  console.error(`Error: ${err.message}`);
  return c.json({ error: err.message }, 500);
});

export default {
  fetch: app.fetch,
  // The cron reads new sale offers. See wrangler.toml for the schedule.
  async scheduled(_event, env, ctx) {
    ctx.waitUntil(refreshOffers(env).then((r) => console.log('offers', r)));
  },
};
