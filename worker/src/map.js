import { BASE_LAYERS, OVERLAY_LAYERS } from './layers.js';

export function getMapHtml(origin) {
  // Build base layer options HTML
  const baseOptions = Object.entries(BASE_LAYERS).map(([slug, layer]) => {
    const checked = slug === 'osm' ? 'checked' : '';
    return `<label><input type="radio" name="base" value="${slug}" ${checked}> ${layer.name}</label>`;
  }).join('\n            ');

  // Build overlay checkboxes HTML grouped by category
  const overlayGroups = Object.entries(OVERLAY_LAYERS).map(([category, layers]) => {
    const checkboxes = Object.entries(layers).map(([slug, layer]) => {
      return `<label><input type="checkbox" class="overlay-cb" value="${slug}"> ${layer.name}</label>`;
    }).join('\n              ');
    return `
          <details>
            <summary>${category}</summary>
            <div class="checkbox-group">
              ${checkboxes}
            </div>
          </details>`;
  }).join('\n');

  // Serialize layer configs for JS
  const baseLayersJson = JSON.stringify(BASE_LAYERS);
  const overlayLayersJson = JSON.stringify(OVERLAY_LAYERS);

  return `<!DOCTYPE html>
<html lang="sl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Gozdar - Pregledovalnik slojev</title>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
    #map { position: absolute; top: 0; left: 0; right: 300px; bottom: 0; }
    #sidebar {
      position: absolute;
      top: 0;
      right: 0;
      width: 300px;
      height: 100%;
      background: #f8f9fa;
      overflow-y: auto;
      border-left: 1px solid #ddd;
      padding: 16px;
    }
    h2 { font-size: 18px; margin-bottom: 12px; color: #2d5016; }
    h3 { font-size: 14px; margin: 16px 0 8px; color: #555; border-bottom: 1px solid #ddd; padding-bottom: 4px; }
    .radio-group, .checkbox-group { display: flex; flex-direction: column; gap: 6px; }
    label { display: flex; align-items: center; gap: 8px; cursor: pointer; font-size: 13px; padding: 4px 0; }
    label:hover { background: #e9ecef; margin: 0 -8px; padding: 4px 8px; border-radius: 4px; }
    input[type="radio"], input[type="checkbox"] { cursor: pointer; }
    details { margin: 4px 0; }
    summary {
      cursor: pointer;
      font-weight: 500;
      padding: 8px 0;
      font-size: 13px;
      color: #333;
    }
    summary:hover { color: #2d5016; }
    details[open] summary { color: #2d5016; }
    details .checkbox-group { padding: 4px 0 8px 16px; }
    .coords {
      position: fixed;
      bottom: 8px;
      left: 8px;
      background: rgba(255,255,255,0.9);
      padding: 4px 8px;
      border-radius: 4px;
      font-size: 12px;
      font-family: monospace;
      z-index: 1000;
    }
    @media (max-width: 768px) {
      #map { right: 0; bottom: 50%; }
      #sidebar { top: 50%; width: 100%; height: 50%; }
    }
  </style>
</head>
<body>
  <div id="map"></div>
  <div id="sidebar">
    <h2>Gozdar Sloji</h2>

    <h3>Osnovni sloj</h3>
    <div class="radio-group">
      ${baseOptions}
    </div>

    <h3>Prekrivni sloji</h3>
    ${overlayGroups}
  </div>
  <div class="coords" id="coords">-</div>

  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <script>
    const ORIGIN = '${origin}';
    const BASE_LAYERS = ${baseLayersJson};
    const OVERLAY_LAYERS = ${overlayLayersJson};

    // Slovenia center
    const map = L.map('map').setView([46.15, 14.995], 9);

    // Current layers
    let baseLayer = null;
    const overlayLayers = {};

    // Create tile URL for a layer
    function getTileUrl(slug, layerConfig) {
      if (layerConfig.external) {
        return layerConfig.url;
      }
      return ORIGIN + '/tiles/' + slug + '/{z}/{x}/{y}.png';
    }

    // Set base layer
    function setBaseLayer(slug) {
      if (baseLayer) {
        map.removeLayer(baseLayer);
      }
      const config = BASE_LAYERS[slug];
      const url = getTileUrl(slug, config);
      baseLayer = L.tileLayer(url, {
        maxZoom: 19,
        attribution: config.name,
        zIndex: 0
      }).addTo(map);
    }

    // Toggle overlay layer
    function toggleOverlay(slug, enabled) {
      if (enabled) {
        if (!overlayLayers[slug]) {
          const url = ORIGIN + '/tiles/' + slug + '/{z}/{x}/{y}.png';
          overlayLayers[slug] = L.tileLayer(url, {
            maxZoom: 19,
            opacity: 0.8,
            zIndex: 10
          }).addTo(map);
        }
      } else {
        if (overlayLayers[slug]) {
          map.removeLayer(overlayLayers[slug]);
          delete overlayLayers[slug];
        }
      }
    }

    // Initialize with OSM
    setBaseLayer('osm');

    // Base layer radio buttons
    document.querySelectorAll('input[name="base"]').forEach(radio => {
      radio.addEventListener('change', (e) => {
        setBaseLayer(e.target.value);
      });
    });

    // Overlay checkboxes
    document.querySelectorAll('.overlay-cb').forEach(cb => {
      cb.addEventListener('change', (e) => {
        toggleOverlay(e.target.value, e.target.checked);
      });
    });

    // Show coordinates on mouse move
    const coordsEl = document.getElementById('coords');
    map.on('mousemove', (e) => {
      coordsEl.textContent = e.latlng.lat.toFixed(5) + ', ' + e.latlng.lng.toFixed(5);
    });

    // URL state management
    function updateUrl() {
      const base = document.querySelector('input[name="base"]:checked').value;
      const overlays = Array.from(document.querySelectorAll('.overlay-cb:checked')).map(cb => cb.value);
      const center = map.getCenter();
      const zoom = map.getZoom();
      const hash = '#' + [zoom, center.lat.toFixed(5), center.lng.toFixed(5), base, ...overlays].join('/');
      history.replaceState(null, '', hash);
    }

    function loadFromUrl() {
      const hash = location.hash.slice(1);
      if (!hash) return;
      const parts = hash.split('/');
      if (parts.length >= 4) {
        const [zoom, lat, lng, base, ...overlays] = parts;
        map.setView([parseFloat(lat), parseFloat(lng)], parseInt(zoom));

        // Set base layer
        const baseRadio = document.querySelector('input[name="base"][value="' + base + '"]');
        if (baseRadio) {
          baseRadio.checked = true;
          setBaseLayer(base);
        }

        // Set overlays
        overlays.forEach(slug => {
          const cb = document.querySelector('.overlay-cb[value="' + slug + '"]');
          if (cb) {
            cb.checked = true;
            toggleOverlay(slug, true);
          }
        });
      }
    }

    loadFromUrl();
    map.on('moveend', updateUrl);
    document.querySelectorAll('input').forEach(el => el.addEventListener('change', updateUrl));
  </script>
</body>
</html>`;
}
