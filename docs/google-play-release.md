# Google Play Release Runbook

## Purpose

This runbook prepares and ships the Play-safe Android build for `dev.dz0ny.gozdar`.

## Distribution Modes

- `direct`: signed APK for GitHub or manual distribution. This build keeps the existing GitHub-release updater flow.
- `play`: signed AAB for Google Play. This build disables in-app APK update behavior and removes Play-sensitive installer permissions from the merged manifest.

## Required Secrets and Local Files

- `android/key.properties`
- release keystore referenced by `android/key.properties`
- `/Users/dz0ny/android-keystores/fastlane-480919-0cb30c62db50.json`
- Play Console access for `dev.dz0ny.gozdar`

## Versioning Rules

- Version source of truth: `pubspec.yaml`
- Android `versionCode` is the number after `+`
- `versionCode` must always increase
- `make build-play` bumps the version before building the Play AAB

## Build Commands

Run commands from the repo root.

```bash
flutter build apk --release --flavor direct
flutter build appbundle --release --flavor play --dart-define=GOZDAR_PLAY_DISTRIBUTION=true
```

Repo shortcuts:

```bash
make build
make build-play
make release-play-internal
make release-play-production
```

## Expected Artifacts

- Direct APK: `build/app/outputs/flutter-apk/app-direct-release.apk`
- Play AAB: `build/app/outputs/bundle/playRelease/app-play-release.aab`

## Internal Testing Release Checklist

1. Confirm `pubspec.yaml` version is correct and `versionCode` increases.
2. Confirm `android/key.properties` points to the release keystore.
3. Build the Play bundle with `make build-play`.
4. Verify the merged Play manifest does not include:
   - `android.permission.REQUEST_INSTALL_PACKAGES`
   - `android.permission.INSTALL_PACKAGES`
   - `android.permission.WRITE_EXTERNAL_STORAGE`
   - OTA update provider or install receiver
5. Upload with `make release-play-internal`.
6. Install from the internal testing track on a real Android device.
7. Smoke test startup, location permissions, map layers, parcel flows, exports, and sharing.

## Production Release Checklist

1. Complete internal testing validation first.
2. Confirm Play Console forms are current:
   - App content
   - Data safety
   - App access
   - Ads declaration
   - Content rating
3. Confirm store assets are current:
   - app icon
   - feature graphic
   - phone screenshots
   - 7-inch tablet screenshots if used
   - 10-inch tablet screenshots if used
   - support URL
   - privacy policy URL
4. Prepare release notes in `android/fastlane/metadata/android/en-US/changelogs/default.txt`.
5. Upload with `make release-play-production`.
6. Roll out in Play Console only after post-upload checks pass.

## Fastlane Lanes

- `bundle exec fastlane android internal`
- `bundle exec fastlane android production`
- `bundle exec fastlane android direct_apk`

## Rollback Rules

- Never reuse or lower an Android `versionCode`.
- If a Play release is bad, halt rollout in Play Console and ship a new higher-version fix.
- Keep direct and Play artifacts separate; do not upload the direct APK to Play.

## Play Metadata and Policy Sources

- Listing text and release notes live under `android/fastlane/metadata/android/en-US/`
- Draft privacy policy source lives in `docs/privacy-policy.md`
- Asset requirements and declaration prompts live in `docs/google-play-store-assets.md`
