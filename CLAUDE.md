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
- `AnalyticsService` - Aptabase analytics (privacy-first, key: A-EU-0504687602)

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

<!-- rtk-instructions v2 -->
# RTK (Rust Token Killer) - Token-Optimized Commands

## Golden Rule

**Always prefix commands with `rtk`**. If RTK has a dedicated filter, it uses it. If not, it passes through unchanged. This means RTK is always safe to use.

**Important**: Even in command chains with `&&`, use `rtk`:
```bash
# ❌ Wrong
git add . && git commit -m "msg" && git push

# ✅ Correct
rtk git add . && rtk git commit -m "msg" && rtk git push
```

## RTK Commands by Workflow

### Build & Compile (80-90% savings)
```bash
rtk cargo build         # Cargo build output
rtk cargo check         # Cargo check output
rtk cargo clippy        # Clippy warnings grouped by file (80%)
rtk tsc                 # TypeScript errors grouped by file/code (83%)
rtk lint                # ESLint/Biome violations grouped (84%)
rtk prettier --check    # Files needing format only (70%)
rtk next build          # Next.js build with route metrics (87%)
```

### Test (60-99% savings)
```bash
rtk cargo test          # Cargo test failures only (90%)
rtk go test             # Go test failures only (90%)
rtk jest                # Jest failures only (99.5%)
rtk vitest              # Vitest failures only (99.5%)
rtk playwright test     # Playwright failures only (94%)
rtk pytest              # Python test failures only (90%)
rtk rake test           # Ruby test failures only (90%)
rtk rspec               # RSpec test failures only (60%)
rtk test <cmd>          # Generic test wrapper - failures only
```

### Git (59-80% savings)
```bash
rtk git status          # Compact status
rtk git log             # Compact log (works with all git flags)
rtk git diff            # Compact diff (80%)
rtk git show            # Compact show (80%)
rtk git add             # Ultra-compact confirmations (59%)
rtk git commit          # Ultra-compact confirmations (59%)
rtk git push            # Ultra-compact confirmations
rtk git pull            # Ultra-compact confirmations
rtk git branch          # Compact branch list
rtk git fetch           # Compact fetch
rtk git stash           # Compact stash
rtk git worktree        # Compact worktree
```

Note: Git passthrough works for ALL subcommands, even those not explicitly listed.

### GitHub (26-87% savings)
```bash
rtk gh pr view <num>    # Compact PR view (87%)
rtk gh pr checks        # Compact PR checks (79%)
rtk gh run list         # Compact workflow runs (82%)
rtk gh issue list       # Compact issue list (80%)
rtk gh api              # Compact API responses (26%)
```

### JavaScript/TypeScript Tooling (70-90% savings)
```bash
rtk pnpm list           # Compact dependency tree (70%)
rtk pnpm outdated       # Compact outdated packages (80%)
rtk pnpm install        # Compact install output (90%)
rtk npm run <script>    # Compact npm script output
rtk npx <cmd>           # Compact npx command output
rtk prisma              # Prisma without ASCII art (88%)
```

### Files & Search (60-75% savings)
```bash
rtk ls <path>           # Tree format, compact (65%)
rtk read <file>         # Code reading with filtering (60%)
rtk grep <pattern>      # Search grouped by file (75%)
rtk find <pattern>      # Find grouped by directory (70%)
```

### Analysis & Debug (70-90% savings)
```bash
rtk err <cmd>           # Filter errors only from any command
rtk log <file>          # Deduplicated logs with counts
rtk json <file>         # JSON structure without values
rtk deps                # Dependency overview
rtk env                 # Environment variables compact
rtk summary <cmd>       # Smart summary of command output
rtk diff                # Ultra-compact diffs
```

### Infrastructure (85% savings)
```bash
rtk docker ps           # Compact container list
rtk docker images       # Compact image list
rtk docker logs <c>     # Deduplicated logs
rtk kubectl get         # Compact resource list
rtk kubectl logs        # Deduplicated pod logs
```

### Network (65-70% savings)
```bash
rtk curl <url>          # Compact HTTP responses (70%)
rtk wget <url>          # Compact download output (65%)
```

### Meta Commands
```bash
rtk gain                # View token savings statistics
rtk gain --history      # View command history with savings
rtk discover            # Analyze Claude Code sessions for missed RTK usage
rtk proxy <cmd>         # Run command without filtering (for debugging)
rtk init                # Add RTK instructions to CLAUDE.md
rtk init --global       # Add RTK to ~/.claude/CLAUDE.md
```

## Token Savings Overview

| Category | Commands | Typical Savings |
|----------|----------|-----------------|
| Tests | vitest, playwright, cargo test | 90-99% |
| Build | next, tsc, lint, prettier | 70-87% |
| Git | status, log, diff, add, commit | 59-80% |
| GitHub | gh pr, gh run, gh issue | 26-87% |
| Package Managers | pnpm, npm, npx | 70-90% |
| Files | ls, read, grep, find | 60-75% |
| Infrastructure | docker, kubectl | 85% |
| Network | curl, wget | 65-70% |

Overall average: **60-90% token reduction** on common development operations.
<!-- /rtk-instructions -->