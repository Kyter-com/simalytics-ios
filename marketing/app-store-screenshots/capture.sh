#!/usr/bin/env bash
# Capture raw App Store screenshots for one simulator, fully offline, from
# public-domain fixtures.
#
#   capture.sh <device-id> <raw-output-dir>
#
# How it works (see README.md for the full rationale):
#   - A DEBUG-only screenshot mode in the app (ScreenshotMode) is enabled by env:
#       SIMALYTICS_SCREENSHOTS=1           -> in-memory store pre-seeded with
#                                            public-domain fixtures, sync disabled,
#                                            gates opened with a sentinel token.
#       SIMALYTICS_SCREENSHOT_TAB=<tab>    -> launch straight into a tab.
#       SIMALYTICS_SCREENSHOT_POSTER_DIR=… -> local dir of public-domain poster
#                                            JPEGs; a URLProtocol serves these for
#                                            every poster request, so nothing
#                                            copyrighted from Simkl's CDN appears.
#   - No account, no token, no network. Every launch re-seeds deterministically.
#
# The companion `generate.py` then composites the marketing layouts.

set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: capture.sh <device-id> <raw-output-dir>" >&2
  exit 2
fi

DEVICE="$1"
RAW_DIR="$2"

ROOT="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$ROOT/../.." && pwd)"
BUNDLE="com.kyter.simalytics"
SCHEME="simalytics"
DERIVED="$ROOT/.capture-runs/DerivedData"
POSTER_DIR="$ROOT/pd-posters"

SDK_VERSION="$(xcrun --sdk iphonesimulator --show-sdk-version)"
SDK_MAJOR="${SDK_VERSION%%.*}"
if [[ ! "$SDK_MAJOR" =~ ^[0-9]+$ ]] || (( SDK_MAJOR < 26 )); then
  echo "error: App Store captures require the iOS 26+ SDK for Liquid Glass (active SDK: $SDK_VERSION)" >&2
  exit 1
fi

# Ordered capture plan: "<NN-name>:<tab>[:<screen>]" where <tab> is a
# SIMALYTICS_SCREENSHOT_TAB value (lists | upnext | explore | settings), the
# optional <screen> is a SIMALYTICS_SCREENSHOT_SCREEN sub-screen (e.g.
# movies-grid), and <NN-name> is the raw filename (must match a `screen` in
# generate.py's SLIDES).
SCREENS=(
  "01-lists:lists"
  "02-upnext:upnext"
  "03-explore:explore"
  "04-grid:lists:movies-grid"
  "05-movie-detail:lists:movie-detail"
)

if [[ ! -d "$POSTER_DIR" ]]; then
  echo "warning: $POSTER_DIR not found — posters will fall back to placeholders" >&2
fi

echo "==> Booting $DEVICE"
xcrun simctl boot "$DEVICE" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null

RUNTIME_VERSION="$(xcrun simctl getenv "$DEVICE" SIMULATOR_RUNTIME_VERSION)"
RUNTIME_MAJOR="${RUNTIME_VERSION%%.*}"
DEVICE_NAME="$(xcrun simctl getenv "$DEVICE" SIMULATOR_DEVICE_NAME)"
if [[ ! "$RUNTIME_MAJOR" =~ ^[0-9]+$ ]] || (( RUNTIME_MAJOR < 26 )); then
  echo "error: $DEVICE_NAME runs iOS $RUNTIME_VERSION; App Store captures require iOS 26+ for Liquid Glass" >&2
  echo "       choose an iOS 26+ device from: xcrun simctl list devices available" >&2
  exit 1
fi
echo "    $DEVICE_NAME on iOS $RUNTIME_VERSION (SDK $SDK_VERSION)"

echo "==> Overriding the status bar (clean Apple 9:41, full battery/signal)"
xcrun simctl status_bar "$DEVICE" override \
  --time "9:41" \
  --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 \
  --batteryState discharging --batteryLevel 100 2>/dev/null || true

echo "==> Building Debug app for the simulator"
xcodebuild -project "$PROJECT_DIR/simalytics.xcodeproj" -scheme "$SCHEME" \
  -configuration Debug -destination "id=$DEVICE" \
  -derivedDataPath "$DERIVED" \
  build >/dev/null

APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/Simalytics.app"
if [[ ! -d "$APP_PATH" ]]; then
  APP_PATH="$(find "$DERIVED/Build/Products" -maxdepth 2 -name '*.app' -type d | head -1)"
fi
echo "    $APP_PATH"

echo "==> Installing"
xcrun simctl install "$DEVICE" "$APP_PATH"

mkdir -p "$RAW_DIR"
for entry in "${SCREENS[@]}"; do
  IFS=':' read -r name tab screen <<< "$entry"
  echo "==> Capturing $name (tab=$tab${screen:+, screen=$screen})"
  # Show the Anime section everywhere except Explore, where the trending-anime
  # shelf (early B&W art) would clash with the color shelves.
  hide_anime="0"; [[ "$tab" == "explore" ]] && hide_anime="1"
  xcrun simctl terminate "$DEVICE" "$BUNDLE" >/dev/null 2>&1 || true
  SIMCTL_CHILD_SIMALYTICS_SCREENSHOTS="1" \
  SIMCTL_CHILD_SIMALYTICS_SCREENSHOT_TAB="$tab" \
  SIMCTL_CHILD_SIMALYTICS_SCREENSHOT_SCREEN="${screen:-}" \
  SIMCTL_CHILD_SIMALYTICS_SCREENSHOT_HIDE_ANIME="$hide_anime" \
  SIMCTL_CHILD_SIMALYTICS_SCREENSHOT_POSTER_DIR="$POSTER_DIR" \
    xcrun simctl launch "$DEVICE" "$BUNDLE" >/dev/null
  sleep 6  # let the seeded UI + local posters render
  xcrun simctl io "$DEVICE" screenshot "$RAW_DIR/$name.png" >/dev/null
  echo "    saved $RAW_DIR/$name.png"
done

echo "==> Done for $DEVICE"
