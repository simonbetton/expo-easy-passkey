#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${CARGO_TARGET_DIR:-"$ROOT_DIR/target"}"
PACKAGE_DIR="$ROOT_DIR/packages/module"
CRATE="expo-easy-passkey-ffi"
LIB_NAME="libexpo_easy_passkey_ffi"

ANDROID_OUT="$PACKAGE_DIR/android/src/main/jniLibs"
IOS_RUST_DIR="$PACKAGE_DIR/ios/rust"
IOS_XCFRAMEWORK="$IOS_RUST_DIR/ExpoEasyPasskeyFfi.xcframework"
IOS_HEADERS_DIR="$TARGET_DIR/expo-easy-passkey-ffi-headers"
IOS_SIM_DIR="$TARGET_DIR/expo-easy-passkey-ffi-ios-simulator"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_command cargo
require_command rustup
require_command xcodebuild
require_command lipo

if ! cargo ndk --version >/dev/null 2>&1; then
  echo "Missing required Cargo subcommand: cargo-ndk" >&2
  echo "Install it with: cargo install cargo-ndk" >&2
  exit 1
fi

rustup target add \
  aarch64-apple-ios \
  aarch64-apple-ios-sim \
  x86_64-apple-ios \
  aarch64-linux-android \
  armv7-linux-androideabi \
  i686-linux-android \
  x86_64-linux-android

rm -rf "$ANDROID_OUT" "$IOS_XCFRAMEWORK" "$IOS_HEADERS_DIR" "$IOS_SIM_DIR"
mkdir -p "$ANDROID_OUT" "$IOS_RUST_DIR" "$IOS_HEADERS_DIR" "$IOS_SIM_DIR"

cargo ndk \
  --target arm64-v8a \
  --target armeabi-v7a \
  --target x86 \
  --target x86_64 \
  --output-dir "$ANDROID_OUT" \
  build \
  --manifest-path "$ROOT_DIR/Cargo.toml" \
  --package "$CRATE" \
  --release

cargo build --manifest-path "$ROOT_DIR/Cargo.toml" --package "$CRATE" --release --target aarch64-apple-ios
cargo build --manifest-path "$ROOT_DIR/Cargo.toml" --package "$CRATE" --release --target aarch64-apple-ios-sim
cargo build --manifest-path "$ROOT_DIR/Cargo.toml" --package "$CRATE" --release --target x86_64-apple-ios

cp "$PACKAGE_DIR/ios/generated/expo_easy_passkey_ffiFFI.h" "$IOS_HEADERS_DIR/"
cp "$PACKAGE_DIR/ios/generated/expo_easy_passkey_ffiFFI.modulemap" "$IOS_HEADERS_DIR/module.modulemap"

lipo -create \
  "$TARGET_DIR/aarch64-apple-ios-sim/release/$LIB_NAME.a" \
  "$TARGET_DIR/x86_64-apple-ios/release/$LIB_NAME.a" \
  -output "$IOS_SIM_DIR/$LIB_NAME.a"

xcodebuild -create-xcframework \
  -library "$TARGET_DIR/aarch64-apple-ios/release/$LIB_NAME.a" \
  -headers "$IOS_HEADERS_DIR" \
  -library "$IOS_SIM_DIR/$LIB_NAME.a" \
  -headers "$IOS_HEADERS_DIR" \
  -output "$IOS_XCFRAMEWORK"
