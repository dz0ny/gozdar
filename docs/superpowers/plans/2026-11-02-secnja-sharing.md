# Sečnja Marking and Sharing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Owners mark trees for felling in a fast marking mode and share a parcel's marks with a logger through a 30-day link that opens in Gozdar and shows up as a toggleable layer.

**Architecture:** Marks stay `MapLocation` rows (type `secnja`) and gain a `parcelId`. A new `SecnjaSharePayload` model builds the JSON a share carries; `SecnjaShareService` talks to new share endpoints on the existing Cloudflare Worker, which stores shares in KV with a 30-day TTL. Received shares live in a new drift table and are drawn by `MapTab` from `MapProvider`. `https://gozdar.dz0ny.dev/s/:id` is an App Link / Universal Link routed by go_router.

**Tech Stack:** Flutter, drift, go_router, provider, `http` (+ `package:http/testing.dart` in tests), `share_plus`, `crypto`; Cloudflare Worker with Hono and KV, tested with `node --test`.

**Spec:** `docs/superpowers/specs/2026-11-02-secnja-sharing-design.md`

## Global Constraints

- Share links: `https://gozdar.dz0ny.dev/s/<id>`; API on the same host: `/api/s`, `/api/s/:id`.
- Share lifetime: 30 days (`30 * 24 * 3600` s) from the last create/update.
- Share id: 6 chars of `[A-Za-z0-9]`. Edit token: 32 random bytes, base64url.
- Payload limit 256 KB (`262144` bytes) → 413.
- Payload `v: 1`; coordinates WGS84, polygon as `[[lat, lng], ...]`.
- drift `schemaVersion` goes 4 → 5.
- Android package and iOS bundle `dev.dz0ny.gozdar`; Apple team `JND55328G8`.
- Colours: own sečnja `Colors.deepOrange`; received shares `Colors.blue`.
- Every user-facing string goes into both `lib/l10n/app_sl.arb` and `lib/l10n/app_hr.arb` (with `@` metadata for placeholders in `app_sl.arb`), then `flutter gen-l10n`.
- Long-press keeps one meaning (open the menu). No new gesture.
- The Hlodi sheet is not touched.
- Use `flutter analyze`, not builds, for code checks. Prefix shell commands with `rtk`.

## Review Focus

1. **Link tapped while Gozdar is already open** (warm start) — must import exactly like a cold start, not be dropped by the shell route. Test in Task 8.
2. **Owner deletes every mark on a shared parcel** — the Sečnja card must stay visible while a share exists so **Prekliči** is reachable. Test in Task 7.
3. **Logger opens the same link twice, or after the owner updated it** — one layer, replaced payload, never a duplicate. Tests in Task 2 and Task 4.
4. **Received share past `expiresAt` while the logger is offline** — disappears anyway; expiry is local, not only server-driven. Test in Task 2.
5. **Species names with č/š/ž and reordered map keys** — the change hash must be stable for identical content, so the card doesn't claim "changed" after a reload. Test in Task 3.

---

### Task 1: Worker share endpoints

**Files:**
- Create: `worker/src/shares.js`
- Create: `worker/test/shares.test.js`
- Modify: `worker/src/index.js` (mount routes, extend CORS methods)
- Modify: `worker/wrangler.toml` (KV binding, custom domain)
- Modify: `worker/package.json` (`"test": "node --test test/"`)

**Interfaces:**
- Produces (HTTP):
  - `POST /api/s` body payload → `201 {id, editToken, expiresAt}`
  - `PUT /api/s/:id` `Authorization: Bearer <token>` → `200 {expiresAt}`; 403 wrong token; 404 missing
  - `DELETE /api/s/:id` same auth → 204
  - `GET /api/s/:id` → `200 {...payload, expiresAt}` (no `editToken`), `Cache-Control: no-store`; 404
  - `GET /s/:id` → HTML install page (always 200)
  - `GET /.well-known/assetlinks.json`, `GET /.well-known/apple-app-site-association` → JSON
  - Bad JSON or missing `parcel`/`points` → 400; body > 262144 bytes → 413
- Produces (JS): `export const shares` — a Hono app mounted with `app.route('/', shares)`; KV accessed as `c.env.SHARES`.

- [ ] **Step 1: Write the failing tests** in `worker/test/shares.test.js` using `node:test` + `node:assert/strict`, calling `shares.request(path, init, env)` with `env = { SHARES: fakeKv() }`, where `fakeKv()` is a `Map`-backed object with `get(key, 'json')`, `put(key, value, {expirationTtl})` (records the ttl), `delete(key)`. Tests:
  - `create returns id, token and expiry` — POST valid payload → 201; `id` matches `/^[A-Za-z0-9]{6}$/`; `editToken` length 43; `expiresAt` ≈ now + 30 days (±60 s); recorded `expirationTtl === 2592000`.
  - `get hides the edit token` — after create, GET `/api/s/<id>` → 200, body has `parcel` and `expiresAt`, no `editToken`; header `cache-control` is `no-store`.
  - `update with right token replaces payload and restarts ttl` — PUT with new `points` → 200; GET shows new points.
  - `update with wrong token is 403` and `update of missing id is 404`.
  - `delete then get is 404`.
  - `rejects payload without points` → 400; `rejects body over 256 KB` → 413.
  - `install page does not leak share data` — GET `/s/<id>` → 200 `text/html`, body does not contain the parcel number from the payload, contains `Gozdar`.
  - `assetlinks lists the package` — body `[0].target.package_name === 'dev.dz0ny.gozdar'`.
  - `aasa lists the app id and path` — `applinks.details[0].appIDs` includes `JND55328G8.dev.dz0ny.gozdar`, `components[0]['/'] === '/s/*'`.

- [ ] **Step 2: Run to see them fail**

Run: `cd worker && rtk npm test`
Expected: FAIL, `Cannot find module '../src/shares.js'`.

- [ ] **Step 3: Implement `worker/src/shares.js`**

Constants at the top: `TTL_SECONDS = 2592000`, `MAX_BYTES = 262144`, `IOS_URL` (App Store/TestFlight URL from the release workflow's app; leave a `TODO(owner)` string if not findable in the repo), `ANDROID_URL = 'https://github.com/dz0ny/gozdar/releases/latest'`, `ANDROID_SHA256 = [<release>, <debug>]` (get them with `keytool -list -v -keystore ~/android-keystores/gozdar-release-key.jks -alias gozdar-release` and `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`). Stored KV value: `{payload, editToken, expiresAt}`. Token comparison in constant time over equal-length strings. Ids via `crypto.getRandomValues`, retry up to 5 times on collision. Install page copy (Slovenian): `Za ogled sečnje potrebuješ aplikacijo Gozdar.`, buttons `iPhone` / `Android`, footer `Po namestitvi znova odpri povezavo.`

- [ ] **Step 4: Mount in `index.js`** — `app.route('/', shares)` before `notFound`; CORS `allowMethods: ['GET', 'HEAD', 'OPTIONS', 'POST', 'PUT', 'DELETE']`, `allowHeaders: ['Content-Type', 'Authorization']`.

- [ ] **Step 5: Bind KV and domain in `wrangler.toml`**

```toml
routes = [{ pattern = "gozdar.dz0ny.dev", custom_domain = true }]

[[kv_namespaces]]
binding = "SHARES"
id = "<from: rtk npx wrangler kv namespace create SHARES>"
```

Creating the namespace is outward-facing; if the executor lacks Cloudflare credentials, leave `id = "REPLACE_ME"` and list it in Task 10.

- [ ] **Step 6: Run tests** — `cd worker && rtk npm test` → all pass.

- [ ] **Step 7: Commit** — `feat(worker): Share endpoints for sečnja links`

---

### Task 2: Schema 5 — parcel links, share state, received shares

**Files:**
- Modify: `lib/db/app_database.dart` (columns, table, migration), regenerate `app_database.g.dart`
- Modify: `lib/models/map_location.dart`, `lib/models/parcel.dart`
- Create: `lib/models/received_share.dart`
- Modify: `lib/services/database_service.dart`
- Test: `test/services/secnja_db_test.dart`

**Interfaces:**
- Produces:
  - `MapLocation.parcelId` (`int?`), carried through `copyWith`, `toMap`/`fromMap`, mappers.
  - `Parcel.shareId`, `shareEditToken`, `shareHash` (`String?`), `sharedAt`, `shareExpiresAt` (`DateTime?`); `bool get isShared => shareId != null`; carried through `copyWith` and mappers.
  - `class ReceivedShare { int id; String shareId; String payloadJson; DateTime fetchedAt; DateTime expiresAt; bool visible; SecnjaSharePayload get payload; int get daysLeft; }` (`payload` getter decodes with Task 3's `SecnjaSharePayload.fromJson`; write it in Task 3 if ordering demands).
  - `DatabaseService`:
    - `insertLocation` — for a `secnja` location with `parcelId == null`, sets it via `parcelIdAt(LatLng)` before inserting (covers marking mode and KML import).
    - `Future<int?> parcelIdAt(LatLng point)` — saved parcel containing the point; smallest `areaM2` wins on overlap.
    - `Future<List<MapLocation>> getSecnjaByParcel(int parcelId)` — ordered by `createdAt` ascending.
    - `Future<Map<int, int>> getSecnjaCountsByParcel()`.
    - `Future<int> countSecnjaWithoutParcel()`.
    - `Future<void> saveParcelShare(int parcelId, {required String shareId, required String editToken, required String hash, required DateTime sharedAt, required DateTime expiresAt})` and `Future<void> clearParcelShare(int parcelId)`.
    - `Future<void> upsertReceivedShare(ReceivedShare s)` (by `shareId`; keeps `visible`), `Future<List<ReceivedShare>> getReceivedShares()` (only `expiresAt > now`), `Future<int> purgeExpiredReceivedShares()`, `Future<void> setReceivedShareVisible(String shareId, bool visible)`, `Future<void> deleteReceivedShare(String shareId)`.
    - `deleteParcelWithContents` also deletes locations whose `parcelId == id` (in addition to today's point-in-polygon rule); the returned counts stay the same shape.
  - `AppDatabase.backfillSecnjaParcels()` — sets `parcel_id` on sečnja rows with null `parcel_id`, smallest containing parcel wins. Called from `onUpgrade` when `from < 5`.

- [ ] **Step 1: Write the failing tests** (pattern: `test/services/log_batch_deletion_test.dart`, in-memory `NativeDatabase.memory()`):
  - `insertLocation assigns the containing parcel to a sečnja mark`
  - `overlapping parcels: smallest wins`
  - `plain points do not get a parcelId`
  - `getSecnjaCountsByParcel counts per parcel`
  - `backfillSecnjaParcels links existing marks` — insert rows directly through `db.into(db.mapLocations)` with null `parcelId`, call `db.backfillSecnjaParcels()`, assert ids.
  - `deleteParcelWithContents removes marks linked by parcelId even outside the polygon`
  - `saveParcelShare / clearParcelShare round trip`
  - `upsertReceivedShare twice keeps one row, latest payload, visibility kept`
  - `getReceivedShares hides expired shares without network` and `purgeExpiredReceivedShares deletes them`

- [ ] **Step 2: Run to see them fail** — `rtk flutter test test/services/secnja_db_test.dart` → compile errors on missing members.

- [ ] **Step 3: Schema** — `MapLocations.parcelId => integer().nullable().references(Parcels, #id)()`; the five `Parcels` columns as nullable; `@DataClassName('DbReceivedShare') class ReceivedShares` with `shareId => text().unique()()`, `payloadJson`, `fetchedAt`, `expiresAt`, `visible => boolean().withDefault(const Constant(true))()`. Register the table; `schemaVersion => 5`; in `onUpgrade` `if (from < 5)` add the six columns, create the table, call `backfillSecnjaParcels()`. Backfill decodes `polygon_json` in Dart (reuse `Parcel.containsPoint`/`areaM2` by building `Parcel` objects), not SQL.

- [ ] **Step 4: Regenerate** — `rtk dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 5: Models, mappers and `DatabaseService` methods** as listed in Interfaces.

- [ ] **Step 6: Run tests** — the new file and `rtk flutter test test/services/` pass.

- [ ] **Step 7: Commit** — `feat: Link sečnja marks to parcels and store shares (schema 5)`

---

### Task 3: Share payload, change hash, share message

**Files:**
- Create: `lib/models/secnja_share.dart`
- Modify: `lib/l10n/app_sl.arb`, `lib/l10n/app_hr.arb`
- Test: `test/models/secnja_share_test.dart`

**Interfaces:**
- Consumes: `Parcel`, `MapLocation` (Task 2).
- Produces:
  - `class SecnjaPoint { String name; double lat; double lng; String? species; }`
  - `class SecnjaSharePayload { String parcelNumber; int? koNumber; String? koName; String? owner; double? areaHa; List<LatLng> polygon; List<SecnjaPoint> points; DateTime createdAt; DateTime? expiresAt; }`
  - `factory SecnjaSharePayload.fromParcel(Parcel p, List<MapLocation> marks, {String? koName, DateTime? now})` — `parcelNumber` falls back to `p.name` when `p.parcelNumber` is null; `owner` null when blank; `areaHa` null when `areaM2 == 0`; species = the leading word of the mark name when it matches a species from `SpeciesService` (pass the list in as `List<String> species` parameter to keep it pure).
  - `Map<String, dynamic> toJson()` / `factory SecnjaSharePayload.fromJson(Map<String, dynamic>)` — schema exactly as in the spec's "Payload" section, `"v": 1`; omit null optionals.
  - `String get contentHash` — SHA-256 hex (`package:crypto`) of `jsonEncode` of `toJson()` **without** `createdAt` and `expiresAt`, keys sorted recursively.
  - `String shareMessage(SecnjaSharePayload p, Uri link, AppLocalizations l10n)` — top-level function producing the spec's five-line message; `Lastnik:` line only when `owner != null`; area part only when `areaHa != null`; `k.o. <koName>` or `k.o. <koNumber>`; date as `d. M. yyyy`.
- l10n keys (sl / hr):
  - `secnjaShareHeadline` `🪓 Sečnja — parcela {parcel}, k.o. {ko}` / `🪓 Sječa — čestica {parcel}, k.o. {ko}`
  - `secnjaShareCount` plural `{count} dreves za posek` (use plural forms as `forestCountTrees`) / `{count} stabala za sječu`
  - `secnjaShareOwner` `Lastnik: {owner}` / `Vlasnik: {owner}`
  - `secnjaShareValidUntil` `Povezava velja do {date}` / `Poveznica vrijedi do {date}`

- [ ] **Step 1: Write the failing tests:**
  - `toJson matches the spec schema` — parcel `1234/5`, ko 1234 `Dolenja vas`, owner `Janez Novak`, two marks (`Smreka 1` with species list `['Smreka']`, `Drevo 2`) → `json['v'] == 1`, `json['points'][0]['species'] == 'Smreka'`, `json['points'][1]` has no `species` key, polygon is list of 2-element lists.
  - `fromJson(toJson(x))` round-trips.
  - `blank owner and zero area are omitted`.
  - `contentHash ignores createdAt` — same content, different `now` → equal hashes.
  - `contentHash is stable for č/š/ž names and reordered keys` — build via `fromJson` from two maps with keys in different order and name `Bukev čšž 3` → equal.
  - `contentHash changes when a mark is renamed or removed`.
  - `shareMessage without owner has four lines`; `with koName null uses the k.o. number`.

- [ ] **Step 2: Run to see them fail** — `rtk flutter test test/models/secnja_share_test.dart`.
- [ ] **Step 3: Add the l10n keys, run `rtk flutter gen-l10n`, implement `lib/models/secnja_share.dart`.**
- [ ] **Step 4: Run tests** → pass.
- [ ] **Step 5: Commit** — `feat: Sečnja share payload and message`

---

### Task 4: `SecnjaShareService`

**Files:**
- Create: `lib/services/secnja_share_service.dart`
- Test: `test/services/secnja_share_service_test.dart`

**Interfaces:**
- Consumes: `DatabaseService` (Task 2), `SecnjaSharePayload` (Task 3).
- Produces:
  - `class SecnjaShareService { SecnjaShareService({http.Client? client, DatabaseService? db, Uri? base}); static final instance; }` — `base` defaults to `https://gozdar.dz0ny.dev`.
  - `Uri linkFor(String shareId)` → `<base>/s/<id>`.
  - `Future<ShareResult> share(Parcel parcel, SecnjaSharePayload payload)` — POST when `!parcel.isShared`, else PUT with the stored token; if PUT returns 404/403 (expired or revoked elsewhere), fall back to POST. On success calls `saveParcelShare` with `payload.contentHash`. `class ShareResult { Uri link; DateTime expiresAt; }`. Throws `ShareException` on network error or non-2xx.
  - `Future<void> revoke(Parcel parcel)` — DELETE (404 counts as success), then `clearParcelShare`.
  - `Future<ReceiveOutcome> receive(String shareId)` — GET; `ReceiveOutcome` is an enum `{ imported, expired, offline }`; `imported` upserts the `ReceivedShare`; `expired` (404/410) deletes any local row; `offline` stores nothing.
  - `Future<void> refreshReceived()` — `purgeExpiredReceivedShares()` first (works offline), then `receive` each remaining id, swallowing `offline`.
  - Request timeout 15 s.

- [ ] **Step 1: Write the failing tests** with `MockClient` from `package:http/testing.dart` and an in-memory DB:
  - `first share POSTs and stores id, token, hash`
  - `second share PUTs with Bearer token to the same id`
  - `PUT 404 falls back to POST and stores the new id`
  - `revoke DELETEs and clears local state; 404 is fine`
  - `receive imports; receiving again replaces payload, one row`
  - `receive 404 deletes the local row and returns expired`
  - `receive on SocketException returns offline and stores nothing`
  - `refreshReceived purges expired rows even when every request fails`

- [ ] **Step 2: Run to see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run tests** → pass.
- [ ] **Step 5: Commit** — `feat: Service for sharing and receiving sečnja`

---

### Task 5: Marking mode

**Files:**
- Create: `lib/widgets/secnja_marking_panel.dart`
- Create: `lib/services/secnja_marking_prefs.dart`
- Modify: `lib/screens/map_tab.dart` (replace `_showAddSecnjaDialog` / `_addSecnja` with marking mode; `onAddSecnja` enters it)
- Modify: `lib/widgets/map_dialogs.dart` (remove `showAddSecnjaDialog`)
- Modify: arb files
- Test: `test/widgets/secnja_marking_panel_test.dart`, `test/services/secnja_marking_prefs_test.dart`

**Interfaces:**
- Consumes: `DatabaseService.parcelIdAt`, `getSecnjaByParcel`, `countSecnjaWithoutParcel`, `insertLocation`, `deleteLocation` (Task 2); `SpeciesService.getSpecies()`.
- Produces:
  - `String nextSecnjaName({String? species, required int existing, required AppLocalizations l10n})` → `'<species> <existing+1>'` or `secnjaDefaultName(existing+1)`.
  - `class SecnjaMarkingPrefs { Future<String?> getSpecies(); Future<void> setSpecies(String? s); }` — SharedPreferences key `secnja_marking_species`.
  - `class SecnjaMarkingPanel extends StatelessWidget` with `required String title` (`🪓 Sečnja · <parcel>` or `secnjaOutsideParcel`), `required int count`, `required List<String> species`, `String? selectedSpecies`, `required ValueChanged<String?> onSpeciesSelected` (tap selected chip again → null), `required VoidCallback onAddSpecies`, `VoidCallback? onUndo` (null disables), `required VoidCallback onMark`, `required VoidCallback onFinish`. Built from `SheetTileRow`/`SheetTile`; `Označi` is the primary tile in `Colors.deepOrange`.
  - In `map_tab.dart`: state `_secnjaMarking` (bool), `_secnjaSessionIds` (`List<int>`), the crosshair reused from measurement (`_MeasurementCrosshair(color: Colors.deepOrange)`). On map move end while marking, recompute header parcel and count. `Označi`: `HapticFeedback.mediumImpact()`, insert at `_mapController.camera.center`, push id. `Razveljavi`: delete last session id. `Končaj`: leave mode; if any session mark has a `parcelId`, show a snackbar with action `secnjaShareAction` that opens the share flow from Task 7 for that parcel (the last one marked). Hide bottom controls while marking like measurement does; GPS button stays reachable (pass `hideBottomControls` only for the locations FAB, or move GPS above the panel — executor's call, but GPS must be usable).
  - `+` chip: `showModalBottomSheet(builder: (_) => const SpeciesManagementSheet())`, then reload species.
- l10n keys (sl / hr): `secnjaOutsideParcel` `Izven parcele` / `Izvan čestice`; `secnjaDefaultName` `Drevo {n}` / `Stablo {n}`; `secnjaMarkAction` `Označi` / `Označi`; `secnjaFinish` `Končaj` / `Završi`; `secnjaMarkedCount` plural like `forestCountTrees`; `secnjaShareAction` `Deli sekaču` / `Podijeli sjekaču`. Reuse `mapTabUndo`. Remove now-unused `mapwMarkFellingTitle`, `mapwTreeDescLabel`, `mapwTreeDescHint`, `mapwEnterDescription`, `mapwMarkAction`, `mapTabSecnjaMarked`, `mapTabSecnjaMarkError` if nothing else uses them.

- [ ] **Step 1: Write the failing tests:**
  - `nextSecnjaName uses species and count` (`'Smreka', 2` → `Smreka 3`; null → `Drevo 3`).
  - `SecnjaMarkingPrefs remembers species and clears with null` (`SharedPreferences.setMockInitialValues({})`).
  - Panel widget: `tapping Označi calls onMark`; `undo disabled when onUndo is null`; `tapping the selected chip deselects`; `header shows count`.
- [ ] **Step 2: Run to see them fail.**
- [ ] **Step 3: Implement panel, prefs, helper, l10n; wire into `map_tab.dart`.**
- [ ] **Step 4: Run** `rtk flutter test test/widgets/secnja_marking_panel_test.dart test/services/secnja_marking_prefs_test.dart test/widgets/map_long_press_menu_test.dart` and `rtk flutter analyze` → clean.
- [ ] **Step 5: Commit** — `feat: Marking mode for sečnja`

---

### Task 6: Simpler “Točka” sheet

**Files:**
- Modify: `lib/widgets/map_dialogs.dart` (`showAddLocationDialog`, `_showNameSheet` becomes `_showPointSheet` or is reshaped — only Točka uses it now)
- Modify: `lib/screens/map_tab.dart` (pass default index and parcel label)
- Modify: arb files
- Test: `test/widgets/add_point_sheet_test.dart`

**Interfaces:**
- Produces: `MapDialogs.showAddLocationDialog({required BuildContext context, required LatLng position, required int nextNumber, String? parcelLabel, VoidCallback? onBack})` → same record type as today.
- Behaviour per spec "Simpler sheets": no autofocus; chips `pointDefaultName(nextNumber)` (pre-selected), `pointChipBoundary`, `pointChipHide`, `pointChipSpring`, `pointChipSkidTrail`; tapping a chip selects it and clears the field; typing deselects chips; empty field + no chip selected → default name; subtitle `parcelLabel · coords` or coords; no error text ever.
- l10n keys (sl / hr): `pointDefaultName` `Točka {n}` / `Točka {n}`; `pointChipBoundary` `Mejnik` / `Međaš`; `pointChipHide` `Lovska preža` / `Lovačka čeka`; `pointChipSpring` `Izvir` / `Izvor`; `pointChipSkidTrail` `Vlaka` / `Vlaka`; `pointOwnNameLabel` `Svoje ime (neobvezno)` / `Vlastiti naziv (neobavezno)`; `pointSave` reuse `commonSave` if it exists. Remove `mapwEnterName` if unused.

- [ ] **Step 1: Write the failing tests:** `save without typing returns Točka 7`; `tapping Izvir returns Izvir`; `typed text wins over chips`; `keyboard does not open` (no `TextField` has focus after pump); `no error text after save with empty field`.
- [ ] **Step 2: Run to see them fail.**
- [ ] **Step 3: Implement; in `map_tab.dart` compute `nextNumber` = existing non-sečnja points + 1, `parcelLabel` from the saved parcel at the point.**
- [ ] **Step 4: Run tests and `rtk flutter analyze`.**
- [ ] **Step 5: Commit** — `feat: Simpler add-point sheet`

---

### Task 7: Moj gozd count and the Sečnja card share flow

**Files:**
- Modify: `lib/screens/forest_tab.dart` (load counts, row text)
- Modify: `lib/screens/parcel_detail_screen.dart` (read marks by `parcelId`, share/revoke actions, show card when shared)
- Modify: `lib/widgets/parcel_data_cards.dart` (`ParcelSecnjaCard`)
- Create: `lib/services/secnja_share_flow.dart` (UI glue used by detail screen and Task 5's snackbar)
- Modify: arb files
- Test: `test/widgets/parcel_secnja_card_test.dart`

**Interfaces:**
- Consumes: Tasks 2–4.
- Produces:
  - `enum SecnjaShareState { notShared, sharedUnchanged, sharedChanged }` and `SecnjaShareState secnjaShareState(Parcel p, String currentHash)`.
  - `ParcelSecnjaCard({required List<MapLocation> secnja, required onNavigateToPoint, required SecnjaShareState shareState, DateTime? expiresAt, required VoidCallback onShare, required VoidCallback onRevoke, bool busy = false})`. Button label by state: `secnjaShareAction` / `secnjaShareAgain` / `secnjaShareUpdate`; when shared, line `secnjaSharedUntil(date)` and text button `secnjaRevoke`. Card renders when `secnja.isNotEmpty || shareState != notShared`; with zero marks the share button is hidden but Prekliči shows.
  - `Future<void> runSecnjaShare(BuildContext context, Parcel parcel)` in `secnja_share_flow.dart`: load marks, resolve k.o. name (`OwnerLookupService.instance.koName(ko) ?? KoLocator.instance.bySifko(ko)?.name`), build payload, if state is `sharedUnchanged` skip upload, else `SecnjaShareService.instance.share`; then `SharePlus.instance.share(ShareParams(text: shareMessage(...)))` (match how `kml_service.dart` calls share_plus in this repo). On `ShareException` → snackbar `secnjaShareFailed`.
  - `Future<void> runSecnjaRevoke(BuildContext context, Parcel parcel)` — confirm dialog `secnjaRevokeConfirm`, then `revoke`.
  - Forest row: `· 🪓 ${secnjaForCutCount(n)}` in `Colors.deepOrange`, placed after the area and before today's cut-trees/m³ items.
- l10n keys (sl / hr): `secnjaShareAgain` `Deli znova` / `Podijeli ponovno`; `secnjaShareUpdate` `Posodobi povezavo` / `Ažuriraj poveznicu`; `secnjaSharedUntil` `Deljeno · velja do {date}` / `Podijeljeno · vrijedi do {date}`; `secnjaRevoke` `Prekliči` / `Opozovi`; `secnjaRevokeConfirm` `Preklic povezave? Sekač je ne bo mogel več odpreti.` / `Opozvati poveznicu? Sjekač je više neće moći otvoriti.`; `secnjaShareFailed` `Deljenje ni uspelo — preveri povezavo` / `Dijeljenje nije uspjelo — provjeri vezu`; `secnjaForCutCount` plural `{count} za posek` / `{count} za sječu`.

- [ ] **Step 1: Write the failing tests:**
  - `secnjaShareState` — not shared; same hash → unchanged; different hash → changed.
  - Card: `not shared shows Deli sekaču`; `shared unchanged shows Deli znova and the expiry line`; `changed shows Posodobi povezavo`; `shared with zero marks still renders with Prekliči and no share button` (Review Focus 2); `tapping Prekliči calls onRevoke`.
- [ ] **Step 2: Run to see them fail.**
- [ ] **Step 3: Implement card, flow, forest row, detail screen wiring (replace the point-in-polygon filter for sečnja with `getSecnjaByParcel`; plain points keep the polygon filter). Hook Task 5's snackbar action to `runSecnjaShare`.**
- [ ] **Step 4: Run tests and `rtk flutter analyze`.**
- [ ] **Step 5: Commit** — `feat: Share sečnja from parcel detail; counts in Moj gozd`

---

### Task 8: Deep link `/s/:id`

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Create: `ios/Runner/Runner.entitlements`
- Modify: `ios/Runner/Info.plist`, `ios/Runner.xcodeproj/project.pbxproj` (`CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;` in the Runner target's Debug, Release and Profile configs)
- Modify: `lib/router/route_names.dart`, `lib/router/app_router.dart`
- Create: `lib/screens/receive_share_screen.dart`
- Modify: arb files
- Test: `test/router/receive_share_route_test.dart`

**Interfaces:**
- Consumes: `SecnjaShareService.receive` (Task 4).
- Produces:
  - `AppRoutes.share(String id) => '/s/$id'`.
  - `ReceiveShareScreen({required String shareId, SecnjaShareService? service})` — shows a spinner, calls `receive`, then `context.go(AppRoutes.map)` and shows a snackbar: `secnjaReceived(parcel, count)` / `secnjaLinkExpired` / `secnjaNoConnection`. After `imported`, tells `MapProvider.loadReceivedShares()` (Task 9) and asks the map to fit the parcel polygon — via a `MapProvider.focusBounds` field `MapTab` listens to (executor's call on mechanism; it must work when the map tab was already built).
  - Android, inside `.MainActivity`:
    ```xml
    <meta-data android:name="flutter_deeplinking_enabled" android:value="true" />
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="https" android:host="gozdar.dz0ny.dev" android:pathPrefix="/s/" />
    </intent-filter>
    ```
  - iOS entitlements: `com.apple.developer.associated-domains` = `[applinks:gozdar.dz0ny.dev]`; Info.plist `FlutterDeepLinkingEnabled` = `true`.
  - The route sits at root level (`parentNavigatorKey: rootNavigatorKey`), outside the shell, so onboarding redirect logic must not swallow it: if onboarding is pending, the share is still received first, then onboarding shows.
- l10n keys (sl / hr): `secnjaReceived` `Prejeta sečnja: parcela {parcel} · {count} dreves` / `Primljena sječa: čestica {parcel} · {count} stabala` (use plural for count); `secnjaLinkExpired` `Povezava je potekla ali bila preklicana` / `Poveznica je istekla ili je opozvana`; `secnjaNoConnection` `Ni povezave — poskusi znova` / `Nema veze — pokušaj ponovno`.

- [ ] **Step 1: Write the failing tests** with a `GoRouter` built by `createRouter(showOnboarding: false, initialLocation: '/s/abc123')` and a fake `SecnjaShareService` subclass returning a fixed outcome:
  - `cold start on /s/:id calls receive with the id and lands on the map`
  - `warm start: router.go('/s/xyz') from the forest tab calls receive` (Review Focus 1)
  - `expired outcome shows the expired snackbar`
  (Inject the fake via a static override on `SecnjaShareService.instance` marked `@visibleForTesting`.)
- [ ] **Step 2: Run to see them fail.**
- [ ] **Step 3: Implement route, screen, platform files.**
- [ ] **Step 4: Run tests and `rtk flutter analyze`.**
- [ ] **Step 5: Commit** — `feat: Open sečnja share links in the app`

---

### Task 9: Received shares on the map

**Files:**
- Modify: `lib/providers/map_provider.dart`
- Modify: `lib/widgets/map_marker_renderer.dart`
- Modify: `lib/screens/map_tab.dart` (polygon layer + markers + pass to selector and saved sheet)
- Modify: `lib/widgets/map_layer_selector.dart` (PREJETO section)
- Modify: `lib/widgets/saved_locations_sheet.dart` (section per visible share; badge count)
- Modify: `lib/main.dart` (refresh on start)
- Modify: arb files
- Test: `test/widgets/map_marker_renderer_test.dart` (extend), `test/widgets/received_shares_section_test.dart`

**Interfaces:**
- Consumes: Task 2 DB methods, Task 4 `refreshReceived`.
- Produces:
  - `MapProvider`: `List<ReceivedShare> get receivedShares`, `Future<void> loadReceivedShares()`, `Future<void> setReceivedShareVisible(String id, bool v)`, `Future<void> deleteReceivedShare(String id)`.
  - `MapMarkerRenderer(..., List<ReceivedShare> receivedShares = const [])` and `List<Marker> buildReceivedShareMarkers({required void Function(SecnjaPoint p) onTap})` — only visible shares; blue pin with the 1-based index as label; same zoom gating as `buildLocationMarkers`.
  - Parcel outline: `PolygonLayer` per visible share, `Colors.blue` border 2 px, fill `Colors.blue` alpha 0.08.
  - Pin tap → `NavigateToSheet.show(context, destination: LatLng(p.lat, p.lng), name: p.name, onInAppNavigation: ...)` reusing what `MapTab` passes for its own points.
  - `ReceivedSharesSection({required List<ReceivedShare> shares, required void Function(String id, bool v) onToggle, required void Function(String id) onDelete})` widget in `map_layer_selector.dart`, shown only when non-empty; header `receivedSectionTitle`; row `🪓 ${secnjaReceivedRow(parcel, ownerOrKo, daysLeft)}` with `Switch` and delete `IconButton` that confirms with `receivedDeleteConfirm`.
  - `MapLayerSelector` and its `show` gain `receivedShares`, `onReceivedShareToggled`, `onReceivedShareDeleted` (optional; section hidden when null).
  - `SavedLocationsSheet` gains `receivedShares` (visible only); one section per share titled with its parcel, tiles navigate. `MapControls.locationsCount` includes received points.
  - `main.dart`: after DB init, `unawaited(SecnjaShareService.instance.refreshReceived().then((_) => mapProvider.loadReceivedShares()))` — executor wires to wherever `MapProvider` is created.
- l10n keys (sl / hr): `receivedSectionTitle` `PREJETO` / `PRIMLJENO`; `secnjaReceivedRow` `Sečnja {parcel} · {who} · še {days} dni` / `Sječa {parcel} · {who} · još {days} dana` (plural on days); `receivedDeleteConfirm` `Odstranim prejeto sečnjo?` / `Ukloniti primljenu sječu?`.

- [ ] **Step 1: Write the failing tests:**
  - Renderer: `hidden share draws no markers`; `visible share draws numbered blue markers in payload order`.
  - Section: `renders one row per share with days left`; `switch calls onToggle`; `delete asks to confirm then calls onDelete`; `section absent when list empty`.
- [ ] **Step 2: Run to see them fail.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `rtk flutter test` (whole suite) and `rtk flutter analyze`.
- [ ] **Step 5: Commit** — `feat: Show received sečnja as a map layer`

---

### Task 10: Deploy and verify on devices

This task touches Cloudflare and Apple; the executor stops and asks the owner before each outward-facing step.

- [ ] **Step 1:** If Task 1 left `REPLACE_ME`, run `rtk npx wrangler kv namespace create SHARES` and commit the id.
- [ ] **Step 2:** Owner enables **Associated Domains** on the `dev.dz0ny.gozdar` App ID in the Apple Developer portal and regenerates the provisioning profile used by the release workflow (otherwise the iOS build fails to sign with the new entitlement).
- [ ] **Step 3:** `cd worker && rtk npx wrangler deploy` (owner's go-ahead). Then:
  - `curl -s https://gozdar.dz0ny.dev/.well-known/apple-app-site-association` → JSON with the app id.
  - `curl -s https://gozdar.dz0ny.dev/.well-known/assetlinks.json` → two fingerprints.
  - POST/GET/PUT/DELETE round trip with `curl`; GET after DELETE → 404.
- [ ] **Step 4:** Android (debug build on a device): `adb shell pm get-app-links dev.dz0ny.gozdar` shows `gozdar.dz0ny.dev: verified`; tapping a link in a messaging app opens Gozdar on the map with the layer visible; a second tap does not duplicate it.
- [ ] **Step 5:** iOS via TestFlight: same flow; Safari on `/s/<id>` without the app shows the install page.
- [ ] **Step 6:** Update `CLAUDE.md`: database is drift (not ObjectBox); `LocationType.secnja` marks carry `parcelId`; share links on `gozdar.dz0ny.dev`. Commit `docs: Note sečnja sharing and drift in CLAUDE.md`.
