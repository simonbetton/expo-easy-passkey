#!/usr/bin/env bash
# Seam: scripts/smoke-test-packaged-native-artifacts.sh
# Validates packaged native targets from immutable artifacts (no rebuild).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/smoke-test-packaged-native-artifacts.sh"
RECORD_SCRIPT="$ROOT_DIR/scripts/record-rust-artifact-metadata.sh"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/smoke-native-artifacts.XXXXXX")"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*"
}

require_script() {
  [[ -x "$SCRIPT" ]] || fail "expected executable smoke-test script at $SCRIPT"
}

make_android_tree() {
  local root="$1"
  local payload="${2:-android-default}"
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
  local payload="${2:-apple-default}"
  local xc="$root/ios/rust/ExpoEasyPasskeyFfi.xcframework"
  mkdir -p \
    "$xc/ios-arm64/Headers" \
    "$xc/ios-arm64_x86_64-simulator/Headers"
  printf '%s' "$payload-device" >"$xc/ios-arm64/libexpo_easy_passkey_ffi.a"
  printf '%s' "$payload-sim" >"$xc/ios-arm64_x86_64-simulator/libexpo_easy_passkey_ffi.a"
  printf '%s' 'header' >"$xc/ios-arm64/Headers/expo_easy_passkey_ffiFFI.h"
  printf '%s' 'header' >"$xc/ios-arm64_x86_64-simulator/Headers/expo_easy_passkey_ffiFFI.h"
  cat >"$xc/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AvailableLibraries</key>
	<array>
		<dict>
			<key>LibraryIdentifier</key>
			<string>ios-arm64</string>
			<key>LibraryPath</key>
			<string>libexpo_easy_passkey_ffi.a</string>
			<key>SupportedArchitectures</key>
			<array>
				<string>arm64</string>
			</array>
			<key>SupportedPlatform</key>
			<string>ios</string>
		</dict>
		<dict>
			<key>LibraryIdentifier</key>
			<string>ios-arm64_x86_64-simulator</string>
			<key>LibraryPath</key>
			<string>libexpo_easy_passkey_ffi.a</string>
			<key>SupportedArchitectures</key>
			<array>
				<string>arm64</string>
				<string>x86_64</string>
			</array>
			<key>SupportedPlatform</key>
			<string>ios</string>
			<key>SupportedPlatformVariant</key>
			<string>simulator</string>
		</dict>
	</array>
	<key>CFBundlePackageType</key>
	<string>XFWK</string>
	<key>XCFrameworkFormatVersion</key>
	<string>1.0</string>
</dict>
</plist>
EOF
}

write_lockfile() {
  printf '# fixture lockfile\n' >"$FIXTURE_ROOT/Cargo.lock"
}

record_metadata() {
  local root="$1"
  local platform="$2"
  local output="$3"
  "$RECORD_SCRIPT" \
    --artifacts-root "$root" \
    --platform "$platform" \
    --source-commit "deadbeefcafebabe0123456789abcdef01234567" \
    --lockfile "$FIXTURE_ROOT/Cargo.lock" \
    --output "$output"
}

# --- tests ---

require_script
write_lockfile

if "$SCRIPT" --help >/dev/null; then
  fail "help should exit non-zero via usage()"
fi
pass "help documents smoke-test usage"

if "$SCRIPT" --platform windows >/dev/null 2>&1; then
  fail "unsupported platform should fail"
fi
pass "unsupported platform fails"

# Missing Android ABI fails before any rebuild
missing_android="$FIXTURE_ROOT/missing-android"
make_android_tree "$missing_android"
mkdir -p "$missing_android/.rust-artifacts"
record_metadata "$missing_android" android "$missing_android/.rust-artifacts/android-native-artifacts.json"
rm -f "$missing_android/android/src/main/jniLibs/x86/libexpo_easy_passkey_ffi.so"

if "$SCRIPT" \
  --platform android \
  --package-dir "$missing_android" \
  --work-dir "$FIXTURE_ROOT/work-missing-android" \
  --skip-pack \
  --skip-ffi; then
  fail "missing Android ABI should fail smoke validation"
fi
pass "missing Android ABI fails without rebuilding"

# Metadata checksum mismatch fails (stale / wrong binary)
stale_android="$FIXTURE_ROOT/stale-android"
make_android_tree "$stale_android" "android-v1"
mkdir -p "$stale_android/.rust-artifacts"
record_metadata "$stale_android" android "$stale_android/.rust-artifacts/android-native-artifacts.json"
printf '%s' 'android-v2-arm64' >"$stale_android/android/src/main/jniLibs/arm64-v8a/libexpo_easy_passkey_ffi.so"
if "$SCRIPT" \
  --platform android \
  --package-dir "$stale_android" \
  --work-dir "$FIXTURE_ROOT/work-stale-android" \
  --skip-pack \
  --skip-ffi; then
  fail "stale Android checksum should fail smoke validation"
fi
pass "stale Android artifact checksum fails"

# Wrong library format fails inspection
bad_format="$FIXTURE_ROOT/bad-format-android"
make_android_tree "$bad_format"
mkdir -p "$bad_format/.rust-artifacts"
record_metadata "$bad_format" android "$bad_format/.rust-artifacts/android-native-artifacts.json"
if "$SCRIPT" \
  --platform android \
  --package-dir "$bad_format" \
  --work-dir "$FIXTURE_ROOT/work-bad-format" \
  --skip-pack \
  --skip-ffi; then
  fail "non-ELF Android library should fail format inspection"
fi
pass "mismatched Android library format fails"

# Missing Apple slice fails
missing_apple="$FIXTURE_ROOT/missing-apple"
make_apple_tree "$missing_apple"
mkdir -p "$missing_apple/.rust-artifacts"
record_metadata "$missing_apple" apple "$missing_apple/.rust-artifacts/apple-native-artifacts.json"
rm -f "$missing_apple/ios/rust/ExpoEasyPasskeyFfi.xcframework/ios-arm64/libexpo_easy_passkey_ffi.a"
if "$SCRIPT" \
  --platform apple \
  --package-dir "$missing_apple" \
  --work-dir "$FIXTURE_ROOT/work-missing-apple" \
  --skip-pack \
  --skip-ffi; then
  fail "missing Apple slice should fail smoke validation"
fi
pass "missing Apple slice fails without rebuilding"

# Real package artifacts: inspect + pack into consumers + FFI (platform-gated)
PACKAGE_DIR="$ROOT_DIR/packages/module"
if [[ ! -f "$PACKAGE_DIR/android/src/main/jniLibs/arm64-v8a/libexpo_easy_passkey_ffi.so" ]]; then
  fail "expected real Android artifacts under packages/module for live smoke coverage"
fi

# Ensure metadata exists for live package tree (local/CI without prior build metadata)
LIVE_META_DIR="$FIXTURE_ROOT/live-metadata"
mkdir -p "$LIVE_META_DIR" "$PACKAGE_DIR/.rust-artifacts"

record_metadata "$PACKAGE_DIR" android "$LIVE_META_DIR/android-native-artifacts.json"
cp "$LIVE_META_DIR/android-native-artifacts.json" "$PACKAGE_DIR/.rust-artifacts/"

if [[ "$(uname -s)" == "Linux" ]]; then
  if ! "$SCRIPT" \
    --platform android \
    --package-dir "$PACKAGE_DIR" \
    --work-dir "$FIXTURE_ROOT/work-live-android"; then
    fail "live Android packaged smoke test should pass on Linux"
  fi
  consumer="$FIXTURE_ROOT/work-live-android/android-consumer"
  installed="$consumer/node_modules/expo-easy-passkey"
  for abi in arm64-v8a armeabi-v7a x86 x86_64; do
    [[ -f "$installed/android/src/main/jniLibs/$abi/libexpo_easy_passkey_ffi.so" ]] \
      || fail "Android consumer missing packed ABI $abi"
  done
  if [[ -L "$installed" ]]; then
    target="$(readlink "$installed")"
    [[ "$target" != *"/packages/module" ]] || fail "Android consumer must not link the workspace package"
  fi
  pass "Android consumer installs packed tarball and executes FFI"
else
  # Host cannot dlopen Android ELF; still prove inspect + packed consumer install.
  if ! "$SCRIPT" \
    --platform android \
    --package-dir "$PACKAGE_DIR" \
    --work-dir "$FIXTURE_ROOT/work-live-android" \
    --skip-ffi; then
    fail "live Android inspect/pack smoke test should pass"
  fi
  consumer="$FIXTURE_ROOT/work-live-android/android-consumer"
  installed="$consumer/node_modules/expo-easy-passkey"
  for abi in arm64-v8a armeabi-v7a x86 x86_64; do
    [[ -f "$installed/android/src/main/jniLibs/$abi/libexpo_easy_passkey_ffi.so" ]] \
      || fail "Android consumer missing packed ABI $abi"
  done
  pass "Android consumer installs packed tarball (FFI deferred to Linux CI)"
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  [[ -f "$PACKAGE_DIR/ios/rust/ExpoEasyPasskeyFfi.xcframework/ios-arm64/libexpo_easy_passkey_ffi.a" ]] \
    || fail "expected real Apple artifacts under packages/module for live smoke coverage"
  record_metadata "$PACKAGE_DIR" apple "$LIVE_META_DIR/apple-native-artifacts.json"
  cp "$LIVE_META_DIR/apple-native-artifacts.json" "$PACKAGE_DIR/.rust-artifacts/"
  if ! "$SCRIPT" \
    --platform apple \
    --package-dir "$PACKAGE_DIR" \
    --work-dir "$FIXTURE_ROOT/work-live-apple"; then
    fail "live Apple packaged smoke test should pass on macOS"
  fi
  consumer="$FIXTURE_ROOT/work-live-apple/apple-consumer"
  installed="$consumer/node_modules/expo-easy-passkey"
  [[ -f "$installed/ios/rust/ExpoEasyPasskeyFfi.xcframework/ios-arm64/libexpo_easy_passkey_ffi.a" ]] \
    || fail "Apple consumer missing packed device slice"
  [[ -f "$installed/ios/rust/ExpoEasyPasskeyFfi.xcframework/ios-arm64_x86_64-simulator/libexpo_easy_passkey_ffi.a" ]] \
    || fail "Apple consumer missing packed simulator slice"
  if [[ -L "$installed" ]]; then
    target="$(readlink "$installed")"
    [[ "$target" != *"/packages/module" ]] || fail "Apple consumer must not link the workspace package"
  fi
  pass "Apple consumer installs packed tarball and executes FFI"
fi

echo "All smoke-test-packaged-native-artifacts seam tests passed."
