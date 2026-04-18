# Google Play Store Assets and Declarations

## URLs

- Support URL: `TODO`
- Privacy policy URL: `TODO`

The privacy policy content draft is in `docs/privacy-policy.md`. Publish it at a stable HTTPS URL before production submission.

## Required Console Declarations

- App access: no special credentials unless a private environment is introduced
- Ads: declare `No` unless ad SDKs are added
- Data safety: reflect actual app behavior from code and permissions review
- Content rating: complete the Play questionnaire
- Target audience: set in Play Console
- News status: `No`

## Data Safety Working Notes

Current Android permissions and SDK usage indicate these disclosures likely need review before submission:

- Location data: used for map position, navigation, and field workflows
- Files or documents created by the user: used for export and sharing
- App info: version/build data via `package_info_plus`

Current code does not indicate ad SDKs or Play billing SDKs.

## Asset Checklist

- App name: `Gozdar`
- Short description: maintain in `android/fastlane/metadata/android/en-US/short_description.txt`
- Full description: maintain in `android/fastlane/metadata/android/en-US/full_description.txt`
- Feature graphic: create `1024x500`
- Phone screenshots: minimum set covering map, parcel management, logs, and offline workflows
- Tablet screenshots: add only if the tablet layout is part of the supported Play listing

## Recommended Screenshot Set

1. Map with cadastral overlays
2. Forest parcel list and summary
3. Log tracking and grouped species totals
4. Navigation or compass workflow
5. Offline map or export workflow

## Maestro Capture Flow

- Install Maestro CLI once: `curl -fsSL "https://get.maestro.mobile.dev" | bash`
- Start an Android emulator and wait until it finishes booting
- Run all phone screenshots: `./scripts/capture_android_phone_screenshots.sh`
- Run one screen only: `./scripts/capture_android_phone_screenshots.sh 01-map`

The script builds the normal Android app once, clears app data, marks onboarding as completed, and uses Maestro to navigate the real UI routes before saving screenshots into:

- `android/fastlane/metadata/android/en-US/images/phoneScreenshots`
- `android/fastlane/metadata/android/sl/images/phoneScreenshots`

Current flows capture:

- `01-map`: map tab
- `02-parcel`: forest tab empty state
- `03-logs`: logs tab empty state
- `04-navigation`: about screen opened from the real app shell
