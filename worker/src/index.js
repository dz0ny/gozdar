import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { BASE_LAYERS, OVERLAY_LAYERS } from './layers.js';
import { getMapHtml } from './map.js';
import { handleTileRequest } from './tiles.js';
import { cache } from './middleware/cache.js';
import { getParcelByPoint, getParcelById, getParcelsByBbox, getCadastralZoning } from './wfs.js';

// Create Hono app
const app = new Hono();

// Global middleware
app.use('*', logger());
app.use('*', cors({
  origin: '*',
  allowMethods: ['GET', 'HEAD', 'OPTIONS'],
}));

// Apply cache middleware to tile routes
app.use('/tiles/*', cache());

// Routes

// Tile proxy endpoint - matches /tiles/:layer/:z/:x/:y with optional .png/.jpg/.jpeg extension
app.get('/tiles/:layer/:z/:x/:filename', handleTileRequest);

// Map viewer
app.get('/', (c) => {
  const url = new URL(c.req.url);
  return c.html(getMapHtml(url.origin));
});

app.get('/map', (c) => {
  const url = new URL(c.req.url);
  return c.html(getMapHtml(url.origin));
});

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
app.get('/api/wfs/parcel/:id', getParcelById);
app.get('/api/wfs/parcels/bbox', getParcelsByBbox);
app.get('/api/wfs/zoning', getCadastralZoning);

// 404 handler
app.notFound((c) => {
  return c.json({ error: 'Not Found' }, 404);
});

// Error handler
app.onError((err, c) => {
  console.error(`Error: ${err.message}`);
  return c.json({ error: err.message }, 500);
});

export default app;
