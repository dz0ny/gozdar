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
    #map { position: absolute; top: 0; left: 0; right: 300px; bottom: 0; cursor: crosshair; }
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
    .parcel-label {
      background: rgba(255, 255, 255, 0.9) !important;
      border: 1px solid #e65100 !important;
      border-radius: 3px !important;
      padding: 2px 6px !important;
      font-size: 11px !important;
      font-weight: 600 !important;
      color: #e65100 !important;
      box-shadow: 0 1px 3px rgba(0,0,0,0.2) !important;
    }
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

    <div style="background: #e3f2fd; padding: 8px; margin-bottom: 12px; border-radius: 4px; font-size: 12px; border-left: 3px solid #2d5016;">
      <strong>💡 Nasvet:</strong> Kliknite na karto za prikaz meje parcele in podatkov<br>
      <small style="color: #666;">Kataster deluje pri zoom ≥ 15</small>
    </div>

    <div style="margin-bottom: 12px;">
      <label style="display: flex; align-items: center; gap: 8px; cursor: pointer; padding: 8px; background: #f0f0f0; border-radius: 4px;">
        <input type="checkbox" id="useVectorKataster" style="cursor: pointer;">
        <span style="font-size: 13px; font-weight: 500;">🎯 Uporabi vektorski kataster (WFS)</span>
      </label>
      <div id="vectorStatus" style="font-size: 10px; color: #666; margin-top: 4px; padding: 0 8px;">
        Prikaže parcele kot vektorje. Zahteva zoom ≥ 15.
      </div>
    </div>

    <div style="margin-bottom: 12px;">
      <button id="selectAreaBtn" style="width: 100%; padding: 8px; background: #2d5016; color: white; border: none; border-radius: 4px; cursor: pointer; font-weight: 500;">
        📦 Izvozi območje kot GeoJSON
      </button>
      <div id="areaStatus" style="font-size: 11px; margin-top: 4px; color: #666; text-align: center;"></div>
    </div>

    <h3>Osnovni sloj</h3>
    <div class="radio-group">
      ${baseOptions}
    </div>

    <h3>Prekrivni sloji</h3>
    ${overlayGroups}

    <details style="margin-top: 20px;">
      <summary style="font-weight: 600; color: #2d5016;">API Endpoints</summary>
      <div style="font-size: 11px; padding: 8px 0; line-height: 1.6;">
        <strong>WFS Cadastral Data:</strong><br>
        <code style="display: block; background: #e9ecef; padding: 4px; margin: 4px 0; border-radius: 2px;">/api/wfs/parcel/point?lat=46.05&lon=14.5</code>
        <code style="display: block; background: #e9ecef; padding: 4px; margin: 4px 0; border-radius: 2px;">/api/wfs/parcel/{id}</code>
        <code style="display: block; background: #e9ecef; padding: 4px; margin: 4px 0; border-radius: 2px;">/api/wfs/parcels/bbox?minLon=14.5&minLat=46&maxLon=14.6&maxLat=46.1</code>
        <code style="display: block; background: #e9ecef; padding: 4px; margin: 4px 0; border-radius: 2px;">/api/wfs/zoning</code>
        <br>
        <strong>Layers Config:</strong><br>
        <code style="display: block; background: #e9ecef; padding: 4px; margin: 4px 0; border-radius: 2px;">/api/layers</code>
      </div>
    </details>
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

    // Click to query parcel
    let queryMarker = null;
    let queryPopup = null;
    let parcelLayer = null;

    map.on('click', async (e) => {
      const lat = e.latlng.lat;
      const lng = e.latlng.lng;

      // Remove previous marker and parcel layer
      if (queryMarker) {
        map.removeLayer(queryMarker);
      }
      if (parcelLayer) {
        map.removeLayer(parcelLayer);
      }

      // Add marker at clicked location
      queryMarker = L.marker([lat, lng]).addTo(map);

      // Show loading popup
      queryPopup = L.popup()
        .setLatLng([lat, lng])
        .setContent('<div style="padding: 10px;">Poizvedovanje...<br><small>Pridobivanje podatkov o parceli</small></div>')
        .openOn(map);

      try {
        // Query WFS for parcel at this point
        const response = await fetch(ORIGIN + '/api/wfs/parcel/point?lat=' + lat + '&lon=' + lng);
        const data = await response.json();

        if (!response.ok) {
          throw new Error(data.error || 'Query failed');
        }

        // Check if we got features
        if (data.features && data.features.length > 0) {
          const feature = data.features[0];
          const props = feature.properties;

          // Store feature data globally for JSON export
          window.lastParcelFeature = feature;

          // Render parcel boundary on map
          if (feature.geometry) {
            parcelLayer = L.geoJSON(feature, {
              style: {
                color: '#2d5016',
                weight: 3,
                opacity: 0.8,
                fillColor: '#4CAF50',
                fillOpacity: 0.2
              }
            }).addTo(map);

            // Fit map to parcel bounds
            const bounds = parcelLayer.getBounds();
            if (bounds.isValid()) {
              map.fitBounds(bounds, { padding: [50, 50], maxZoom: 17 });
            }
          }

          // Build parcel info HTML
          let html = '<div style="min-width: 250px;"><strong>Parcela</strong><br>';

          // Helper to safely display values
          const displayValue = (val) => {
            if (val === null || val === undefined) return '';
            if (typeof val === 'object') return JSON.stringify(val, null, 2);
            return val;
          };

          // Display key properties
          if (props.label) {
            html += '<b>Oznaka:</b> ' + props.label + '<br>';
          }

          if (props.inspireId) {
            html += '<b>ID:</b> <pre style="display: inline; background: #f0f0f0; padding: 2px 4px; font-size: 10px;">' + displayValue(props.inspireId) + '</pre><br>';
          }

          if (props.areaValue) {
            html += '<b>Površina:</b> <pre style="display: inline; background: #f0f0f0; padding: 2px 4px; font-size: 10px;">' + displayValue(props.areaValue) + '</pre><br>';
          }

          // Show all other properties
          const displayedKeys = ['label', 'inspireId', 'areaValue', 'geometry'];
          const otherProps = Object.keys(props).filter(k => !displayedKeys.includes(k));

          if (otherProps.length > 0) {
            html += '<details style="margin-top: 8px;"><summary style="cursor: pointer;">Več podatkov (' + otherProps.length + ')</summary>';
            html += '<div style="max-height: 200px; overflow-y: auto; font-size: 11px;">';
            otherProps.forEach(key => {
              const val = displayValue(props[key]);
              if (val) {
                html += '<b>' + key + ':</b><br>';
                html += '<pre style="background: #f0f0f0; padding: 4px; margin: 2px 0; white-space: pre-wrap; word-break: break-all;">' + val + '</pre>';
              }
            });
            html += '</div></details>';
          }

          // Add buttons for JSON export
          html += '<div style="margin-top: 10px; display: flex; gap: 5px;">';
          html += '<button onclick="window.showParcelJSON()" style="flex: 1; padding: 6px; background: #2d5016; color: white; border: none; border-radius: 3px; cursor: pointer; font-size: 11px;">Prikaži JSON</button>';
          html += '<button onclick="window.downloadParcelJSON()" style="flex: 1; padding: 6px; background: #4CAF50; color: white; border: none; border-radius: 3px; cursor: pointer; font-size: 11px;">Prenesi GeoJSON</button>';
          html += '</div>';

          html += '</div>';
          queryPopup.setContent(html);
        } else {
          queryPopup.setContent('<div style="padding: 10px;">Ni podatkov<br><small>Na tej lokaciji ni najdena parcela</small></div>');
        }
      } catch (error) {
        console.error('Parcel query error:', error);
        queryPopup.setContent('<div style="padding: 10px; color: #c00;">Napaka<br><small>' + error.message + '</small></div>');
      }
    });

    // Helper functions for JSON export
    window.showParcelJSON = function() {
      if (window.lastParcelFeature) {
        const json = JSON.stringify(window.lastParcelFeature, null, 2);
        const popup = L.popup({ maxWidth: 600, maxHeight: 400 })
          .setLatLng(map.getCenter())
          .setContent('<div style="max-height: 400px; overflow: auto;"><strong>GeoJSON Feature</strong><pre style="background: #f0f0f0; padding: 10px; font-size: 10px; white-space: pre-wrap; word-break: break-all;">' + json + '</pre></div>')
          .openOn(map);
      }
    };

    window.downloadParcelJSON = function() {
      if (window.lastParcelFeature) {
        const json = JSON.stringify(window.lastParcelFeature, null, 2);
        const blob = new Blob([json], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'parcel-' + (window.lastParcelFeature.properties.label || 'unknown') + '.geojson';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
      }
    };

    // Vector cadastral layer (WFS)
    let vectorKatasterLayer = null;
    let useVectorKataster = false;
    let loadingVector = false;

    async function loadVectorKataster() {
      if (!useVectorKataster || loadingVector) return;

      const zoom = map.getZoom();
      const status = document.getElementById('vectorStatus');

      if (zoom < 15) {
        if (vectorKatasterLayer) {
          map.removeLayer(vectorKatasterLayer);
          vectorKatasterLayer = null;
        }
        status.textContent = 'Povečajte do zoom 15 ali več';
        status.style.color = '#ff9800';
        return;
      }

      loadingVector = true;
      status.textContent = 'Nalaganje parcel...';
      status.style.color = '#2d5016';

      const bounds = map.getBounds();
      const minLon = bounds.getWest();
      const minLat = bounds.getSouth();
      const maxLon = bounds.getEast();
      const maxLat = bounds.getNorth();

      try {
        const url = ORIGIN + '/api/wfs/parcels/bbox?minLon=' + minLon + '&minLat=' + minLat + '&maxLon=' + maxLon + '&maxLat=' + maxLat;
        const response = await fetch(url);
        const data = await response.json();

        if (response.ok && data.features && data.features.length > 0) {
          // Remove old layer
          if (vectorKatasterLayer) {
            map.removeLayer(vectorKatasterLayer);
          }

          // Add new layer
          vectorKatasterLayer = L.geoJSON(data, {
            style: {
              color: '#e65100',
              weight: 2,
              opacity: 0.8,
              fillColor: '#ff9800',
              fillOpacity: 0.1
            },
            onEachFeature: (feature, layer) => {
              if (feature.properties && feature.properties.label) {
                layer.bindTooltip(feature.properties.label, {
                  permanent: false,
                  direction: 'center',
                  className: 'parcel-label'
                });
              }
            }
          }).addTo(map);

          status.textContent = 'Prikazanih ' + data.features.length + ' parcel';
          status.style.color = '#4CAF50';
        } else {
          status.textContent = 'Ni parcel na tem območju';
          status.style.color = '#999';
        }
      } catch (error) {
        console.error('Vector load error:', error);
        status.textContent = 'Napaka pri nalaganju';
        status.style.color = '#d32f2f';
      } finally {
        loadingVector = false;
      }
    }

    document.getElementById('useVectorKataster').addEventListener('change', function(e) {
      useVectorKataster = e.target.checked;

      if (useVectorKataster) {
        // Hide WMS kataster layers
        if (overlayLayers['kataster']) {
          map.removeLayer(overlayLayers['kataster']);
        }
        if (overlayLayers['kataster-nazivi']) {
          map.removeLayer(overlayLayers['kataster-nazivi']);
        }
        loadVectorKataster();
      } else {
        // Remove vector layer
        if (vectorKatasterLayer) {
          map.removeLayer(vectorKatasterLayer);
          vectorKatasterLayer = null;
        }
        // Restore WMS layers if they were checked
        const katasterCb = document.querySelector('.overlay-cb[value="kataster"]');
        const naziviCb = document.querySelector('.overlay-cb[value="kataster-nazivi"]');
        if (katasterCb && katasterCb.checked) {
          toggleOverlay('kataster', true);
        }
        if (naziviCb && naziviCb.checked) {
          toggleOverlay('kataster-nazivi', true);
        }
      }
    });

    map.on('moveend', function() {
      if (useVectorKataster) {
        loadVectorKataster();
      }
    });

    // Area selection for bulk export
    let selectingArea = false;
    let areaRect = null;
    let areaStartPoint = null;

    document.getElementById('selectAreaBtn').addEventListener('click', function() {
      selectingArea = !selectingArea;
      const btn = this;
      const status = document.getElementById('areaStatus');

      if (selectingArea) {
        btn.textContent = '❌ Prekliči izbiro';
        btn.style.background = '#d32f2f';
        status.textContent = 'Kliknite in povlecite pravokotnik na karti';
        map.getContainer().style.cursor = 'crosshair';
      } else {
        btn.textContent = '📦 Izberi območje za izvoz';
        btn.style.background = '#2d5016';
        status.textContent = '';
        map.getContainer().style.cursor = '';
        if (areaRect) {
          map.removeLayer(areaRect);
          areaRect = null;
        }
      }
    });

    map.on('mousedown', function(e) {
      if (!selectingArea) return;
      areaStartPoint = e.latlng;
      if (areaRect) {
        map.removeLayer(areaRect);
      }
    });

    map.on('mousemove', function(e) {
      if (!selectingArea || !areaStartPoint) return;

      if (areaRect) {
        map.removeLayer(areaRect);
      }

      const bounds = L.latLngBounds(areaStartPoint, e.latlng);
      areaRect = L.rectangle(bounds, {
        color: '#2d5016',
        weight: 2,
        fillOpacity: 0.1
      }).addTo(map);
    });

    map.on('mouseup', async function(e) {
      if (!selectingArea || !areaStartPoint) return;

      const bounds = L.latLngBounds(areaStartPoint, e.latlng);
      const minLon = bounds.getWest();
      const minLat = bounds.getSouth();
      const maxLon = bounds.getEast();
      const maxLat = bounds.getNorth();

      areaStartPoint = null;
      selectingArea = false;

      const btn = document.getElementById('selectAreaBtn');
      const status = document.getElementById('areaStatus');
      btn.textContent = '📦 Izberi območje za izvoz';
      btn.style.background = '#2d5016';
      map.getContainer().style.cursor = '';

      // Fetch parcels in bbox
      status.textContent = 'Pridobivanje parcel...';
      status.style.color = '#2d5016';

      try {
        const url = ORIGIN + '/api/wfs/parcels/bbox?minLon=' + minLon + '&minLat=' + minLat + '&maxLon=' + maxLon + '&maxLat=' + maxLat;
        const response = await fetch(url);
        const data = await response.json();

        if (!response.ok) {
          throw new Error(data.error || 'Query failed');
        }

        const count = data.features ? data.features.length : 0;
        status.textContent = 'Najdenih ' + count + ' parcel';
        status.style.color = '#4CAF50';

        if (count > 0) {
          // Download as GeoJSON
          const json = JSON.stringify(data, null, 2);
          const blob = new Blob([json], { type: 'application/json' });
          const downloadUrl = URL.createObjectURL(blob);
          const a = document.createElement('a');
          a.href = downloadUrl;
          a.download = 'parcels-' + count + '-' + new Date().toISOString().split('T')[0] + '.geojson';
          document.body.appendChild(a);
          a.click();
          document.body.removeChild(a);
          URL.revokeObjectURL(downloadUrl);

          setTimeout(() => {
            status.textContent = '';
          }, 3000);
        }

        // Remove rectangle
        if (areaRect) {
          map.removeLayer(areaRect);
          areaRect = null;
        }
      } catch (error) {
        console.error('Area query error:', error);
        status.textContent = 'Napaka: ' + error.message;
        status.style.color = '#d32f2f';
      }
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
