#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_DIR="$ROOT_DIR/apps/example/android"
RUST_LIBRARY_DIR="${CARGO_TARGET_DIR:-"$ROOT_DIR/target"}/debug"

if [[ ! -x "$ANDROID_DIR/gradlew" ]]; then
  echo "Missing generated Android project. Run Expo prebuild first." >&2
  exit 1
fi

cargo build \
  --manifest-path "$ROOT_DIR/Cargo.toml" \
  --package expo-easy-passkey-ffi

PASSKEY_RUST_TEST_LIBRARY_PATH="$RUST_LIBRARY_DIR" \
  "$ANDROID_DIR/gradlew" \
  -p "$ANDROID_DIR" \
  :expo-easy-passkey:testDebugUnitTest \
  --tests "expo.modules.easypasskey.PasskeyRequestMapperTest"
