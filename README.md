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

### Configuration in App

1. Open the app.
2. Triple-tap the "Karta" tab icon.
3. Enter your worker URL (e.g. `https://your-worker.workers.dev`).
4. Tap Save.

## Flutter Development

```bash
flutter pub get
flutter run
```
