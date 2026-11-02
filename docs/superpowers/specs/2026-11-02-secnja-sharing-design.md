# Sečnja: marking trees and sharing them with a logger

Design, 2026-11-02. Status: draft for approval.

## Intent

A forest owner walks their parcel and marks the trees to be cut. They then
send the logger (sekač) one short message — parcel number, k.o., tree
count, a link. The logger taps the link, Gozdar opens, and the marked trees
appear on the logger's map as a layer they can switch on and off and
navigate to. The link works for 30 days.

Why: today the owner has to describe the trees over the phone or walk the
logger through the stand. The app already has "Sečnja" markers; what's
missing is fast marking, a way to tie marks to a parcel, and a way to hand
them over.

## Goals

- Marking many trees in a row is fast and needs no typing.
- The parcel list and parcel detail show how many trees are marked.
- One tap shares a parcel's marks as a short message with a link.
- The link opens in Gozdar on the logger's phone; the marks are stored
  locally and work offline in the forest.
- The link expires 30 days after the last share. Re-sharing the same
  parcel updates the same link and restarts the 30 days.
- The owner can revoke a link.
- The sheets off the long-press menu (Točka, Sečnja) become simpler:
  nothing mandatory.

## Non-goals

- No web viewer. A browser opening the link sees only an install page.
- Nothing flows back from logger to owner (no "done" ticks, no messages).
- No accounts, no login. Ownership of a link is proven by a token on the
  owner's phone.
- The Hlodi (log entry) sheet stays as it is.

## Anti-goals

- A second kind of long-press. Long-press has one meaning: open the menu.
- A share link that anyone with the URL can overwrite or delete.
- A link that silently shows stale data after the owner updated it.

## Constraints

- Flutter app, drift database (`lib/db/app_database.dart`, schema version
  4 today). Note: CLAUDE.md still says ObjectBox; drift is what's in use.
- Routing is go_router (`lib/router/app_router.dart`).
- Backend is the existing Cloudflare Worker in `worker/` (Hono, R2 bucket
  `gozdar-v2`, daily cron). Links are served from `gozdar.dz0ny.dev`,
  bound to that worker as a custom domain.
- Android package `dev.dz0ny.gozdar`; iOS bundle `dev.dz0ny.gozdar`, team
  `JND55328G8`.
- UI strings in Slovenian and Croatian (`lib/l10n/app_sl.arb`,
  `app_hr.arb`).
- Markers from Slovenian WMS layers only show at zoom ≥ 11; this feature
  adds no new constraint there.

## Owner side

### Marking mode

Entry: long-press → **Dodaj → Sečnja** (the submenu stays as it is).
Instead of today's name sheet, this enters *marking mode*, built on the
same pattern as the existing distance/area measurement mode in
`map_tab.dart` (crosshair at the map centre, bottom panel, GPS button
still available so the user can centre on where they stand).

Bottom panel, top to bottom:

- Header: `🪓 Sečnja · <parcel number>` on the left, `N dreves` on the
  right. N counts marks on the parcel under the crosshair. When the
  crosshair is outside any saved parcel, the header shows
  `Izven parcele` and marking is still allowed.
- Species chips from `SpeciesService.getSpecies()` plus a `+` chip that
  opens the existing add-species flow. One chip is selected at a time; the
  selection persists for the next mark and is remembered between sessions
  (SharedPreferences). The first time, nothing is selected.
- Tile row: **Razveljavi** (deletes the last mark made in this session),
  **Označi** (primary, drops a mark at the crosshair with haptic
  feedback), **Končaj**.

Each mark is a `MapLocation` of type `secnja`, saved immediately, with:

- `name`: `<Species> <n>` when a species chip is selected, else
  `Drevo <n>`, where `n` is one more than the number of sečnja marks
  already on that parcel (or already outside any parcel). Renaming later
  works as today (tap the pin).
- `parcelId`: the id of the saved parcel whose polygon contains the
  point, or null. When polygons overlap, the parcel with the smallest
  area wins (same rule for the migration backfill).

**Končaj** leaves marking mode. If at least one mark was made on a parcel
during the session, a snackbar offers `Deli sekaču` as its action (my
call; it is a shortcut to the same share flow as below, nothing more).

### Marks and parcels

A new nullable `parcelId` column on `MapLocations` (drift schema version
5). On migration, backfill every existing sečnja mark by point-in-polygon
against the saved parcels, so the Sečnja card in parcel detail keeps
showing them. From now on parcel detail and the Moj gozd count read by
`parcelId`, not by geometry, so an edited polygon does not lose its marks.

Deleting a parcel: marks keep existing but their `parcelId` is cleared
(they fall back to "outside any parcel"). The existing delete summary
("deleted N points") stays as is.

### Moj gozd list

On each parcel row, in the line with the area, append
`· 🪓 N za posek` in deep orange (same colour as sečnja pins) when N > 0.
Nothing when N = 0. Order: area, marked trees, then today's cut-trees and
m³ items.

### Parcel detail: Sečnja card

The existing `ParcelSecnjaCard` gets:

- Items read by `parcelId`. Subtitle shows the species if the name does
  not already carry it — keep the current coordinate subtitle otherwise.
- A footer row with one primary button whose label depends on share
  state:
  - never shared: **Deli sekaču**
  - shared and unchanged since: **Deli znova** (re-opens the share sheet
    with the same link; no upload)
  - shared, marks changed since: **Posodobi povezavo** (uploads, then
    opens the share sheet)
- When shared, a secondary line: `Deljeno · velja do <date>` and a
  text button **Prekliči** that deletes the share on the server, clears
  the local share record, and returns the button to **Deli sekaču**.

"Changed since" is decided by content, not timestamps (`MapLocations` has
no `updatedAt` and deletes leave nothing behind): the parcel stores
`shareHash`, a SHA-256 of the canonical payload JSON at the time of the
last upload. The card rebuilds the payload and compares hashes.

### Share flow

1. Build the payload (below) from the parcel and its marks.
2. If the parcel has no share record: `POST /api/s` → `{id, editToken,
   expiresAt}`. Otherwise `PUT /api/s/:id` with the edit token →
   `{expiresAt}`.
3. Store `{shareId, editToken, sharedAt, expiresAt, shareHash}` on the
   parcel (new nullable columns on `Parcels`, same migration).
4. Open the system share sheet (`share_plus`, already a dependency) with
   this text, no subject:

   ```
   🪓 Sečnja — parcela 1234/5, k.o. Dolenja vas
   12 dreves za posek · 2,31 ha
   Lastnik: Janez Novak
   https://gozdar.dz0ny.dev/s/k7Qm2x
   Povezava velja do 2. 12. 2026
   ```

   The `Lastnik:` line appears only when the parcel's `owner` field is
   non-empty. Area comes from `Parcel.areaM2` (computed from the polygon)
   and is omitted when 0. The k.o. name is resolved the way the long-press
   menu does it (`OwnerLookupService.koName` then
   `KoLocator.bySifko(...).name`); when neither knows it, the message says
   `k.o. 1234` and `koName` is left out of the payload.

Sharing needs network. On failure show a snackbar
`Deljenje ni uspelo — preveri povezavo` and leave the local state as it
was. No retry queue.

### Simpler sheets off the long-press menu

Applies to `showAddLocationDialog` (Točka) only; the Sečnja sheet is
replaced by marking mode, and Hlodi is untouched. Rules:

- Keyboard does not open on its own (`autofocus: false`).
- A chip row above the field with the default name pre-selected
  (`Točka <n>`, n = existing points + 1) and fixed suggestions:
  `Mejnik`, `Lovska preža`, `Izvir`, `Vlaka` (Croatian equivalents in
  `app_hr.arb`). Tapping a chip selects it and clears the free-text
  field; typing in the field deselects the chips.
- Field label: `Svoje ime (neobvezno)`.
- Subtitle: `Parcela <number> · <coordinates>` when the point is inside a
  saved parcel, else coordinates only.
- The primary button always works; no "Vnesite ime" error.

## Logger side

### Deep link

`https://gozdar.dz0ny.dev/s/:id` is registered as an Android App Link
and iOS Universal Link:

- Android: `autoVerify` intent filter for `https` host
  `gozdar.dz0ny.dev` path prefix `/s/`, plus
  `flutter_deeplinking_enabled` meta-data so go_router receives the path.
  Worker serves `/.well-known/assetlinks.json` listing every signing
  certificate the app ships with: the local release keystore
  (`~/android-keystores/gozdar-release-key.jks`, used for the direct APK),
  and the debug keystore. The app is not on Google Play yet; when it
  gets there with Play App Signing, Google's app-signing certificate
  SHA-256 is added as a third entry. Fingerprints are hard-coded in
  `shares.js`.
- iOS: new `ios/Runner/Runner.entitlements` with Associated Domains
  `applinks:gozdar.dz0ny.dev`, `FlutterDeepLinkingEnabled` in
  `Info.plist`. Worker serves `/.well-known/apple-app-site-association`
  (JSON, `application/json`) for `JND55328G8.dev.dz0ny.gozdar`, paths
  `/s/*`.

go_router route `/s/:id` (outside the shell, root navigator) whose
builder triggers the import below and then redirects to the map tab.

### Import

On `/s/:id`: `GET /api/s/:id`. On 200, store the share as a
`ReceivedShare` row (new table): `shareId`, `payloadJson`, `fetchedAt`,
`expiresAt`, `visible = true`. If a row with that `shareId` exists,
replace its payload. Then switch to the map tab, fit the camera to the
parcel polygon, and show a snackbar `Prejeta sečnja: parcela 1234/5 ·
12 dreves`.

On 404/410: snackbar `Povezava je potekla ali bila preklicana`; if a
local row exists for that id, delete it. On network error: snackbar
`Ni povezave — poskusi znova`, nothing stored.

Refresh: on each app start with network, for every stored share, `GET
/api/s/:id` and replace the payload; delete rows whose `expiresAt` has
passed or that come back 404/410. Nothing happens offline.

### Showing it

Map: for each visible received share, draw the parcel outline (thin, same
blue) and the points as numbered pins in blue (`Colors.blue`), numbered by
their order in the payload. Own sečnja pins stay orange. Tapping a pin
opens the existing navigate sheet (`NavigateToSheet`) with the tree's
name as the destination name. Pins show at the same zoom thresholds as
other markers.

Layer selector (`MapLayerSelector`): a new section **PREJETO** below the
existing categories, shown only when at least one received share exists.
One switch row per share:
`🪓 Sečnja <parcel> · <owner or k.o.> · še <n> dni`, with a trailing
delete icon that removes the share locally (confirm dialog). Toggling
sets `visible`.

Saved-points sheet (bottom-left button): a section per visible received
share listing its trees with the existing navigate action. The badge count
on the button includes received trees.

## Server

Worker additions, in `worker/src/shares.js`:

- Infrastructure, done by the builder with `wrangler`: create the KV
  namespace (`wrangler kv namespace create SHARES`) and commit its id to
  `wrangler.toml`; add the custom domain as
  `routes = [{ pattern = "gozdar.dz0ny.dev", custom_domain = true }]`
  (the `dz0ny.dev` zone is already on Cloudflare — `gozdar-kataster.dz0ny.dev`
  lives there). The app's existing base URL
  `https://gozdar-proxy.dz0ny.workers.dev` stays for everything else; only
  share links and the share API use `gozdar.dz0ny.dev`.
- Storage: a new KV namespace `SHARES` bound in `wrangler.toml`. Each
  share is one KV value (the payload JSON plus `editToken`), written with
  `expirationTtl = 30 * 24 * 3600`. KV is chosen over R2 because the TTL
  is a one-liner and there is nothing to list or stream; a re-share
  rewrites the key and so restarts the TTL. Payloads are small (a few KB).
- `POST /api/s` body = payload → `{id, editToken, expiresAt}`. `id`: 6
  chars from `[A-Za-z0-9]` (base62 of random bytes), retry on collision.
  `editToken`: 32 random bytes, base64url.
- `PUT /api/s/:id` header `Authorization: Bearer <editToken>`, body =
  payload → `{expiresAt}`. 403 on wrong token, 404 when missing.
- `DELETE /api/s/:id` same auth → 204.
- `GET /api/s/:id` → payload without `editToken`, plus `expiresAt`. 404
  when missing. `Cache-Control: no-store`.
- `GET /.well-known/assetlinks.json` and
  `/.well-known/apple-app-site-association` → static JSON.
- Payload size limit 256 KB → 413. No other validation beyond "is JSON
  with `parcel` and `points`".
- CORS: the existing global CORS middleware allows GET only; the new
  routes need POST/PUT/DELETE allowed too (the app is not a browser, but
  keep the middleware consistent).

### Payload

```json
{
  "v": 1,
  "parcel": {
    "number": "1234/5",
    "koNumber": "1234",
    "koName": "Dolenja vas",
    "owner": "Janez Novak",
    "areaHa": 2.31,
    "polygon": [[46.05, 14.50], [46.06, 14.50], [46.06, 14.51]]
  },
  "points": [
    {"name": "Smreka 1", "lat": 46.0512, "lng": 14.5051, "species": "Smreka"},
    {"name": "Drevo 2", "lat": 46.0515, "lng": 14.5058}
  ],
  "createdAt": "2026-11-02T10:00:00Z"
}
```

`owner`, `koName`, `species`, `areaHa` are optional. Coordinates are
WGS84, `[lat, lng]`. Server adds `expiresAt` on read.

### Install page

Dropped for now (owner's call, 2026-11-02). In a browser `/s/:id` returns
the worker's JSON 404; only the app handles the link.

## Data changes (drift schema 5)

- `MapLocations.parcelId` INTEGER NULL.
- `Parcels.shareId` TEXT NULL, `Parcels.shareEditToken` TEXT NULL,
  `Parcels.sharedAt` DATETIME NULL, `Parcels.shareExpiresAt` DATETIME NULL,
  `Parcels.shareHash` TEXT NULL.
- New table `ReceivedShares`: `id` autoincrement, `shareId` TEXT UNIQUE,
  `payloadJson` TEXT, `fetchedAt` DATETIME, `expiresAt` DATETIME,
  `visible` BOOL default true.
- Migration 4 → 5: add columns, create table, backfill `parcelId` by
  point-in-polygon.

## New strings

All in `app_sl.arb` and `app_hr.arb`; keys are the builder's choice but
cover: marking-mode header and `Izven parcele`, `N dreves` plural,
`Označi`, `Končaj`, `Razveljavi` (reuse existing where present), default
names `Drevo {n}` / `Točka {n}`, `za posek` count, `Deli sekaču`,
`Deli znova`, `Posodobi povezavo`, `Prekliči`, `Deljeno · velja do {date}`,
share message lines, share failure, received snackbar, expired/revoked
snackbar, no-connection snackbar, `PREJETO`, `še {n} dni`, received-share
delete confirmation, Točka chip labels, `Svoje ime (neobvezno)`.

## Left to the builder

- Exact widget structure of marking mode; reuse the measurement panel
  pieces (`SheetTileRow`, `SheetTile`, crosshair painter) where they fit.
- Pin numbering style for received trees.
- How refresh-on-start is scheduled (e.g. from `MapProvider` init).
- Whether the install page is inline HTML in `shares.js` or a template
  file next to `map.js`.
- Random id/token generation details on the worker (`crypto.getRandomValues`).
- Test coverage; at minimum: migration backfill, "changed since" logic,
  payload build, and worker handlers via `wrangler dev` + curl.

## Verification

- `flutter analyze`, `flutter test`.
- Android: `adb shell pm get-app-links dev.dz0ny.gozdar` shows the domain
  verified; tapping a share link in a messaging app opens Gozdar on the
  map with the layer visible.
- iOS: same via TestFlight build; the AASA validator confirms the file.
- Worker: `curl` POST/GET/PUT/DELETE round trip against `wrangler dev`;
  GET after DELETE is 404; a browser on `/s/<id>` shows the install page.

## Distribution facts (as of 2026-11-02)

- iOS is the only store channel (Apple, via the release workflow's
  TestFlight upload). Android is not on Google Play; APKs come from
  GitHub releases. Both affect only `assetlinks.json` entries and the
  install page buttons, as described above.
