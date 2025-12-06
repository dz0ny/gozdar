import proj4 from 'proj4';
import { LAYERS, BASE_LAYERS, OVERLAY_LAYERS } from './layers.js';
import { getMapHtml } from './map.js';

// Define Projections
// EPSG:3794 - Slovenia 1996 / Slovene National Grid
proj4.defs('EPSG:3794', '+proj=tmerc +lat_0=0 +lon_0=15 +k=0.9999 +x_0=500000 +y_0=-5000000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs +type=crs');
// EPSG:3857 - Web Mercator (Standard XYZ)
proj4.defs('EPSG:3857', '+proj=merc +a=6378137 +b=6378137 +lat_ts=0 +lon_0=0 +x_0=0 +y_0=0 +k=1 +units=m +nadgrids=@null +wktext +no_defs +type=crs');

// Constants for Web Mercator
const R = 6378137;
const MAX_EXTENT = 20037508.342789244;

// Slovenia Bounds (EPSG:3794)
// Approximately: X: 370k-620k, Y: 30k-190k
// We use a generous buffer to include border areas but exclude invalid requests
const SLOVENIA_BOUNDS = {
  minX: 300000,
  maxX: 700000,
  minY: 10000,
  maxY: 300000
};

// 1x1 Transparent PNG for out-of-bounds requests
const EMPTY_IMAGE = Uint8Array.from(atob('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='), c => c.charCodeAt(0));

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

      // Check if this is a base layer (no R2 caching for base layers)
      const isBaseLayer = ['ortofoto', 'dof-ir', 'dmr'].includes(layerSlug);

      // 1. Calculate Web Mercator BBOX
      const bbox3857 = xyzToBbox(x, y, z);

      // 2. Reproject to EPSG:3794
      const bbox3794 = reprojectBbox(bbox3857, 'EPSG:3857', 'EPSG:3794');

      // Check if tile is within Slovenia bounds
      // If outside, return empty image immediately to save resources and avoid upstream errors
      if (bbox3794.maxX < SLOVENIA_BOUNDS.minX || 
          bbox3794.minX > SLOVENIA_BOUNDS.maxX || 
          bbox3794.maxY < SLOVENIA_BOUNDS.minY || 
          bbox3794.minY > SLOVENIA_BOUNDS.maxY) {
        return new Response(EMPTY_IMAGE, {
          headers: {
            'Content-Type': 'image/png',
            'Cache-Control': 'public, max-age=31536000, immutable',
            'Access-Control-Allow-Origin': '*'
          }
        });
      }

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

      // 4. Fetch and Cache
      // Use the Cache API
      const cache = caches.default;
      let response = await cache.match(request);

      if (!response) {
        // Try R2 Cache (only for overlay layers, not base layers)
        const ext = layerConfig.format === 'image/jpeg' ? 'jpg' : 'png';
        const r2Key = `${layerSlug}/${z}/${x}/${y}.${ext}`;
        let r2Object = null;

        if (!isBaseLayer) {
          try {
            r2Object = await env.TILES_BUCKET.get(r2Key);
          } catch (e) {
            console.error(`R2 Error: ${e.message}`);
          }
        }

        if (r2Object) {
          console.log(`R2 hit for ${r2Key}`);
          const headers = new Headers();
          r2Object.writeHttpMetadata(headers);

          if (!headers.has('content-type')) {
            headers.set('content-type', layerConfig.format || 'image/jpeg');
          }
          headers.set('content-length', r2Object.size.toString());
          headers.set('etag', r2Object.httpEtag);

          // Add standard HTTP headers to satisfy strict clients
          const now = new Date();
          headers.set('date', now.toUTCString());
          headers.set('last-modified', r2Object.uploaded.toUTCString());
          headers.set('expires', new Date(now.getTime() + 31536000000).toUTCString());

          headers.set('cache-control', 'public, max-age=31536000, immutable');
          headers.set('access-control-allow-origin', '*');

          response = new Response(r2Object.body, { headers });

          // Re-populate Edge Cache
          ctx.waitUntil(cache.put(request, response.clone()));
        } else {
          console.log(`Cache/R2 miss for ${path}, fetching upstream...`);
          console.log(`Fetching: ${upstreamUrl}`);
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

            // Buffer the response to handle R2 put constraints
            const buffer = await upstreamResponse.arrayBuffer();
            const contentType = upstreamResponse.headers.get('content-type') || layerConfig.format || 'image/jpeg';
            
            const now = new Date();
            const headers = new Headers({
                'Content-Type': contentType,
                'Content-Length': buffer.byteLength.toString(),
                'Date': now.toUTCString(),
                'Last-Modified': now.toUTCString(),
                'Expires': new Date(now.getTime() + 31536000000).toUTCString(),
                'Cache-Control': 'public, max-age=31536000, immutable',
                'Access-Control-Allow-Origin': '*',
                'ETag': `"${layerSlug}-${z}-${x}-${y}"`
            });

            // Create response to cache
            response = new Response(buffer, {
                status: 200,
                headers: headers
            });
            
            // Store in R2 (background) - only for overlay layers
            if (!isBaseLayer) {
              ctx.waitUntil(env.TILES_BUCKET.put(r2Key, buffer, {
                httpMetadata: {
                  contentType: contentType,
                }
              }));
            }

            // Store in edge cache (background)
            ctx.waitUntil(cache.put(request, response.clone()));
          } catch (e) {
            return new Response(`Proxy error: ${e.message}`, { status: 500 });
          }
        }
      } else {
         console.log(`Cache hit for ${path}`);
      }

      return response;
    }

    // Map viewer
    if (path === '/' || path === '/map') {
      return new Response(getMapHtml(url.origin), {
        headers: { 'Content-Type': 'text/html; charset=utf-8' }
      });
    }

    // API: List layers as JSON
    if (path === '/layers' || path === '/api/layers') {
      return new Response(JSON.stringify({ base: BASE_LAYERS, overlays: OVERLAY_LAYERS }, null, 2), {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      });
    }

    return new Response('Not Found', { status: 404 });
  }
};
