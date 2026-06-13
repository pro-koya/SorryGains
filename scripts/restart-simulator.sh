#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/SorryGains.xcodeproj"
SCHEME_NAME="SorryGains"
APP_NAME="SorryGains"
BUNDLE_ID="com.sorrygains.SorryGains"
DERIVED_DATA_PATH="$ROOT_DIR/.build"
REQUESTED_DEVICE="${1:-iPhone 16}"

find_booted_udid() {
  xcrun simctl list devices available | awk '
    /\(Booted\)/ {
      if (match($0, /\(([0-9A-F-]+)\)/)) {
        print substr($0, RSTART + 1, RLENGTH - 2)
        exit
      }
    }
  '
}

find_device_udid() {
  local device_name="$1"
  xcrun simctl list devices available | awk -v device_name="$device_name" '
    index($0, "    " device_name " (") == 1 {
      if (match($0, /\(([0-9A-F-]+)\)/)) {
        print substr($0, RSTART + 1, RLENGTH - 2)
        exit
      }
    }
  '
}

BOOTED_UDID="$(find_booted_udid)"

if [[ -n "$BOOTED_UDID" ]]; then
  TARGET_UDID="$BOOTED_UDID"
  echo "Using booted simulator: $TARGET_UDID"
else
  TARGET_UDID="$(find_device_udid "$REQUESTED_DEVICE")"

  if [[ -z "$TARGET_UDID" ]]; then
    echo "Simulator '$REQUESTED_DEVICE' was not found." >&2
    echo "Pass a device name, for example: ./scripts/restart-simulator.sh 'iPhone 17 Pro'" >&2
    exit 1
  fi

  echo "Booting simulator: $REQUESTED_DEVICE ($TARGET_UDID)"
  open -a Simulator
  xcrun simctl boot "$TARGET_UDID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$TARGET_UDID" -b
fi

echo "Building $SCHEME_NAME for simulator..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME_NAME" \
  -configuration Debug \
  -destination "id=$TARGET_UDID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/$APP_NAME.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Built app was not found at: $APP_PATH" >&2
  exit 1
fi

echo "Restarting app in simulator..."
xcrun simctl terminate "$TARGET_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$TARGET_UDID" "$APP_PATH"
xcrun simctl launch "$TARGET_UDID" "$BUNDLE_ID"

echo "Done."
