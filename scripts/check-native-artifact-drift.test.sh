#!/usr/bin/env bash
# Seam: scripts/check-native-artifact-drift.sh
# Fails when committed natives drift from independently generated trusted outputs.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/check-native-artifact-drift.sh"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/native-artifact-drift.XXXXXX")"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*"
}

make_android_tree() {
  local root="$1"
  local payload="${2:-payload}"
  mkdir -p \
    "$root/android/src/main/jniLibs/arm64-v8a" \
    "$root/android/src/main/jniLibs/armeabi-v7a" \
    "$root/android/src/main/jniLibs/x86" \
    "$root/android/src/main/jniLibs/x86_64"
  printf '%s' "$payload-arm64" >"$root/android/src/main/jniLibs/arm64-v8a/libexpo_easy_passkey_ffi.so"
  printf '%s' "$payload-armv7" >"$root/android/src/main/jniLibs/armeabi-v7a/libexpo_easy_passkey_ffi.so"
  printf '%s' "$payload-x86" >"$root/android/src/main/jniLibs/x86/libexpo_easy_passkey_ffi.so"
  printf '%s' "$payload-x64" >"$root/android/src/main/jniLibs/x86_64/libexpo_easy_passkey_ffi.so"
}

make_apple_tree() {
  local root="$1"
  local payload="${2:-payload}"
  local xc="$root/ios/rust/ExpoEasyPasskeyFfi.xcframework"
  mkdir -p "$xc/ios-arm64" "$xc/ios-arm64_x86_64-simulator"
  printf '%s' "$payload-device" >"$xc/ios-arm64/libexpo_easy_passkey_ffi.a"
  printf '%s' "$payload-sim" >"$xc/ios-arm64_x86_64-simulator/libexpo_easy_passkey_ffi.a"
}

[[ -x "$SCRIPT" ]] || fail "expected executable drift script at $SCRIPT"

if "$SCRIPT" --help >/dev/null; then
  fail "help should exit non-zero via usage()"
fi
pass "help documents drift usage"

committed="$FIXTURE_ROOT/committed"
generated="$FIXTURE_ROOT/generated"
make_android_tree "$committed" "same"
make_apple_tree "$committed" "same"
make_android_tree "$generated" "same"
make_apple_tree "$generated" "same"

"$SCRIPT" \
  --committed-root "$committed" \
  --generated-root "$generated" \
  --platform all
pass "matching committed and generated natives pass"

make_android_tree "$generated" "different"
if "$SCRIPT" \
  --committed-root "$committed" \
  --generated-root "$generated" \
  --platform android; then
  fail "android drift should fail"
fi
pass "android content drift fails"

make_android_tree "$generated" "same"
make_apple_tree "$generated" "different"
if "$SCRIPT" \
  --committed-root "$committed" \
  --generated-root "$generated" \
  --platform apple; then
  fail "apple drift should fail"
fi
pass "apple content drift fails"

missing="$FIXTURE_ROOT/missing-generated"
make_android_tree "$missing" "same"
rm -f "$missing/android/src/main/jniLibs/x86/libexpo_easy_passkey_ffi.so"
if "$SCRIPT" \
  --committed-root "$committed" \
  --generated-root "$missing" \
  --platform android; then
  fail "missing generated ABI should fail"
fi
pass "missing generated ABI fails"

echo "All check-native-artifact-drift seam tests passed."
