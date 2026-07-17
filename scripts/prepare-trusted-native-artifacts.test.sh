#!/usr/bin/env bash
# Seam: scripts/prepare-trusted-native-artifacts.sh
# Stages immutable trusted natives for publication (never rebuilds).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/prepare-trusted-native-artifacts.sh"
RECORD_SCRIPT="$ROOT_DIR/scripts/record-rust-artifact-metadata.sh"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/prepare-trusted-native.XXXXXX")"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*"
}

SOURCE_COMMIT="deadbeefcafebabe0123456789abcdef01234567"

make_android_tree() {
  local root="$1"
  local payload="${2:-android-trusted}"
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
  local payload="${2:-apple-trusted}"
  local xc="$root/ios/rust/ExpoEasyPasskeyFfi.xcframework"
  mkdir -p "$xc/ios-arm64/Headers" "$xc/ios-arm64_x86_64-simulator/Headers"
  printf '%s' "$payload-device" >"$xc/ios-arm64/libexpo_easy_passkey_ffi.a"
  printf '%s' "$payload-sim" >"$xc/ios-arm64_x86_64-simulator/libexpo_easy_passkey_ffi.a"
  printf '%s' 'header' >"$xc/ios-arm64/Headers/expo_easy_passkey_ffiFFI.h"
  printf '%s' 'header' >"$xc/ios-arm64_x86_64-simulator/Headers/expo_easy_passkey_ffiFFI.h"
  printf '%s' 'plist' >"$xc/Info.plist"
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
    --source-commit "$SOURCE_COMMIT" \
    --lockfile "$FIXTURE_ROOT/Cargo.lock" \
    --output "$output"
}

seed_package_with_stale() {
  local package_dir="$1"
  make_android_tree "$package_dir" "stale-android"
  make_apple_tree "$package_dir" "stale-apple"
}

[[ -x "$SCRIPT" ]] || fail "expected executable prepare script at $SCRIPT"

if "$SCRIPT" --help >/dev/null; then
  fail "help should exit non-zero via usage()"
fi
pass "help documents prepare usage"

write_lockfile

trusted_android="$FIXTURE_ROOT/trusted-android"
trusted_apple="$FIXTURE_ROOT/trusted-apple"
make_android_tree "$trusted_android" "trusted-android"
make_apple_tree "$trusted_apple" "trusted-apple"
mkdir -p "$trusted_android/.rust-artifacts" "$trusted_apple/.rust-artifacts"
record_metadata "$trusted_android" android "$trusted_android/.rust-artifacts/android-native-artifacts.json"
record_metadata "$trusted_apple" apple "$trusted_apple/.rust-artifacts/apple-native-artifacts.json"

package_dir="$FIXTURE_ROOT/package"
seed_package_with_stale "$package_dir"
evidence="$FIXTURE_ROOT/release-evidence.json"

# Missing trusted android source fails and must not leave stale package natives as evidence
if "$SCRIPT" \
  --package-dir "$package_dir" \
  --android-from "$FIXTURE_ROOT/missing-android" \
  --apple-from "$trusted_apple" \
  --expected-source-commit "$SOURCE_COMMIT" \
  --evidence-output "$evidence"; then
  fail "missing android trusted root should fail"
fi
pass "missing android trusted root fails"

# Wrong source commit fails
if "$SCRIPT" \
  --package-dir "$package_dir" \
  --android-from "$trusted_android" \
  --apple-from "$trusted_apple" \
  --expected-source-commit "0000000000000000000000000000000000000000" \
  --evidence-output "$evidence"; then
  fail "source commit mismatch should fail"
fi
pass "source commit mismatch fails"

# Stale trusted payload vs metadata fails
stale_meta_android="$FIXTURE_ROOT/stale-meta-android"
cp -R "$trusted_android" "$stale_meta_android"
printf '%s' 'tampered' >"$stale_meta_android/android/src/main/jniLibs/arm64-v8a/libexpo_easy_passkey_ffi.so"
if "$SCRIPT" \
  --package-dir "$package_dir" \
  --android-from "$stale_meta_android" \
  --apple-from "$trusted_apple" \
  --expected-source-commit "$SOURCE_COMMIT" \
  --evidence-output "$evidence"; then
  fail "checksum mismatch in trusted android should fail"
fi
pass "trusted checksum mismatch fails"

# Successful prepare replaces stale package natives and writes evidence
seed_package_with_stale "$package_dir"
"$SCRIPT" \
  --package-dir "$package_dir" \
  --android-from "$trusted_android" \
  --apple-from "$trusted_apple" \
  --expected-source-commit "$SOURCE_COMMIT" \
  --evidence-output "$evidence"

[[ -f "$evidence" ]] || fail "expected release evidence output"
grep -q 'trusted-android-arm64' "$package_dir/android/src/main/jniLibs/arm64-v8a/libexpo_easy_passkey_ffi.so" \
  || fail "package android natives should come from trusted inputs"
grep -q 'trusted-apple-device' "$package_dir/ios/rust/ExpoEasyPasskeyFfi.xcframework/ios-arm64/libexpo_easy_passkey_ffi.a" \
  || fail "package apple natives should come from trusted inputs"
if grep -q 'stale-android' "$package_dir/android/src/main/jniLibs/arm64-v8a/libexpo_easy_passkey_ffi.so"; then
  fail "stale committed android binaries must not remain after prepare"
fi

python3 - "$evidence" "$SOURCE_COMMIT" "$FIXTURE_ROOT/Cargo.lock" \
  "$trusted_android/.rust-artifacts/android-native-artifacts.json" \
  "$trusted_apple/.rust-artifacts/apple-native-artifacts.json" \
  "$package_dir" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

evidence_path, source_commit, lockfile, android_meta_path, apple_meta_path, package_dir = sys.argv[1:]
evidence = json.loads(Path(evidence_path).read_text(encoding="utf-8"))
android_meta = json.loads(Path(android_meta_path).read_text(encoding="utf-8"))
apple_meta = json.loads(Path(apple_meta_path).read_text(encoding="utf-8"))

assert evidence["schemaVersion"] == 1, evidence
assert evidence["sourceCommit"] == source_commit, evidence
assert evidence["lockfileDigest"] == android_meta["lockfileDigest"] == apple_meta["lockfileDigest"]
assert "android" in evidence["platforms"] and "apple" in evidence["platforms"], evidence
assert evidence["platforms"]["android"]["toolchain"]["rustc"]
assert evidence["platforms"]["apple"]["toolchain"]["rustc"]

android_ids = {t["id"] for t in evidence["platforms"]["android"]["targets"]}
apple_ids = {t["id"] for t in evidence["platforms"]["apple"]["targets"]}
assert android_ids == {
    "android-arm64-v8a",
    "android-armeabi-v7a",
    "android-x86",
    "android-x86_64",
}, android_ids
assert apple_ids == {
    "apple-ios-arm64",
    "apple-ios-arm64_x86_64-simulator",
}, apple_ids

package = Path(package_dir)
for platform_key in ("android", "apple"):
    for target in evidence["platforms"][platform_key]["targets"]:
        path = package / target["path"]
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        assert digest == target["sha256"], (target["id"], digest, target["sha256"])

print("ok")
PY
pass "prepare stages trusted natives and writes release evidence"

# Packing-boundary verify: tarball natives must match evidence
tarball_root="$FIXTURE_ROOT/tarball-package"
mkdir -p "$tarball_root"
cp -R "$package_dir/android" "$package_dir/ios" "$tarball_root/"
printf '%s\n' '{"name":"expo-easy-passkey","version":"0.0.0"}' >"$tarball_root/package.json"
(
  cd "$FIXTURE_ROOT"
  tar -czf packed.tgz -C tarball-package .
)
# npm-style tarballs nest under package/; mimic that
mkdir -p "$FIXTURE_ROOT/npm-style/package"
tar -xzf "$FIXTURE_ROOT/packed.tgz" -C "$FIXTURE_ROOT/npm-style/package"
(
  cd "$FIXTURE_ROOT/npm-style"
  tar -czf ../npm-packed.tgz package
)
"$SCRIPT" \
  --verify-tarball "$FIXTURE_ROOT/npm-packed.tgz" \
  --evidence-output "$evidence"
pass "packed tarball natives match release evidence"

# Tampered tarball fails verify
tampered="$FIXTURE_ROOT/npm-style/package/android/src/main/jniLibs/arm64-v8a/libexpo_easy_passkey_ffi.so"
printf '%s' 'tampered-pack' >"$tampered"
(
  cd "$FIXTURE_ROOT/npm-style"
  tar -czf ../npm-tampered.tgz package
)
if "$SCRIPT" \
  --verify-tarball "$FIXTURE_ROOT/npm-tampered.tgz" \
  --evidence-output "$evidence"; then
  fail "tampered packed tarball should fail evidence verify"
fi
pass "tampered packed tarball fails evidence verify"

echo "All prepare-trusted-native-artifacts seam tests passed."
