#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

IOS_OUTPUT_DIR="ios/fastlane/screenshots/en-US"
SL_IOS_OUTPUT_DIR="ios/fastlane/screenshots/sl-SI"
IOS_SCREENSHOT_WIDTH=1284
IOS_SCREENSHOT_HEIGHT=2778
IPAD_SCREENSHOT_WIDTH=2048
IPAD_SCREENSHOT_HEIGHT=2732
INTEGRATION_TEST="integration_test/app_screenshots_test.dart"
BUNDLE_ID="dev.dz0ny.gozdar"

IOS_DEVICES=(
  "iPhone 17 Pro Max"
  "iPad Pro 13-inch (M5)"
)

echo -e "${BLUE}Gozdar iOS screenshot generator${NC}"

if [ ! -f "$INTEGRATION_TEST" ]; then
  echo -e "${RED}Missing integration test: $INTEGRATION_TEST${NC}"
  exit 1
fi

if [ ! -f "test_driver/integration_test.dart" ]; then
  echo -e "${RED}Missing integration test driver: test_driver/integration_test.dart${NC}"
  exit 1
fi

take_ios_screenshots() {
  local device_name="$1"
  echo -e "${GREEN}Capturing screenshots on $device_name${NC}"

  local device_line=$(xcrun simctl list devices available | grep "$device_name" | grep -v "unavailable" | head -1)
  local device_id=$(echo "$device_line" | sed -n 's/.*(\([0-9A-F-]*\)).*/\1/p')

  if [ -z "$device_id" ]; then
    echo -e "${RED}Device not found: $device_name${NC}"
    return 1
  fi

  local screenshot_prefix=""
  local screenshot_width="$IOS_SCREENSHOT_WIDTH"
  local screenshot_height="$IOS_SCREENSHOT_HEIGHT"
  local remove_pattern="[0-9][0-9]-*.png"
  if [[ "$device_name" == *"iPad"* ]]; then
    screenshot_prefix="ipad-"
    screenshot_width="$IPAD_SCREENSHOT_WIDTH"
    screenshot_height="$IPAD_SCREENSHOT_HEIGHT"
    remove_pattern="ipad-*.png"
  fi

  mkdir -p "$IOS_OUTPUT_DIR"
  rm -f "$IOS_OUTPUT_DIR"/$remove_pattern

  xcrun simctl shutdown "$device_id" 2>/dev/null || true
  xcrun simctl boot "$device_id" 2>/dev/null || true
  sleep 3
  xcrun simctl uninstall "$device_id" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl privacy "$device_id" grant notifications "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl privacy "$device_id" grant location "$BUNDLE_ID" 2>/dev/null || true

  SCREENSHOT_OUTPUT_DIR="$IOS_OUTPUT_DIR" flutter drive \
    --driver=test_driver/integration_test.dart \
    --target="$INTEGRATION_TEST" \
    -d "$device_id" \
    --dart-define=GOZDAR_SCREENSHOTS=true \
    --dart-define=SCREENSHOT_PREFIX="$screenshot_prefix" \
    --screenshot="$IOS_OUTPUT_DIR" || {
    echo -e "${RED}Screenshot capture failed on $device_name${NC}"
    return 1
  }

  if command -v sips >/dev/null 2>&1; then
    for screenshot in "$IOS_OUTPUT_DIR"/$remove_pattern; do
      sips -z "$screenshot_height" "$screenshot_width" "$screenshot" >/dev/null
    done
  else
    echo -e "${YELLOW}sips not found; screenshots were not resized${NC}"
  fi

  echo -e "${GREEN}Completed $device_name${NC}"
}

if [ "$1" = "--list" ]; then
  xcrun simctl list devices available | grep -E "iPhone|iPad" | grep -v "unavailable"
  exit 0
fi

if [ "$1" = "--device" ] && [ -n "$2" ]; then
  take_ios_screenshots "$2"
else
  for device in "${IOS_DEVICES[@]}"; do
    take_ios_screenshots "$device"
  done
fi

mkdir -p "$SL_IOS_OUTPUT_DIR"
find "$SL_IOS_OUTPUT_DIR" -maxdepth 1 -type f -name '*.png' -delete
cp "$IOS_OUTPUT_DIR"/*.png "$SL_IOS_OUTPUT_DIR"/

echo -e "${GREEN}Screenshots saved to $IOS_OUTPUT_DIR${NC}"
echo -e "${GREEN}Screenshots copied to $SL_IOS_OUTPUT_DIR${NC}"
