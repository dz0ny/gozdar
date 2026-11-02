# Site Specification

## Configuration
- **Site Type**: General (single product landing page + legal/support pages for Google Play)
- **Target Audience**: Slovenian forest owners, forestry contractors and workers; secondarily Play Store reviewers looking for the privacy/support URLs
- **Primary Goal**: Install the app (Android APK now; Google Play and TestFlight later)
- **Language**: Slovenian only (`lang="sl"`). English skipped: it would double every page and the Play listing does not need it.
- **Production URL**: https://gozdar.dz0ny.dev (served by `../worker` as Workers Static Assets)

## Design Read
Reading this as: a product landing page for Slovenian forest owners, with a grounded, practical, outdoorsy feel, leaning a warm-dark "forest floor" aesthetic that matches the app's own dark-green and tan UI.

## Directions considered (decided without an interview)
- **A. "Gozdna tla"** (chosen) — Dark language, warm near-black green, tan highlight taken from the app UI, topographic contour lines as the only ornament. Fraunces / Instrument Sans. Asymmetric split hero with two real phone screenshots.
- B. "Terenski zvezek" — Minimalist light paper, field-notebook feel, monospace numbers. Rejected: clashes with the app's dark UI, so screenshots would look pasted in.
- C. "Ortofoto" — Full-bleed orthophoto media mask. Rejected: no licensed large aerial image in the repo, and the store screenshots already carry the imagery.

## Design Direction
- **Direction**: "Gozdna tla" — the site looks like the app: dark forest surfaces, tan for anything you should press, contour lines as the map motif.
- **Base Language**: Dark (with Minimalist restraint on ornament)
- **Dials**: VARIANCE 6 · MOTION 5 · DENSITY 4
  - VARIANCE 6: left-aligned 7/5 split hero, bento feature grid, one full-bleed band; no centered hero.
  - MOTION 5: one orchestrated hero entrance + IntersectionObserver scroll reveals (hidden only when JS runs, `.js` class), CTA lift on hover. All behind `prefers-reduced-motion: no-preference`.
  - DENSITY 4: `--spacing-section` 6rem (4rem mobile), 76rem container.
- **Palette** (60/30/10): dominant #0f160f (bg) / #182118 (card) · secondary #2e7d32 brand green (fills, the offline band) · accent #d6a776 tan (CTAs, key numbers) — neutrals derived from the brand hue (OKLCH h≈144, C≈0.02); accent hue h≈67 taken from the app UI rather than a strict triadic rotation, so the site and the app match.
- **Fonts**: Fraunces 400–800 variable (display) / Instrument Sans 400–700 variable (body) — Google via Astro Fonts API, subsets `latin` + `latin-ext` (č š ž).
- **Signature patterns**: Asymmetric Split hero (overlapping tilted phone), Bento (6 cells, kataster lead cell), Split band (logs), Masonry/column-offset screenshot rail (horizontal scroll on mobile), Full-bleed band (offline steps), Column list ("In še to").
- **Motion recipes**: Orchestrated Entrance, Scroll Reveal, Magnetic CTA (lift only).

### Contrast (WCAG, computed with culori)
```
on bg #0f160f / card #182118 / muted #242f23
  foreground        #f2f0e7   16.1 / 14.5 / 12.2  ✓
  muted-foreground  #b0bbb0    9.3 /  8.3 /  7.0  ✓ body text
  faint             #919c91    6.5 /  5.8 /  4.9  ✓ meta text
  brand-bright      #63bc65    7.8 /  7.0 /  5.9  ✓ green text, icons
  primary (tan)     #d6a776    8.5 /  7.6 /  6.4  ✓
  brand             #2e7d32    3.6 /  3.2 /  2.7  ✗ fills/decor only, never text
primary-foreground #24180b on tan: 8.0 ✓
foreground on brand #2e7d32: 4.49 — large text only (the offline band uses it for H2/numbers; step cards sit on bg/85)
```
Stock Tailwind gray/slate utilities are not used for text anywhere.

## Content sources
- Copy anchored on `android/fastlane/metadata/android/sl/*.txt`, `lib/l10n/app_sl.arb` (intro wizard, about, search, export, auction, valuation strings) and the code in `lib/services/`.
- Screenshots: `ios/fastlane/screenshots/sl-SI/0{1..4}-*.png`, cropped to remove the bottom tab bar (it shows an "RTK" tab that is not in current `lib/`). The Android fastlane screenshots are empty states and were not used.
- OG image: `android/fastlane/metadata/android/sl/images/featureGraphic.png`.
- Not marketed on purpose: experimental drone survey tools (off by default), RTK.

## Design Evolution
- **User customizations**: 2026-11-02 — user asked to remove the old Leaflet layer viewer entirely (no `/pregledovalnik`); the landing page owns `/`.
- **Current style**: Dark warm forest-green site, Fraunces headlines with a tan second clause, real phone screenshots in thick rounded bezels, faint green contour lines behind the hero and lead bento cell, one saturated brand-green band for the offline story. Long-form pages (`/zasebnost/`, `/podpora/`) use `.prose-gozd` on a 44rem column.
