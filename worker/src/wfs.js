/**
 * WFS (Web Feature Service) client for Slovenian cadastral data
 * Source: https://ipi.eprostor.gov.si/wfs-si-gurs-ins/cp/wfs
 */

const WFS_BASE_URL = 'https://ipi.eprostor.gov.si/wfs-si-gurs-ins/cp/wfs';

/**
 * Get cadastral parcel by coordinates (point query)
 * @param {number} lat - Latitude (WGS84)
 * @param {number} lon - Longitude (WGS84)
 * @returns {Promise<Response>}
 */
export async function getParcelByPoint(c) {
  const { lat, lon } = c.req.query();

  if (!lat || !lon) {
    return c.json({ error: 'Missing lat or lon query parameters' }, 400);
  }

  const latitude = parseFloat(lat);
  const longitude = parseFloat(lon);

  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return c.json({ error: 'Invalid coordinates' }, 400);
  }

  // Use a small bbox around the point (approx 10 meters)
  const buffer = 0.0001; // ~10 meters
  const minLon = longitude - buffer;
  const minLat = latitude - buffer;
  const maxLon = longitude + buffer;
  const maxLat = latitude + buffer;

  // Build WFS GetFeature request with bbox
  const params = new URLSearchParams({
    service: 'WFS',
    version: '2.0.0',
    request: 'GetFeature',
    typeName: 'cp:CadastralParcel',
    outputFormat: 'application/json',
    srsName: 'EPSG:4326',
    bbox: `${minLon},${minLat},${maxLon},${maxLat},EPSG:4326`,
    count: '1'
  });

  const url = `${WFS_BASE_URL}?${params.toString()}`;

  try {
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Gozdar/1.0 (Cloudflare Worker)'
      }
    });

    if (!response.ok) {
      const text = await response.text();
      console.error(`WFS error: ${response.status}`, text);
      return c.json({ error: `WFS request failed: ${response.status}` }, 502);
    }

    const data = await response.json();
    return c.json(data);
  } catch (e) {
    console.error(`WFS request error: ${e.message}`);
    return c.json({ error: `Request failed: ${e.message}` }, 500);
  }
}

/**
 * Get cadastral parcel by parcel ID
 * @param {string} id - Parcel identifier
 * @returns {Promise<Response>}
 */
export async function getParcelById(c) {
  const { id } = c.req.param();

  if (!id) {
    return c.json({ error: 'Missing parcel ID' }, 400);
  }

  const params = new URLSearchParams({
    service: 'WFS',
    version: '2.0.0',
    request: 'GetFeature',
    typeName: 'cp:CadastralParcel',
    outputFormat: 'application/json',
    srsName: 'EPSG:4326',
    featureID: id
  });

  const url = `${WFS_BASE_URL}?${params.toString()}`;

  try {
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Gozdar/1.0 (Cloudflare Worker)'
      }
    });

    if (!response.ok) {
      const text = await response.text();
      console.error(`WFS error: ${response.status}`, text);
      return c.json({ error: `WFS request failed: ${response.status}` }, 502);
    }

    const data = await response.json();
    return c.json(data);
  } catch (e) {
    console.error(`WFS request error: ${e.message}`);
    return c.json({ error: `Request failed: ${e.message}` }, 500);
  }
}

/**
 * Get parcels within bounding box
 * @param {number} minLon - Minimum longitude
 * @param {number} minLat - Minimum latitude
 * @param {number} maxLon - Maximum longitude
 * @param {number} maxLat - Maximum latitude
 * @returns {Promise<Response>}
 */
export async function getParcelsByBbox(c) {
  const { minLon, minLat, maxLon, maxLat } = c.req.query();

  if (!minLon || !minLat || !maxLon || !maxLat) {
    return c.json({ error: 'Missing bbox parameters (minLon, minLat, maxLon, maxLat)' }, 400);
  }

  // Calculate bbox size
  const lonDiff = Math.abs(parseFloat(maxLon) - parseFloat(minLon));
  const latDiff = Math.abs(parseFloat(maxLat) - parseFloat(minLat));

  // Reject if bbox is too large (approximately zoom < 15)
  // At zoom 15, typical bbox is ~0.02 degrees, we allow up to 0.05 degrees
  const MAX_BBOX_SIZE = 0.05;
  if (lonDiff > MAX_BBOX_SIZE || latDiff > MAX_BBOX_SIZE) {
    return c.json({
      error: 'Bounding box too large. Please zoom in to level 15 or higher.',
      maxSize: MAX_BBOX_SIZE,
      currentSize: { lon: lonDiff, lat: latDiff }
    }, 400);
  }

  const params = new URLSearchParams({
    service: 'WFS',
    version: '2.0.0',
    request: 'GetFeature',
    typeName: 'cp:CadastralParcel',
    outputFormat: 'application/json',
    srsName: 'EPSG:4326',
    bbox: `${minLon},${minLat},${maxLon},${maxLat},EPSG:4326`
  });

  const url = `${WFS_BASE_URL}?${params.toString()}`;

  try {
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Gozdar/1.0 (Cloudflare Worker)'
      }
    });

    if (!response.ok) {
      const text = await response.text();
      console.error(`WFS error: ${response.status}`, text);
      return c.json({ error: `WFS request failed: ${response.status}` }, 502);
    }

    const data = await response.json();
    return c.json(data);
  } catch (e) {
    console.error(`WFS request error: ${e.message}`);
    return c.json({ error: `Request failed: ${e.message}` }, 500);
  }
}

/**
 * Get cadastral parcel by KO number and parcel number (strict match)
 * @param {string} koNumber - Cadastral municipality number
 * @param {string} parcelNumber - Parcel number (e.g., "1/1" or "42")
 * @returns {Promise<Response>}
 */
export async function getParcelByKoAndNumber(c) {
  const { koNumber, parcelNumber } = c.req.param();

  if (!koNumber || !parcelNumber) {
    return c.json({ error: 'Missing koNumber or parcelNumber' }, 400);
  }

  // Construct nationalCadastralReference: "KO_NUMBER PARCEL_NUMBER"
  const cadastralRef = `${koNumber} ${parcelNumber}`;

  const params = new URLSearchParams({
    service: 'WFS',
    version: '2.0.0',
    request: 'GetFeature',
    typeName: 'cp:CadastralParcel',
    outputFormat: 'application/json',
    srsName: 'EPSG:4326',
    CQL_FILTER: `nationalCadastralReference='${cadastralRef}'`
  });

  const url = `${WFS_BASE_URL}?${params.toString()}`;

  try {
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Gozdar/1.0 (Cloudflare Worker)'
      }
    });

    if (!response.ok) {
      const text = await response.text();
      console.error(`WFS error: ${response.status}`, text);
      return c.json({ error: `WFS request failed: ${response.status}` }, 502);
    }

    const data = await response.json();
    return c.json(data);
  } catch (e) {
    console.error(`WFS request error: ${e.message}`);
    return c.json({ error: `Request failed: ${e.message}` }, 500);
  }
}

/**
 * Get cadastral municipalities (zoning)
 * @returns {Promise<Response>}
 */
export async function getCadastralZoning(c) {
  const params = new URLSearchParams({
    service: 'WFS',
    version: '2.0.0',
    request: 'GetFeature',
    typeName: 'cp:CadastralZoning',
    outputFormat: 'application/json',
    srsName: 'EPSG:4326'
  });

  const url = `${WFS_BASE_URL}?${params.toString()}`;

  try {
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Gozdar/1.0 (Cloudflare Worker)'
      }
    });

    if (!response.ok) {
      const text = await response.text();
      console.error(`WFS error: ${response.status}`, text);
      return c.json({ error: `WFS request failed: ${response.status}` }, 502);
    }

    const data = await response.json();
    return c.json(data);
  } catch (e) {
    console.error(`WFS request error: ${e.message}`);
    return c.json({ error: `Request failed: ${e.message}` }, 500);
  }
}
