import proj4 from 'proj4';
import { LAYERS } from './layers.js';

// Define Projections
// EPSG:3794 - Slovenia 1996 / Slovene National Grid
proj4.defs('EPSG:3794', '+proj=tmerc +lat_0=0 +lon_0=15 +k=0.9999 +x_0=500000 +y_0=-5000000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs +type=crs');
// EPSG:3857 - Web Mercator (Standard XYZ)
proj4.defs('EPSG:3857', '+proj=merc +a=6378137 +b=6378137 +lat_ts=0 +lon_0=0 +x_0=0 +y_0=0 +k=1 +units=m +nadgrids=@null +wktext +no_defs +type=crs');

// Constants for Web Mercator
const R = 6378137;
const MAX_EXTENT = 20037508.342789244;

/**
 * Convert XYZ tile coordinates to Web Mercator (EPSG:3857) BBOX
 */
function xyzToBbox(x, y, z) {
  const resolution = (2 * Math.PI * R) / (256 * Math.pow(2, z));
  const originX = -Math.PI * R;
  const originY = Math.PI * R;

  const minX = originX + x * 256 * resolution;
  const maxX = originX + (x + 1) * 256 * resolution;
  const maxY = originY - y * 256 * resolution;
  const minY = originY - (y + 1) * 256 * resolution;

  return { minX, minY, maxX, maxY };
}

/**
 * Reproject BBOX from source CRS to dest CRS
 * Transforms all 4 corners to ensure coverage
 */
function reprojectBbox(bbox, sourceCrs, destCrs) {
  const corners = [
    [bbox.minX, bbox.minY],
    [bbox.maxX, bbox.minY],
    [bbox.maxX, bbox.maxY],
    [bbox.minX, bbox.maxY],
  ];

  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;

  corners.forEach(corner => {
    const projected = proj4(sourceCrs, destCrs, corner);
    if (projected[0] < minX) minX = projected[0];
    if (projected[0] > maxX) maxX = projected[0];
    if (projected[1] < minY) minY = projected[1];
    if (projected[1] > maxY) maxY = projected[1];
  });

  return { minX, minY, maxX, maxY };
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;

    // Route: /tiles/:layer/:z/:x/:y
    const match = path.match(/^\/tiles\/([^\/]+)\/(\d+)\/(\d+)\/(\d+)(?:\.png|\.jpg|\.jpeg)?$/);

    if (match) {
      const [, layerSlug, zStr, xStr, yStr] = match;
      const z = parseInt(zStr, 10);
      const x = parseInt(xStr, 10);
      const y = parseInt(yStr, 10);

      const layerConfig = LAYERS[layerSlug];
      if (!layerConfig) {
        return new Response('Layer not found', { status: 404 });
      }

      // 1. Calculate Web Mercator BBOX
      const bbox3857 = xyzToBbox(x, y, z);

      // 2. Reproject to EPSG:3794
      const bbox3794 = reprojectBbox(bbox3857, 'EPSG:3857', 'EPSG:3794');

      // 3. Construct Upstream WMS URL
      // Switching to WMS 1.1.1 for better compatibility (SRS vs CRS)
      const params = new URLSearchParams({
        SERVICE: 'WMS',
        VERSION: '1.1.1',
        REQUEST: 'GetMap',
        FORMAT: layerConfig.format,
        TRANSPARENT: layerConfig.transparent ? 'true' : 'false',
        LAYERS: layerConfig.layers,
        SRS: 'EPSG:3794', 
        STYLES: layerConfig.styles || '',
        WIDTH: '256',
        HEIGHT: '256',
        BBOX: `${bbox3794.minX},${bbox3794.minY},${bbox3794.maxX},${bbox3794.maxY}`
      });

      const upstreamUrl = `${layerConfig.baseUrl}?${params.toString()}`;
      console.log(`Fetching: ${upstreamUrl}`);

      // 4. Fetch and Cache
      // Use the Cache API
      const cache = caches.default;
      let response = await cache.match(request);

      if (!response) {
        console.log(`Cache miss for ${path}, fetching upstream...`);
        try {
          // Fetch from upstream
          const upstreamResponse = await fetch(upstreamUrl, {
            headers: {
              'User-Agent': 'Gozdar/1.0 (Cloudflare Worker Proxy)'
            }
          });

          if (!upstreamResponse.ok) {
            console.log(`Upstream failed: ${upstreamResponse.status} ${upstreamResponse.statusText}`);
            const text = await upstreamResponse.text();
            console.log(`Body: ${text}`);
            return new Response(`Upstream error: ${upstreamResponse.status} - ${upstreamResponse.statusText}\n${text}`, { status: 502 });
          }

          // Create response to cache
          // We need to recreate the response to set headers
          response = new Response(upstreamResponse.body, upstreamResponse);
          response.headers.set('Cache-Control', 'public, max-age=31536000, immutable');
          response.headers.set('Access-Control-Allow-Origin', '*');
          
          // Store in cache (background)
          ctx.waitUntil(cache.put(request, response.clone()));
        } catch (e) {
          return new Response(`Proxy error: ${e.message}`, { status: 500 });
        }
      } else {
         console.log(`Cache hit for ${path}`);
      }

      return response;
    }

    // Default route: List layers
    if (path === '/' || path === '/layers') {
      const layersList = Object.keys(LAYERS).map(k => {
        const l = LAYERS[k];
        return `- ${k} (${l.format})`;
      }).join('\n');
      
      return new Response(`Gozdar Tile Proxy\n\nAvailable Layers:\n${layersList}`, {
        headers: { 'Content-Type': 'text/plain' }
      });
    }

    return new Response('Not Found', { status: 404 });
  }
};
