#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_DIR="$ROOT_DIR/apps/example/ios"
PODFILE="$IOS_DIR/Podfile"
TEST_POD="  pod 'ExpoEasyPasskey', :path => '../../../packages/module', :testspecs => ['Tests']"
DESTINATION="${IOS_TEST_DESTINATION:-}"

if [[ ! -f "$PODFILE" ]]; then
  echo "Missing generated iOS project. Run Expo prebuild first." >&2
  exit 1
fi

if [[ -z "$DESTINATION" ]]; then
  DEVICE_ID="$(
    xcrun simctl list devices available -j |
      python3 -c 'import json, sys; data = json.load(sys.stdin); print(next(device["udid"] for devices in data["devices"].values() for device in devices if device["name"].startswith("iPhone")))'
  )"
  DESTINATION="platform=iOS Simulator,id=$DEVICE_ID"
fi

python3 - "$PODFILE" "$TEST_POD" <<'PY'
from pathlib import Path
import sys

podfile = Path(sys.argv[1])
test_pod = sys.argv[2]
contents = podfile.read_text()

if test_pod not in contents:
    anchor = "  use_expo_modules!\n"
    if anchor not in contents:
        raise SystemExit("Unable to find use_expo_modules! in generated Podfile")
    podfile.write_text(contents.replace(anchor, f"{anchor}{test_pod}\n", 1))
PY

(
  cd "$IOS_DIR"
  pod install
  xcodebuild test \
    -workspace "ExpoEasyPasskeyExample.xcworkspace" \
    -scheme "ExpoEasyPasskey-Unit-Tests" \
    -destination "$DESTINATION" \
    CODE_SIGNING_ALLOWED=NO
)
