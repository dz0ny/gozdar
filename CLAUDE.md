# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Important: Use Bun

This project uses **bun** instead of npm/node. Always use:
- `bun` instead of `npm`
- `bunx` instead of `npx`
- Never run `npm` or `npx` commands

## Project Overview

Gozdar is a Flutter forestry management app for Slovenia. Users can map forest parcels, track wood logging, view cadastral data, and use GPS/compass for field work.

## Build Commands

```bash
flutter pub get          # Install dependencies
flutter run              # Run in development
flutter analyze          # Check for issues
flutter test             # Run tests
flutter build ios        # Build for iOS
flutter build android    # Build for Android
flutter build macos      # Build for macOS
```

## Architecture

### Service Layer (Singletons)
All services use singleton pattern:
- `DatabaseService` - SQLite (sqflite) with schema v4, tables: parcels, logs, locations
- `CadastralService` - WMS GetFeatureInfo queries to prostor.zgs.gov.si (30s timeout)
- `HttpCacheService` - 1-year HTTP cache for Slovenian government APIs
- `TileCacheService` - ObjectBox-backed tile caching
- `OnboardingService` - First-run wizard state (SharedPreferences)
- `MapPreferencesService` - Map layer preferences, defaults: Ortofoto + Kataster + Kataster z nazivi
- `ExportService` - Excel (.xlsx) export for logs

### Key Models
- `Parcel` - Forest polygon with cadastral data (KO + parcel number), wood tracking (allowance/cut)
- `LogEntry` - Wood log with cylinder volume calculation: V = π × (d/200)² × L
- `MapLayer` - WMS/tile layer configuration with 40+ Slovenian overlay layers

### Volume Conversions (Hlodi tab)
Displays total m³ with conversions:
- **PRM** (prostorninski meter) = m³ × factor (default 0.65) - stacked firewood
- **NM** (nasuti meter) = m³ × factor (default 0.40) - loose chips/pieces
- Factors configurable via settings sheet

### Navigation
3-tab bottom navigation: Karta (Map), Gozd (Forest), Hlodi (Logs)
- Default tab: Gozd (Forest) - index 1
- 5-tap on any tab resets onboarding wizard
- First-run shows `IntroWizardScreen` with 5 pages explaining app features

## Critical: Slovenian CRS (EPSG:3794)

All Slovenian WMS layers require custom coordinate system defined in `lib/utils/slovenian_crs.dart`:
- Transverse Mercator projection at longitude 15°
- 16 zoom levels with specific resolutions
- **Always use this CRS for prostor.zgs.gov.si layers**

Coordinate handling pattern:
- Store as WGS84 (LatLng) internally
- Convert to EPSG:3794 only for WMS requests using proj4dart

Marker visibility thresholds (different zoom scales):
- Slovenian WMS layers: zoom ≥ 11
- Standard Web Mercator: zoom ≥ 15

## Map Layer Configuration

Layers defined in `lib/models/map_layer.dart`:
- Base layers: OSM, TopoMap, ESRI, Google, Ortofoto, DTK25
- Overlay layers use WMS from `prostor.zgs.gov.si/geoserver/wms`
- Slovenian layers only visible when base layer is also Slovenian (isSlovenian getter)

## Database Schema

```sql
-- parcels table
id, name, polygon (JSON), cadastral_municipality, parcel_number,
owner, wood_allowance, wood_cut, created_at
-- Unique constraint on (cadastral_municipality, parcel_number)

-- logs table
id, diameter, length, volume, latitude, longitude, notes, created_at

-- locations table
id, name, latitude, longitude, created_at
```

## UI Language

App uses Slovenian strings: Karta, Gozd, Hlodi, Parcela, Posek, etc.
