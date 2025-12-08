import proj4 from 'proj4';
import { LAYERS } from './layers.js';

// Define Projections
proj4.defs('EPSG:3794', '+proj=tmerc +lat_0=0 +lon_0=15 +k=0.9999 +x_0=500000 +y_0=-5000000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs +type=crs');
proj4.defs('EPSG:3857', '+proj=merc +a=6378137 +b=6378137 +lat_ts=0 +lon_0=0 +x_0=0 +y_0=0 +k=1 +units=m +nadgrids=@null +wktext +no_defs +type=crs');

// Constants for Web Mercator
const R = 6378137;

// Slovenia Bounds (EPSG:3794)
const SLOVENIA_BOUNDS = {
  minX: 300000,
  maxX: 700000,
  minY: 10000,
  maxY: 300000
};

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

/**
 * Check if tile is within Slovenia bounds
 */
function isWithinSlovenia(bbox3794) {
  return !(bbox3794.maxX < SLOVENIA_BOUNDS.minX ||
           bbox3794.minX > SLOVENIA_BOUNDS.maxX ||
           bbox3794.maxY < SLOVENIA_BOUNDS.minY ||
           bbox3794.minY > SLOVENIA_BOUNDS.maxY);
}

/**
 * Construct WMS URL for tile request
 */
function buildWmsUrl(layerConfig, bbox3794) {
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

  return `${layerConfig.baseUrl}?${params.toString()}`;
}

/**
 * Fetch tile from upstream WMS service
 */
async function fetchUpstreamTile(layerConfig, bbox3794) {
  const upstreamUrl = buildWmsUrl(layerConfig, bbox3794);

  console.log(`Fetching: ${upstreamUrl}`);

  const upstreamResponse = await fetch(upstreamUrl, {
    headers: {
      'User-Agent': 'Gozdar/1.0 (Cloudflare Worker Proxy)'
    }
  });

  if (!upstreamResponse.ok) {
    const text = await upstreamResponse.text();
    console.log(`Upstream failed: ${upstreamResponse.status} ${upstreamResponse.statusText}`);
    console.log(`Body: ${text}`);
    throw new Error(`Upstream error: ${upstreamResponse.status} - ${upstreamResponse.statusText}\n${text}`);
  }

  return upstreamResponse;
}

/**
 * Create response with proper headers
 */
function createTileResponse(buffer, contentType, layerSlug, z, x, y) {
  const now = new Date();
  const headers = new Headers({
    'Content-Type': contentType,
    'Content-Length': buffer.byteLength.toString(),
    'Date': now.toUTCString(),
    'Last-Modified': now.toUTCString(),
    'Expires': new Date(now.getTime() + 86400000).toUTCString(),
    'Cache-Control': 'public, max-age=86400',
    'Access-Control-Allow-Origin': '*',
    'ETag': `"v2-${layerSlug}-${z}-${x}-${y}"`
  });

  return new Response(buffer, {
    status: 200,
    headers: headers
  });
}

/**
 * Handle tile request
 */
export async function handleTileRequest(c) {
  const params = c.req.param();
  const layerSlug = params.layer;
  const zStr = params.z;
  const xStr = params.x;

  // Handle both 'y' and 'filename' parameter (filename may have .png/.jpg/.jpeg extension)
  let yStr = params.y || params.filename;
  if (yStr && yStr.includes('.')) {
    yStr = yStr.replace(/\.(png|jpg|jpeg)$/i, '');
  }

  console.log(`Tile request params:`, { layerSlug, zStr, xStr, yStr });

  // Parse and validate coordinates
  const z = parseInt(zStr, 10);
  const x = parseInt(xStr, 10);
  const y = parseInt(yStr, 10);

  if (!Number.isFinite(z) || !Number.isFinite(x) || !Number.isFinite(y)) {
    console.error(`Invalid coordinates: z=${zStr}, x=${xStr}, y=${yStr}`);
    return c.json({ error: 'Invalid tile coordinates' }, 400);
  }

  // Return 404 for zoom levels below 15
  if (z < 15) {
    return c.json({ error: 'Zoom level too low. Minimum zoom: 15' }, 404);
  }

  const layerConfig = LAYERS[layerSlug];
  if (!layerConfig) {
    return c.json({ error: 'Layer not found' }, 404);
  }

  // Check if this is a base layer (no R2 caching for base layers)
  const isBaseLayer = ['ortofoto', 'ortofoto-2023', 'ortofoto-2022', 'dof-ir', 'dmr'].includes(layerSlug);

  // Calculate bounding boxes
  const bbox3857 = xyzToBbox(x, y, z);

  // Validate bbox before reprojection
  if (!Number.isFinite(bbox3857.minX) || !Number.isFinite(bbox3857.minY) ||
      !Number.isFinite(bbox3857.maxX) || !Number.isFinite(bbox3857.maxY)) {
    console.error(`Invalid bbox3857: ${JSON.stringify(bbox3857)}, coords: z=${z}, x=${x}, y=${y}`);
    return c.json({ error: 'Invalid bounding box' }, 500);
  }

  let bbox3794;
  try {
    bbox3794 = reprojectBbox(bbox3857, 'EPSG:3857', 'EPSG:3794');
  } catch (e) {
    console.error(`Reprojection error: ${e.message}`, { bbox3857, z, x, y });
    return c.json({ error: `Reprojection failed: ${e.message}` }, 500);
  }

  // Return 404 if outside Slovenia bounds
  if (!isWithinSlovenia(bbox3794)) {
    return c.json({ error: 'Tile outside Slovenia bounds' }, 404);
  }

  // Build R2 key
  const ext = layerConfig.format === 'image/jpeg' ? 'jpg' : 'png';
  const r2Key = `${layerSlug}/${z}/${x}/${y}.${ext}`;

  // Try R2 cache first (only for overlay layers)
  if (!isBaseLayer && c.env.TILES_BUCKET) {
    try {
      const r2Object = await c.env.TILES_BUCKET.get(r2Key);

      if (r2Object) {
        console.log(`R2 hit for ${r2Key}`);
        const headers = new Headers();
        r2Object.writeHttpMetadata(headers);

        if (!headers.has('content-type')) {
          headers.set('content-type', layerConfig.format || 'image/jpeg');
        }
        headers.set('content-length', r2Object.size.toString());
        headers.set('etag', r2Object.httpEtag);

        const now = new Date();
        headers.set('date', now.toUTCString());
        headers.set('last-modified', r2Object.uploaded.toUTCString());
        headers.set('expires', new Date(now.getTime() + 86400000).toUTCString());
        headers.set('cache-control', 'public, max-age=86400');
        headers.set('access-control-allow-origin', '*');

        const response = new Response(r2Object.body, { headers });

        // Re-populate Edge Cache with versioned key
        const cacheUrl = new URL(c.req.url);
        cacheUrl.searchParams.set('_v', 'v2');
        const cacheKey = new Request(cacheUrl.toString(), c.req.raw);
        c.executionCtx.waitUntil(caches.default.put(cacheKey, response.clone()));

        return response;
      }
    } catch (e) {
      console.error(`R2 Error: ${e.message}`);
    }
  }

  // Fetch from upstream
  console.log(`Cache/R2 miss, fetching upstream...`);

  try {
    const upstreamResponse = await fetchUpstreamTile(layerConfig, bbox3794);
    const buffer = await upstreamResponse.arrayBuffer();
    const contentType = upstreamResponse.headers.get('content-type') || layerConfig.format || 'image/jpeg';

    // Don't cache suspiciously small images (likely empty/error tiles)
    // Minimum realistic tile size is ~1800 bytes
    const MIN_TILE_SIZE = 1800;
    const shouldCache = buffer.byteLength >= MIN_TILE_SIZE;

    if (!shouldCache) {
      console.log(`Skipping cache for small tile: ${buffer.byteLength} bytes`);
    }

    const response = createTileResponse(buffer, contentType, layerSlug, z, x, y);

    // Store in R2 (background) - only for overlay layers and valid tiles
    if (shouldCache && !isBaseLayer && c.env.TILES_BUCKET) {
      c.executionCtx.waitUntil(c.env.TILES_BUCKET.put(r2Key, buffer, {
        httpMetadata: {
          contentType: contentType,
        }
      }));
    }

    // Store in edge cache (background) with versioned key - only valid tiles
    if (shouldCache) {
      const cacheUrl = new URL(c.req.url);
      cacheUrl.searchParams.set('_v', 'v2');
      const cacheKey = new Request(cacheUrl.toString(), c.req.raw);
      c.executionCtx.waitUntil(caches.default.put(cacheKey, response.clone()));
    }

    return response;
  } catch (e) {
    return c.json({ error: `Proxy error: ${e.message}` }, 500);
  }
}
