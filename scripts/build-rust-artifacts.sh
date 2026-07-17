#!/usr/bin/env bash
# Build packageable native Rust artifacts from the committed lockfile.
# Outputs land under packages/module and are accompanied by release metadata.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${CARGO_TARGET_DIR:-"$ROOT_DIR/target"}"
PACKAGE_DIR="$ROOT_DIR/packages/module"
CRATE="expo-easy-passkey-ffi"
LIB_NAME="libexpo_easy_passkey_ffi"
METADATA_SCRIPT="$ROOT_DIR/scripts/record-rust-artifact-metadata.sh"

ANDROID_OUT="$PACKAGE_DIR/android/src/main/jniLibs"
IOS_RUST_DIR="$PACKAGE_DIR/ios/rust"
IOS_XCFRAMEWORK="$IOS_RUST_DIR/ExpoEasyPasskeyFfi.xcframework"
IOS_HEADERS_DIR="$TARGET_DIR/expo-easy-passkey-ffi-headers"
IOS_SIM_DIR="$TARGET_DIR/expo-easy-passkey-ffi-ios-simulator"
METADATA_DIR="${RUST_ARTIFACT_METADATA_DIR:-$PACKAGE_DIR/.rust-artifacts}"

PLATFORM="${1:-all}"

usage() {
  cat <<'EOF' >&2
Usage: build-rust-artifacts.sh [android|apple|all]

Builds native Rust artifacts from the release commit's Cargo.lock (--locked)
into packages/module, then records immutable artifact metadata.
EOF
  exit 2
}

case "$PLATFORM" in
  android | apple | all) ;;
  -h | --help)
    usage
    ;;
  *)
    echo "Unsupported platform: $PLATFORM" >&2
    usage
    ;;
esac

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require_command cargo
require_command rustup
require_command rustc

SOURCE_COMMIT="${RUST_ARTIFACT_SOURCE_COMMIT:-$(git -C "$ROOT_DIR" rev-parse HEAD)}"

build_android() {
  if ! cargo ndk --version >/dev/null 2>&1; then
    echo "Missing required Cargo subcommand: cargo-ndk" >&2
    echo "Install it with: cargo install cargo-ndk" >&2
    exit 1
  fi

  rustup target add \
    aarch64-linux-android \
    armv7-linux-androideabi \
    i686-linux-android \
    x86_64-linux-android

  rm -rf "$ANDROID_OUT"
  mkdir -p "$ANDROID_OUT"

  cargo ndk \
    --target arm64-v8a \
    --target armeabi-v7a \
    --target x86 \
    --target x86_64 \
    --output-dir "$ANDROID_OUT" \
    build \
    --manifest-path "$ROOT_DIR/Cargo.toml" \
    --package "$CRATE" \
    --release \
    --locked
}

build_apple_target() {
  local triple="$1"
  cargo build \
    --manifest-path "$ROOT_DIR/Cargo.toml" \
    --package "$CRATE" \
    --release \
    --locked \
    --target "$triple"
}

build_apple() {
  require_command xcodebuild
  require_command lipo

  rustup target add \
    aarch64-apple-ios \
    aarch64-apple-ios-sim \
    x86_64-apple-ios

  rm -rf "$IOS_XCFRAMEWORK" "$IOS_HEADERS_DIR" "$IOS_SIM_DIR"
  mkdir -p "$IOS_RUST_DIR" "$IOS_HEADERS_DIR" "$IOS_SIM_DIR"

  build_apple_target aarch64-apple-ios
  build_apple_target aarch64-apple-ios-sim
  build_apple_target x86_64-apple-ios

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
}

record_metadata() {
  local platform="$1"
  mkdir -p "$METADATA_DIR"
  "$METADATA_SCRIPT" \
    --artifacts-root "$PACKAGE_DIR" \
    --platform "$platform" \
    --source-commit "$SOURCE_COMMIT" \
    --lockfile "$ROOT_DIR/Cargo.lock" \
    --output "$METADATA_DIR/${platform}-native-artifacts.json"
}

case "$PLATFORM" in
  android)
    build_android
    record_metadata android
    ;;
  apple)
    build_apple
    record_metadata apple
    ;;
  all)
    build_android
    build_apple
    record_metadata all
    ;;
esac

echo "Native Rust artifacts ready for platform: $PLATFORM"
