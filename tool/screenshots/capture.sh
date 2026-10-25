#!/usr/bin/env bash
# Captures the raw App Store screenshots from the iOS Simulator.
#
# Builds the app once with tool/screenshots/main.dart as its entry point, then
# launches it on each store device size with a different garden each time and
# saves what the simulator shows to docs/store/screenshots/raw/<device>/.
# tool/screenshots/compose.py turns those into the captioned store images.
#
#   tool/screenshots/capture.sh                  every device
#   tool/screenshots/capture.sh iphone-6.3       just the ones named
set -euo pipefail

cd "$(dirname "$0")/../.."
OUT=docs/store/screenshots/raw
BUNDLE=com.pipgarden.pipGarden

# App Store Connect's required slots are the medium Dynamic Island iPhone
# (1206 x 2622) and the 13" iPad (2064 x 2752); the large iPhone (1320 x 2868)
# is optional and falls back to the medium set when left empty.
DEVICES=(
  "iphone-6.3|iPhone 18 Pro"
  "iphone-6.9|iPhone 18 Pro Max"
  "ipad-13|iPad Pro 13-inch (M5)"
)

# name | what to show, as SHOT_* pairs written to the app's shot.env (see main.dart)
SHOTS=(
  "garden|SHOT_TAB=garden SHOT_SEASON=spring"
  "journal|SHOT_TAB=journal"
  "season-spring|SHOT_TAB=garden SHOT_SEASON=spring"
  "season-summer|SHOT_TAB=garden SHOT_SEASON=summer"
  "season-autumn|SHOT_TAB=garden SHOT_SEASON=autumn"
  "season-winter|SHOT_TAB=garden SHOT_SEASON=winter"
  "theme-zen|SHOT_TAB=garden SHOT_THEME=zen SHOT_SEASON=summer"
  "theme-tropical|SHOT_TAB=garden SHOT_THEME=tropical SHOT_SEASON=summer"
  "theme-wildflower|SHOT_TAB=garden SHOT_THEME=wildflower SHOT_SEASON=summer"
  # Last: a session leaves its Live Activity in the Dynamic Island afterwards.
  "session|SHOT_TAB=timer SHOT_SESSION=true SHOT_SEASON=spring"
  "garden-session|SHOT_TAB=garden SHOT_SESSION=true SHOT_SEASON=summer"
)

flutter build ios --simulator --debug -t tool/screenshots/main.dart

for device in "${DEVICES[@]}"; do
  folder=${device%%|*}
  name=${device#*|}
  if (($#)) && [[ " $* " != *" $folder "* ]]; then continue; fi
  udid=$(xcrun simctl list devices available |
    grep -F "    $name (" | head -1 | grep -oE '[0-9A-F-]{36}')
  echo "== $name ($udid)"

  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl ui "$udid" appearance light
  xcrun simctl status_bar "$udid" override --time "9:41" \
    --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --operatorName "" \
    --batteryState charged --batteryLevel 100
  xcrun simctl install "$udid" build/ios/iphonesimulator/Runner.app
  mkdir -p "$OUT/$folder"
  documents="$(xcrun simctl get_app_container "$udid" "$BUNDLE" data)/Documents"
  mkdir -p "$documents"

  for shot in "${SHOTS[@]}"; do
    file=${shot%%|*}
    xcrun simctl terminate "$udid" "$BUNDLE" 2>/dev/null || true
    tr ' ' '\n' <<<"${shot#*|}" >"$documents/shot.env"
    xcrun simctl launch "$udid" "$BUNDLE" >/dev/null
    # Long enough for the art to decode and the garden's entrance to finish.
    sleep 10
    xcrun simctl io "$udid" screenshot "$OUT/$folder/$file.png" >/dev/null 2>&1
    echo "   $file"
  done

  xcrun simctl terminate "$udid" "$BUNDLE" || true
  xcrun simctl status_bar "$udid" clear
done
