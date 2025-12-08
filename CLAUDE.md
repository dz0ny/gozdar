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
flutter analyze          # Check for issues (ALWAYS use this, never build)
flutter test             # Run tests
flutter build ios        # Build for iOS
flutter build android    # Build for Android
flutter build macos      # Build for macOS
```

**IMPORTANT:** When checking code quality, ONLY use `flutter analyze`. Never run build commands unless explicitly requested by the user.

## Android Signing Configuration

Production keystore is stored **outside the project directory** at `~/android-keystores/gozdar-release-key.jks` to prevent deletion by `flutter clean`.

### Configuration Files
- **Keystore location:** `~/android-keystores/gozdar-release-key.jks`
- **Key alias:** `gozdar-release`
- **Credentials:** Stored in `android/key.properties` (gitignored)

### Backup & Security
- **IMPORTANT:** Backup the keystore file and passwords securely
- The keystore cannot be regenerated if lost
- `key.properties` is gitignored and should never be committed
- Default passwords are set to `gozdar2024` (change for production use)

### Regenerating Keystore (if needed)
```bash
keytool -genkey -v -keystore ~/android-keystores/gozdar-release-key.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 \
  -alias gozdar-release
```

After regenerating, update `android/key.properties` with new passwords.

## Versioning System

The Makefile manages version numbers in the format: `YYYY.MMDD.DAILY+BUILD`

### Version Components
- **YYYY.MMDD.DAILY**: Human-readable version name (e.g., `2025.1208.3`)
  - YYYY: Year
  - MMDD: Month and day
  - DAILY: Daily build counter (resets to 1 each day)
- **BUILD**: Android version code (after the `+`)
  - **CRITICAL**: Must ALWAYS increment, never decrease
  - Android refuses to install APKs with lower version codes (security feature)
  - Never resets, even on new days

### Commands
```bash
make version    # Show current and next version
make bump       # Increment version in pubspec.yaml
make build      # Auto-bump version and build APK
```

### Why This Matters
If version codes decrease (e.g., from 9 to 2 on date change), Android shows "package corrupted" error on updates. Users must uninstall first, losing data. The Makefile now ensures BUILD always increments to prevent this.

## Architecture

### Service Layer (Singletons)
All services use singleton pattern:
- `DatabaseService` - ObjectBox database with entities: parcels, logs, log_batches, locations
- `CadastralService` - WMS GetFeatureInfo queries to prostor.zgs.gov.si (30s timeout)
- `HttpCacheService` - 1-year HTTP cache for Slovenian government APIs
- `TileCacheService` - ObjectBox-backed tile caching
- `OnboardingService` - First-run wizard state (SharedPreferences)
- `MapPreferencesService` - Map layer preferences, defaults: Ortofoto + Kataster + Kataster z nazivi
- `SpeciesService` - Tree species management (SharedPreferences), defaults: Smreka, Bukev, Jelka
- `ExportService` - Excel (.xlsx) export for logs

### Key Models
- `Parcel` - Forest polygon with cadastral data (KO + parcel number), wood tracking (allowance/cut)
  - Fields: name, polygonJson, cadastralMunicipality, parcelNumber, owner, **notes**, forestTypeIndex, woodAllowance, woodCut, treesCut, createdAt
  - Relations: ToMany<LogEntry> (backlink from logs)
- `LogEntry` - Wood log with species tracking, cylinder volume calculation: V = π × (d/200)² × L
  - Fields: diameter, length, volume, latitude, longitude, notes, **species**, createdAt
  - Relations: ToOne<LogBatch>, ToOne<Parcel>
- `MapLayer` - WMS/tile layer configuration with 40+ Slovenian overlay layers

### Hlodi (Logs) Tab Features
**Volume Conversions:**
- Displays total m³ with conversions:
  - **PRM** (prostorninski meter) = m³ × factor (default 0.65) - stacked firewood
  - **NM** (nasuti meter) = m³ × factor (default 0.40) - loose chips/pieces
  - Factors configurable via settings sheet

**Species Tracking:**
- Each log can have a species assigned (Smreka, Bukev, Jelka, or custom)
- Logs automatically grouped by species when 2+ species exist (progressive enhancement)
- Species headers show count and total volume per species (e.g., "3 hlodov • 1.25 m³")
- Species management accessible via ⋮ menu → "Upravljanje vrst"
- Users can add/remove species via SpeciesService

### Navigation
3-tab bottom navigation: Karta (Map), Gozd (Forest), Hlodi (Logs)
- Default tab: Gozd (Forest) - index 1
- 5-tap on any tab resets onboarding wizard
- First-run shows `IntroWizardScreen` with 9 pages explaining app features

### Onboarding (IntroWizardScreen)
9-page wizard with unified design pattern (icon circle + info card):
1. **Dobrodošli v Gozdar** - Welcome and app overview
2. **Navigacija** - 3-tab navigation explanation
3. **Beleženje hlodovine** - Log tracking with species, auto-calculation, grouping
4. **Dolg pritisk na karti** - Long press menu (add point, log, cutting, import parcel)
5. **Označbe na karti** - Map markers (red=locations, brown=logs, orange=cuttings)
6. **Sloji na karti** - Map layers (Ortofoto, Kataster, etc.)
7. **Delo brez povezave** - Offline mode and caching
8. **Navigacija do mejnika** - Compass navigation to boundary points
9. **Pogoji uporabe** - Terms of use and data attribution

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

## Database Schema (ObjectBox)

**Entities:**
- `Parcel` - id, name, polygonJson, cadastralMunicipality, parcelNumber, owner, **notes**, forestTypeIndex, woodAllowance, woodCut, treesCut, createdAt
  - Unique constraint on (cadastralMunicipality, parcelNumber)
  - ToMany<LogEntry> backlink
- `LogEntry` - id, diameter, length, volume, latitude, longitude, notes, **species**, createdAt
  - Relations: ToOne<LogBatch>, ToOne<Parcel>
  - **IMPORTANT:** batchId and parcelId getters are marked @Transient() to avoid ObjectBox conflicts
- `LogBatch` - id, name, totalVolume, logCount, prmFactor, nmFactor, createdAt
- `Location` - id, name, latitude, longitude, createdAt
- `HttpCacheEntry` - url, response, createdAt, expiresAt

## UI Language

App uses Slovenian strings: Karta, Gozd, Hlodi, Parcela, Posek, etc.
