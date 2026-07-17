#!/usr/bin/env bash
# Seam: scripts/record-rust-artifact-metadata.sh
# Validates required native targets and records release evidence metadata.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/record-rust-artifact-metadata.sh"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/rust-artifact-metadata.XXXXXX")"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*"
}

require_script() {
  [[ -x "$SCRIPT" ]] || fail "expected executable metadata script at $SCRIPT"
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
    "$xc/ios-arm64" \
    "$xc/ios-arm64_x86_64-simulator"
  printf '%s' "$payload-device" >"$xc/ios-arm64/libexpo_easy_passkey_ffi.a"
  printf '%s' "$payload-sim" >"$xc/ios-arm64_x86_64-simulator/libexpo_easy_passkey_ffi.a"
  printf '%s' 'plist' >"$xc/Info.plist"
}

# --- tests ---

require_script

LOCKFILE="$FIXTURE_ROOT/Cargo.lock"
printf '# fixture lockfile\n' >"$LOCKFILE"
EXPECTED_LOCK_DIGEST="$(shasum -a 256 "$LOCKFILE" | awk '{print $1}')"
SOURCE_COMMIT="deadbeefcafebabe0123456789abcdef01234567"

# Missing Android ABI fails
missing_android="$FIXTURE_ROOT/missing-android"
make_android_tree "$missing_android"
rm -f "$missing_android/android/src/main/jniLibs/x86/libexpo_easy_passkey_ffi.so"
if "$SCRIPT" \
  --artifacts-root "$missing_android" \
  --platform android \
  --source-commit "$SOURCE_COMMIT" \
  --lockfile "$LOCKFILE" \
  --output "$FIXTURE_ROOT/should-not-exist.json"; then
  fail "missing Android ABI should fail metadata recording"
fi
pass "missing Android ABI fails"

# Missing Apple slice fails
missing_apple="$FIXTURE_ROOT/missing-apple"
make_apple_tree "$missing_apple"
rm -f "$missing_apple/ios/rust/ExpoEasyPasskeyFfi.xcframework/ios-arm64/libexpo_easy_passkey_ffi.a"
if "$SCRIPT" \
  --artifacts-root "$missing_apple" \
  --platform apple \
  --source-commit "$SOURCE_COMMIT" \
  --lockfile "$LOCKFILE" \
  --output "$FIXTURE_ROOT/should-not-exist.json"; then
  fail "missing Apple slice should fail metadata recording"
fi
pass "missing Apple slice fails"

# Complete Android inventory writes expected metadata
android_root="$FIXTURE_ROOT/android-ok"
make_android_tree "$android_root" "android-v1"
android_meta="$FIXTURE_ROOT/android-metadata.json"
"$SCRIPT" \
  --artifacts-root "$android_root" \
  --platform android \
  --source-commit "$SOURCE_COMMIT" \
  --lockfile "$LOCKFILE" \
  --output "$android_meta"

python3 - "$android_meta" "$SOURCE_COMMIT" "$EXPECTED_LOCK_DIGEST" <<'PY'
import json, sys
meta = json.load(open(sys.argv[1]))
assert meta["schemaVersion"] == 1, meta
assert meta["sourceCommit"] == sys.argv[2], meta
assert meta["lockfileDigest"] == f"sha256:{sys.argv[3]}", meta
assert meta["platform"] == "android", meta
assert "rustc" in meta["toolchain"], meta
assert "cargo" in meta["toolchain"], meta
assert "host" in meta["toolchain"], meta
ids = {t["id"] for t in meta["targets"]}
assert ids == {
    "android-arm64-v8a",
    "android-armeabi-v7a",
    "android-x86",
    "android-x86_64",
}, ids
for target in meta["targets"]:
    assert target["sha256"] and len(target["sha256"]) == 64, target
    assert target["path"], target
print("ok")
PY
pass "Android metadata records commit, lockfile, toolchain, targets, checksums"

# Same-ABI content change changes checksum
android_changed="$FIXTURE_ROOT/android-changed"
make_android_tree "$android_changed" "android-v2"
changed_meta="$FIXTURE_ROOT/android-changed-metadata.json"
"$SCRIPT" \
  --artifacts-root "$android_changed" \
  --platform android \
  --source-commit "$SOURCE_COMMIT" \
  --lockfile "$LOCKFILE" \
  --output "$changed_meta"

python3 - "$android_meta" "$changed_meta" <<'PY'
import json, sys
a = json.load(open(sys.argv[1]))
b = json.load(open(sys.argv[2]))
a_map = {t["id"]: t["sha256"] for t in a["targets"]}
b_map = {t["id"]: t["sha256"] for t in b["targets"]}
assert a_map.keys() == b_map.keys()
assert any(a_map[k] != b_map[k] for k in a_map), (a_map, b_map)
print("ok")
PY
pass "same-ABI content change alters artifact checksums"

# Complete Apple inventory
apple_root="$FIXTURE_ROOT/apple-ok"
make_apple_tree "$apple_root"
apple_meta="$FIXTURE_ROOT/apple-metadata.json"
"$SCRIPT" \
  --artifacts-root "$apple_root" \
  --platform apple \
  --source-commit "$SOURCE_COMMIT" \
  --lockfile "$LOCKFILE" \
  --output "$apple_meta"

python3 - "$apple_meta" <<'PY'
import json, sys
meta = json.load(open(sys.argv[1]))
assert meta["platform"] == "apple", meta
ids = {t["id"] for t in meta["targets"]}
assert ids == {
    "apple-ios-arm64",
    "apple-ios-arm64_x86_64-simulator",
}, ids
print("ok")
PY
pass "Apple metadata includes device and simulator slices"

echo "All record-rust-artifact-metadata seam tests passed."
