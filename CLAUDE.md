# CLAUDE.md

Guidance for Claude Code when working with this Flutter forestry management app for Slovenia.

## Project Overview

**Gozdar** - Forest parcel mapping, wood logging, cadastral data integration, GPS/compass navigation.

## Development

**Commands:**
```bash
flutter pub get     # Install dependencies
flutter run         # Development mode
flutter analyze     # Code quality check (USE THIS, not build)
flutter test        # Run tests
make version        # Show version info
make bump           # Increment version
make build          # Bump version + build APK
```

**CRITICAL:** Use `flutter analyze` for code quality checks, NOT build commands unless explicitly requested.

## Build Configuration

### Android Signing
- **Keystore:** `~/android-keystores/gozdar-release-key.jks` (outside project, survives `flutter clean`)
- **Alias:** `gozdar-release`
- **Credentials:** `android/key.properties` (gitignored, default password: `gozdar2024`)
- **CRITICAL:** Backup keystore securely - cannot be regenerated if lost

**Regenerate if needed:**
```bash
keytool -genkey -v -keystore ~/android-keystores/gozdar-release-key.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias gozdar-release
```

### Versioning (YYYY.MMDD.DAILY+BUILD)
- **Version name:** `2025.1208.3` (year.date.daily-counter)
- **Version code:** Build number after `+` (e.g., `+42`)
- **CRITICAL:** Build number must ALWAYS increment, never decrease (Android security requirement)
- Decreasing version codes cause "package corrupted" errors requiring uninstall/data loss

## Architecture

### Services (Singleton Pattern)
- `DatabaseService` - ObjectBox: parcels, logs, log_batches, locations
- `CadastralService` - WMS queries to prostor.zgs.gov.si (30s timeout)
- `HttpCacheService` / `TileCacheService` - 1-year cache for govt APIs, ObjectBox tile cache
- `MapPreferencesService` - Layer prefs (defaults: Ortofoto + Kataster + Kataster z nazivi)
- `SpeciesService` - Tree species (SharedPreferences, defaults: Smreka, Bukev, Jelka)
- `OnboardingService` - First-run wizard (SharedPreferences)
- `ExportService` - Excel (.xlsx) export
- `AnalyticsService` - Firebase wrapper (auto-disabled in `kDebugMode`)

### Data Models (ObjectBox)
- **Parcel** - Forest polygon: name, polygonJson, cadastralMunicipality, parcelNumber, owner, notes, forestTypeIndex, woodAllowance/Cut, treesCut, createdAt | Relations: ToMany<LogEntry>
- **LogEntry** - Wood log (V = π × (d/200)² × L): diameter, length, volume, lat/lng, notes, species, createdAt | Relations: ToOne<LogBatch>, ToOne<Parcel> | **NOTE:** batchId/parcelId are @Transient()
- **LogBatch** - Batch summary: name, totalVolume, logCount, prmFactor, nmFactor, createdAt
- **Location** - GPS point: name, lat/lng, createdAt
- **MapLayer** - WMS/tile config (40+ Slovenian layers)

## User Interface

### Navigation
- **3 tabs:** Karta (Map), Gozd (Forest), Hlodi (Logs) | Default: Gozd (index 1)
- **Easter egg:** 5-tap any tab to reset onboarding wizard
- **First run:** 9-page `IntroWizardScreen` (welcome, navigation, log tracking, long-press menu, map markers, layers, offline mode, compass, terms)

### Hlodi (Logs) Tab
**Volume conversions:**
- **PRM** (prostorninski meter) = m³ × 0.65 (stacked firewood)
- **NM** (nasuti meter) = m³ × 0.40 (loose chips)
- Factors configurable via settings

**Species tracking:**
- Assign species per log (Smreka, Bukev, Jelka, custom)
- Auto-group when 2+ species exist
- Headers show "3 hlodov • 1.25 m³" per species
- Manage via ⋮ menu → "Upravljanje vrst"

## GIS & Mapping

### Slovenian CRS (EPSG:3794) - CRITICAL
**Required for all prostor.zgs.gov.si WMS layers** (defined in `lib/utils/slovenian_crs.dart`):
- Transverse Mercator projection at 15° longitude, 16 zoom levels
- **Store coordinates as WGS84 (LatLng), convert to EPSG:3794 only for WMS requests** (proj4dart)
- **Marker visibility:** Slovenian layers zoom ≥ 11, Web Mercator zoom ≥ 15

### Map Layers (`lib/models/map_layer.dart`)
- **Base layers:** OSM, TopoMap, ESRI, Google, Ortofoto, DTK25
- **Overlays:** WMS from `prostor.zgs.gov.si/geoserver/wms`
- **Visibility rule:** Slovenian overlays only show when base layer `isSlovenian == true`

## Localization

UI uses Slovenian: Karta, Gozd, Hlodi, Parcela, Posek, etc.
