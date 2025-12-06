# Gozdar

Gozdar is a Flutter forestry management app for Slovenia. Users can map forest parcels, track wood logging, view cadastral data, and use GPS/compass for field work.

## Project Structure

- `lib/`: Flutter application code
- `worker/`: Cloudflare Worker tile proxy

## Cloudflare Tile Proxy

The `worker/` directory contains a Cloudflare Worker that proxies and caches tiles from Slovenian government servers (`prostor.zgs.gov.si`).

### Features
- **Reprojection:** Translates standard Web Mercator (XYZ) tile requests to Slovenian National Grid (EPSG:3794).
- **Caching:** Caches rendered tiles at the edge for 1 year, significantly reducing load times and server strain.
- **Compatibility:** Makes Slovenian WMS layers available as standard XYZ tile layers for any map client.

### Deployment

1. Navigate to the worker directory:
   ```bash
   cd worker
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Deploy to your Cloudflare account:
   ```bash
   npx wrangler deploy
   ```

### Usage API

Once deployed, access layers via:
`https://<your-worker>.workers.dev/tiles/<layer-name>/{z}/{x}/{y}`

**Available Layers:**
- `ortofoto` (Aerial imagery)
- `kataster` (Cadastral parcels)
- `sestoji` (Forest stands)
- ...and 40+ others (see `worker/src/layers.js` for full list)

## Flutter Development

```bash
flutter pub get
flutter run
```
