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
)

if [[ ! -d "$POSTER_DIR" ]]; then
  echo "warning: $POSTER_DIR not found — posters will fall back to placeholders" >&2
fi

echo "==> Booting $DEVICE"
xcrun simctl boot "$DEVICE" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null

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
  xcrun simctl terminate "$DEVICE" "$BUNDLE" >/dev/null 2>&1 || true
  SIMCTL_CHILD_SIMALYTICS_SCREENSHOTS="1" \
  SIMCTL_CHILD_SIMALYTICS_SCREENSHOT_TAB="$tab" \
  SIMCTL_CHILD_SIMALYTICS_SCREENSHOT_SCREEN="${screen:-}" \
  SIMCTL_CHILD_SIMALYTICS_SCREENSHOT_POSTER_DIR="$POSTER_DIR" \
    xcrun simctl launch "$DEVICE" "$BUNDLE" >/dev/null
  sleep 6  # let the seeded UI + local posters render
  xcrun simctl io "$DEVICE" screenshot "$RAW_DIR/$name.png" >/dev/null
  echo "    saved $RAW_DIR/$name.png"
done

echo "==> Done for $DEVICE"
