#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ID="${APP_ID:-dev.dz0ny.gozdar}"
DEVICE_ID="${DEVICE_ID:-emulator-5554}"
MAESTRO_BIN="${MAESTRO_BIN:-$HOME/.maestro/bin/maestro}"
OUTPUT_BASE="$ROOT_DIR/android/fastlane/metadata/android"
EN_OUTPUT_DIR="$OUTPUT_BASE/en-US/images/phoneScreenshots"
SL_OUTPUT_DIR="$OUTPUT_BASE/sl/images/phoneScreenshots"
RUN_OUTPUT_BASE="$ROOT_DIR/build/maestro-phone-screenshots"

flows=("01-map" "02-parcel" "03-logs" "04-navigation")

if [[ ! -x "$MAESTRO_BIN" ]]; then
  echo "Maestro CLI not found at $MAESTRO_BIN" >&2
  echo "Install it with: curl -fsSL https://get.maestro.mobile.dev | bash" >&2
  exit 1
fi

if [[ $# -gt 1 ]]; then
  echo "Usage: $0 [01-map|02-parcel|03-logs|04-navigation]" >&2
  exit 1
fi

if [[ $# -eq 1 ]]; then
  selected_flow="$1"
  flows=()
  case "$selected_flow" in
    01-map|02-parcel|03-logs|04-navigation)
      flows=("$selected_flow")
      ;;
    *)
      echo "Unknown screenshot flow: $selected_flow" >&2
      exit 1
      ;;
  esac
fi

mkdir -p "$EN_OUTPUT_DIR" "$SL_OUTPUT_DIR"
mkdir -p "$RUN_OUTPUT_BASE"

adb -s "$DEVICE_ID" wait-for-device >/dev/null

boot_completed="$(adb -s "$DEVICE_ID" shell getprop sys.boot_completed | tr -d '\r')"
if [[ "$boot_completed" != "1" ]]; then
  echo "Android device $DEVICE_ID is not fully booted." >&2
  exit 1
fi

adb -s "$DEVICE_ID" shell settings put system accelerometer_rotation 0 >/dev/null
adb -s "$DEVICE_ID" shell settings put system user_rotation 0 >/dev/null
adb -s "$DEVICE_ID" shell input keyevent KEYCODE_WAKEUP >/dev/null || true
adb -s "$DEVICE_ID" shell input keyevent 82 >/dev/null || true

export MAESTRO_CLI_NO_ANALYTICS=1
export MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED=true

for flow in "${flows[@]}"; do
  file="$flow"
  flow_file="$ROOT_DIR/.maestro/$flow.yaml"
  initial_route=""
  case "$flow" in
    01-map)
      initial_route="/map"
      ;;
    02-parcel)
      initial_route="/forest"
      ;;
    03-logs)
      initial_route="/logs"
      ;;
    04-navigation)
      initial_route="/about"
      ;;
  esac

  echo "Building app for $initial_route..."
  (
    cd "$ROOT_DIR"
    flutter build apk --debug --flavor direct \
      --dart-define=GOZDAR_PLAY_DISTRIBUTION=true \
      --dart-define=GOZDAR_INITIAL_ROUTE="$initial_route"
  )

  echo "Installing APK..."
  adb -s "$DEVICE_ID" install -r "$ROOT_DIR/build/app/outputs/flutter-apk/app-direct-debug.apk" >/dev/null
  adb -s "$DEVICE_ID" shell pm clear "$APP_ID" >/dev/null
  adb -s "$DEVICE_ID" shell "run-as $APP_ID sh -c 'mkdir -p shared_prefs && printf \"%s\n\" \"<?xml version=\\\"1.0\\\" encoding=\\\"utf-8\\\" standalone=\\\"yes\\\" ?>\" \"<map>\" \"    <int name=\\\"flutter.onboarding_version\\\" value=\\\"3\\\" />\" \"</map>\" > shared_prefs/FlutterSharedPreferences.xml'"
  adb -s "$DEVICE_ID" shell pm grant "$APP_ID" android.permission.ACCESS_FINE_LOCATION >/dev/null
  adb -s "$DEVICE_ID" shell pm grant "$APP_ID" android.permission.ACCESS_COARSE_LOCATION >/dev/null

  rm -f "$EN_OUTPUT_DIR/$file.png" "$SL_OUTPUT_DIR/$file.png"
  rm -rf "$RUN_OUTPUT_BASE/$file"

  echo "Capturing $file.png..."
  if [[ "$flow" == "01-map" ]]; then
    generated_png="$RUN_OUTPUT_BASE/$file.png"
    adb -s "$DEVICE_ID" shell am force-stop "$APP_ID" >/dev/null
    adb -s "$DEVICE_ID" shell am start -n "$APP_ID/.MainActivity" >/dev/null
    sleep 12
    adb -s "$DEVICE_ID" exec-out screencap -p > "$generated_png"
    cp "$generated_png" "$EN_OUTPUT_DIR/$file.png"
    cp "$generated_png" "$SL_OUTPUT_DIR/$file.png"
    continue
  fi

  "$MAESTRO_BIN" test \
    --device "$DEVICE_ID" \
    --test-output-dir "$RUN_OUTPUT_BASE/$file" \
    "$flow_file"

  generated_png="$(find "$RUN_OUTPUT_BASE/$file" -name "$file.png" -print -quit)"
  if [[ -z "$generated_png" ]]; then
    echo "Maestro did not produce $file.png" >&2
    exit 1
  fi

  cp "$generated_png" "$EN_OUTPUT_DIR/$file.png"
  cp "$generated_png" "$SL_OUTPUT_DIR/$file.png"
done

echo "Android phone screenshots updated in:"
echo "  $EN_OUTPUT_DIR"
echo "  $SL_OUTPUT_DIR"
