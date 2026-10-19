#!/usr/bin/env bash
# Captures README screenshots of the example apps on an Apple Watch and an iPhone simulator.
# Usage: scripts/screenshots.sh <project> --watch <Scheme> <bundle id> <scene> [<scene> ...] \
#                                         --iphone <Scheme> <bundle id> <scene> [<scene> ...]
# Writes docs/screenshots/<device>-<scene>.png, for example watch-player.png and iphone-styles.png.
# Every scene shows the generated demo audio bundled with the example app (made by
# scripts/generate-demo-audio.py), and the app labels it "Generated demo audio" on screen. No scene
# uses the microphone.
# Each app writes tmp/screenshot-ready into its container once the scene is on screen; the script
# waits for that marker and exits with an error instead of keeping a blank, stale or home-screen
# capture.
set -euo pipefail

PROJECT="$1"; shift
WATCH_SCHEME=""; WATCH_BUNDLE=""; WATCH_SCENES=()
PHONE_SCHEME=""; PHONE_BUNDLE=""; PHONE_SCENES=()
target=""
while [ $# -gt 0 ]; do
  case "$1" in
    --watch)
      target=watch; WATCH_SCHEME="$2"; WATCH_BUNDLE="$3"; shift 3; continue ;;
    --iphone)
      target=iphone; PHONE_SCHEME="$2"; PHONE_BUNDLE="$3"; shift 3; continue ;;
    *)
      case "$target" in
        watch) WATCH_SCENES+=("$1") ;;
        iphone) PHONE_SCENES+=("$1") ;;
        *) echo "Scene $1 must follow --watch or --iphone" >&2; exit 1 ;;
      esac
      ;;
  esac
  shift
done
if [ ${#WATCH_SCENES[@]} -eq 0 ] && [ ${#PHONE_SCENES[@]} -eq 0 ]; then
  echo "No scenes given" >&2
  exit 1
fi
OUT="docs/screenshots"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"

# Watch captures are small and mostly dark, so a file size threshold cannot tell a blank frame from a
# real one. A small checker looks at the image size and colour variety instead, on both devices.
xcrun swiftc -O scripts/check-screenshot.swift -o "$TMP/check-screenshot"

# newest_runtime <platform regex>: identifier of the newest available runtime, or nothing.
newest_runtime() {
  xcrun simctl list runtimes available -j | jq -r --arg platform "$1" '
    [.runtimes[] | select(.identifier | test($platform))]
    | sort_by(.version | split(".") | map(tonumber)) | last | .identifier // empty'
}

# Ranks Apple Watch names: the newest "Series", then the newest "Ultra", then any other model; bigger
# cases first.
RANK='
  def model: [scan("(?:Series|Ultra|SE) ([0-9]+)")] | (.[0][0] // "0") | tonumber;
  def size: [scan("([0-9]+)mm")] | (.[0][0] // "0") | tonumber;
  def family: if test("Series") then 2 elif test("Ultra") then 1 else 0 end;
  def rank: [(.name | family), (.name | model), (.name | size)];
'

# pick_watch: the best available Apple Watch on the newest watchOS runtime. Creates one when none
# exists.
pick_watch() {
  local udid runtime device_type
  udid=$(xcrun simctl list devices available -j | jq -r "$RANK"'
    [.devices | to_entries[] | select(.key | test("watchOS"))
      | (.key | [scan("[0-9]+")] | map(tonumber)) as $version
      | .value[] | select(.name | test("^Apple Watch"))
      | . + {order: ([$version] + rank)}]
    | sort_by(.order) | last | .udid // empty')
  if [ -n "$udid" ]; then echo "$udid"; return; fi
  runtime=$(newest_runtime watchOS)
  if [ -z "$runtime" ]; then
    echo "No watchOS simulator runtime available" >&2
    exit 1
  fi
  for device_type in $(xcrun simctl list devicetypes -j | jq -r "$RANK"'
    [.devicetypes[] | select(.name | test("^Apple Watch")) | . + {order: rank}] | sort_by(.order) | reverse | .[].identifier'); do
    if udid=$(xcrun simctl create "Screenshots Apple Watch" "$device_type" "$runtime" 2>/dev/null); then
      echo "$udid"
      return
    fi
  done
  echo "Could not create an Apple Watch simulator" >&2
  exit 1
}

# pick_iphone: an iPhone Pro on the newest iOS runtime, then any iPhone. Creates one when none exists.
pick_iphone() {
  local devices udid pattern type runtime
  devices=$(xcrun simctl list devices available -j | jq -c '
    [.devices | to_entries | sort_by(.key) | reverse | .[]
     | select(.key | test("iOS")) | .value[] | select(.name | test("^iPhone"))]')
  for pattern in "^iPhone [0-9]+ Pro$" "Pro$" "^iPhone [0-9]+$"; do
    udid=$(jq -r --arg pattern "$pattern" 'map(select(.name | test($pattern))) | .[0].udid // empty' <<< "$devices")
    if [ -n "$udid" ]; then echo "$udid"; return; fi
  done
  udid=$(jq -r '.[0].udid // empty' <<< "$devices")
  if [ -z "$udid" ]; then
    runtime=$(newest_runtime iOS)
    type=$(xcrun simctl list devicetypes -j | jq -r '
      [.devicetypes[] | select(.name | test("^iPhone"))] | last | .identifier // empty')
    if [ -z "$type" ] || [ -z "$runtime" ]; then
      echo "No iPhone simulator, device type or iOS runtime available" >&2
      exit 1
    fi
    udid=$(xcrun simctl create "Screenshots iPhone" "$type" "$runtime")
  fi
  echo "$udid"
}

# build <scheme> <udid>: builds the scheme for the simulator and prints the app's path.
# The example apps need no entitlements, so an ad-hoc signed build needs no development team.
build() {
  local scheme="$1" udid="$2" app
  xcodebuild build \
    -project "Example/$PROJECT.xcodeproj" \
    -scheme "$scheme" \
    -destination "id=$udid" \
    -derivedDataPath "build/$scheme" \
    CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= | tail -n 5 >&2
  app=$(find "build/$scheme/Build/Products" -maxdepth 2 -name "$scheme.app" | head -n 1)
  if [ -z "$app" ]; then
    echo "Build product $scheme.app not found" >&2
    exit 1
  fi
  echo "$app"
}

# valid_capture <file> <home capture> <previous capture or empty>
# Rejects blank or launching frames (the checker), a capture identical to the home screen or watch
# face (the app never came to the front) and one identical to the previous scene (the app never
# switched).
valid_capture() {
  local file="$1" home="$2" previous="$3"
  [ -s "$file" ] || return 1
  "$TMP/check-screenshot" "$file" || return 1
  if cmp -s "$file" "$home"; then
    return 1
  fi
  if [ -n "$previous" ] && cmp -s "$file" "$previous"; then
    return 1
  fi
  return 0
}

# capture <udid> <app> <bundle id> <device label> <scene> [<scene> ...]: boots the simulator,
# captures every scene, shuts it down again, so `booted` always means this one simulator.
capture() {
  local udid="$1" app="$2" bundle="$3" device="$4" scene file capture previous="" attempt ok waited
  shift 4
  local scenes=("$@")
  xcrun simctl shutdown all > /dev/null 2>&1 || true
  xcrun simctl boot "$udid" || true
  xcrun simctl bootstatus "$udid" -b
  if [ "$device" = "iphone" ]; then
    xcrun simctl status_bar "$udid" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
    xcrun simctl ui "$udid" appearance dark
  fi
  xcrun simctl install "$udid" "$app"
  local container home
  container=$(xcrun simctl get_app_container "$udid" "$bundle" data)
  # A first boot can still be setting up the home screen or watch face, and iOS shows system banners
  # for a while after it; give it time (about 45 seconds on iPhone), then keep a capture of it so a
  # frame where the app never came to the front is rejected.
  if [ "$device" = "iphone" ]; then
    sleep 45
  else
    sleep 15
  fi
  home="$TMP/home-$device.png"
  xcrun simctl io "$udid" screenshot "$home"

  for scene in "${scenes[@]}"; do
    file="$OUT/$device-$scene.png"
    capture="$TMP/$device-$scene.png"
    ok=""
    for attempt in 1 2 3; do
      xcrun simctl terminate "$udid" "$bundle" 2>/dev/null || true
      sleep 1
      rm -f "$container/tmp/screenshot-ready"
      if ! xcrun simctl launch "$udid" "$bundle" -screenshot "$scene"; then
        echo "Could not launch the app for $device-$scene (attempt $attempt), retrying"
        continue
      fi
      # The app writes this marker once the scene is on screen.
      waited=0
      while [ ! -f "$container/tmp/screenshot-ready" ] && [ "$waited" -lt 180 ]; do
        sleep 1
        waited=$((waited + 1))
      done
      if [ ! -f "$container/tmp/screenshot-ready" ]; then
        echo "The app did not show $scene on $device (attempt $attempt), retrying"
        continue
      fi
      # Nothing in the scenes animates (the player is paused at a fixed position), but
      # the system can still be fading the app in after a launch.
      sleep $((3 + attempt * 2))
      rm -f "$capture"
      xcrun simctl io "$udid" screenshot "$capture"
      if valid_capture "$capture" "$home" "$previous"; then
        ok=1
        break
      fi
      echo "Blank, stale or home screen capture for $device-$scene (attempt $attempt), retrying"
    done
    if [ -z "$ok" ]; then
      echo "Capture for $device-$scene is still broken; refusing to commit a bad screenshot." >&2
      exit 1
    fi
    mv "$capture" "$file"
    previous="$file"
    echo "Captured $file ($(wc -c < "$file") bytes)"
  done

  xcrun simctl shutdown "$udid" || true
}

if [ ${#WATCH_SCENES[@]} -gt 0 ]; then
  # A watchOS simulator runtime is needed to build and run; download it if the runner has none.
  if [ -z "$(newest_runtime watchOS)" ]; then
    echo "No watchOS simulator runtime installed, downloading one"
    xcodebuild -downloadPlatform watchOS
  fi
  WATCH=$(pick_watch)
  echo "Using Apple Watch simulator $WATCH"
  WATCH_APP=$(build "$WATCH_SCHEME" "$WATCH")
  capture "$WATCH" "$WATCH_APP" "$WATCH_BUNDLE" watch "${WATCH_SCENES[@]}"
fi

if [ ${#PHONE_SCENES[@]} -gt 0 ]; then
  IPHONE=$(pick_iphone)
  echo "Using iPhone simulator $IPHONE"
  PHONE_APP=$(build "$PHONE_SCHEME" "$IPHONE")
  capture "$IPHONE" "$PHONE_APP" "$PHONE_BUNDLE" iphone "${PHONE_SCENES[@]}"
fi
