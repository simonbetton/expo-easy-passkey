#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${CARGO_TARGET_DIR:-"$ROOT_DIR/target"}"
SWIFT_OUT="$ROOT_DIR/packages/module/ios/generated"
KOTLIN_OUT="$ROOT_DIR/packages/module/android/src/main/java/expo/modules/easypasskey/generated"

case "$(uname -s)" in
  Darwin)
    LIBRARY="$TARGET_DIR/debug/libexpo_easy_passkey_ffi.dylib"
    ;;
  *)
    LIBRARY="$TARGET_DIR/debug/libexpo_easy_passkey_ffi.so"
    ;;
esac

mkdir -p "$SWIFT_OUT" "$KOTLIN_OUT"

cargo build --manifest-path "$ROOT_DIR/Cargo.toml" -p expo-easy-passkey-ffi --lib
cargo run \
  --manifest-path "$ROOT_DIR/Cargo.toml" \
  -p expo-easy-passkey-ffi \
  --features cli \
  --bin uniffi-bindgen \
  -- generate \
  --library "$LIBRARY" \
  --language swift \
  --out-dir "$SWIFT_OUT"
cargo run \
  --manifest-path "$ROOT_DIR/Cargo.toml" \
  -p expo-easy-passkey-ffi \
  --features cli \
  --bin uniffi-bindgen \
  -- generate \
  --library "$LIBRARY" \
  --language kotlin \
  --out-dir "$KOTLIN_OUT"
