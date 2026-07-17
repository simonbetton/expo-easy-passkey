#!/usr/bin/env bash
# Record immutable release evidence for built native Rust artifacts.
# Seam used by trusted CI build jobs and local artifact builds.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ARTIFACTS_ROOT=""
PLATFORM=""
SOURCE_COMMIT=""
LOCKFILE="$ROOT_DIR/Cargo.lock"
OUTPUT=""

usage() {
  cat <<'EOF' >&2
Usage: record-rust-artifact-metadata.sh \
  --artifacts-root <dir> \
  --platform <android|apple|all> \
  --output <metadata.json> \
  [--source-commit <sha>] \
  [--lockfile <Cargo.lock>]
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifacts-root)
      ARTIFACTS_ROOT="${2:-}"
      shift 2
      ;;
    --platform)
      PLATFORM="${2:-}"
      shift 2
      ;;
    --source-commit)
      SOURCE_COMMIT="${2:-}"
      shift 2
      ;;
    --lockfile)
      LOCKFILE="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT="${2:-}"
      shift 2
      ;;
    -h | --help)
      usage
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      ;;
  esac
done

[[ -n "$ARTIFACTS_ROOT" && -n "$PLATFORM" && -n "$OUTPUT" ]] || usage
[[ -d "$ARTIFACTS_ROOT" ]] || {
  echo "Artifacts root does not exist: $ARTIFACTS_ROOT" >&2
  exit 1
}
[[ -f "$LOCKFILE" ]] || {
  echo "Lockfile not found: $LOCKFILE" >&2
  exit 1
}

case "$PLATFORM" in
  android | apple | all) ;;
  *)
    echo "Unsupported platform: $PLATFORM" >&2
    exit 1
    ;;
esac

if [[ -z "$SOURCE_COMMIT" ]]; then
  SOURCE_COMMIT="$(git -C "$ROOT_DIR" rev-parse HEAD)"
fi

# shellcheck source=scripts/lib/sha256.sh
source "$ROOT_DIR/scripts/lib/sha256.sh"

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Missing required native artifact: $path" >&2
    exit 1
  fi
}

collect_targets() {
  case "$1" in
    android)
      cat <<'EOF'
android-arm64-v8a|android/src/main/jniLibs/arm64-v8a/libexpo_easy_passkey_ffi.so
android-armeabi-v7a|android/src/main/jniLibs/armeabi-v7a/libexpo_easy_passkey_ffi.so
android-x86|android/src/main/jniLibs/x86/libexpo_easy_passkey_ffi.so
android-x86_64|android/src/main/jniLibs/x86_64/libexpo_easy_passkey_ffi.so
EOF
      ;;
    apple)
      cat <<'EOF'
apple-ios-arm64|ios/rust/ExpoEasyPasskeyFfi.xcframework/ios-arm64/libexpo_easy_passkey_ffi.a
apple-ios-arm64_x86_64-simulator|ios/rust/ExpoEasyPasskeyFfi.xcframework/ios-arm64_x86_64-simulator/libexpo_easy_passkey_ffi.a
EOF
      ;;
    all)
      collect_targets android
      collect_targets apple
      ;;
  esac
}

TARGET_ROWS="$(mktemp "${TMPDIR:-/tmp}/rust-artifact-targets.XXXXXX")"
trap 'rm -f "$TARGET_ROWS"' EXIT

while IFS='|' read -r target_id relative_path; do
  [[ -n "$target_id" ]] || continue
  absolute_path="$ARTIFACTS_ROOT/$relative_path"
  require_file "$absolute_path"
  digest="$(sha256_file "$absolute_path")"
  printf '%s\t%s\t%s\n' "$target_id" "$relative_path" "$digest" >>"$TARGET_ROWS"
done < <(collect_targets "$PLATFORM")

LOCK_DIGEST="$(sha256_file "$LOCKFILE")"
RUSTC_VERSION="$(rustc -V)"
CARGO_VERSION="$(cargo -V)"
HOST_TRIPLE="$(rustc -vV | awk -F': ' '/^host:/{print $2}')"
CARGO_NDK_VERSION=""
if cargo ndk --version >/dev/null 2>&1; then
  CARGO_NDK_VERSION="$(cargo ndk --version 2>/dev/null | head -n 1 || true)"
fi
ANDROID_NDK_VERSION=""
if [[ -n "${ANDROID_NDK_HOME:-}" && -f "${ANDROID_NDK_HOME}/source.properties" ]]; then
  ANDROID_NDK_VERSION="$(
    awk -F'=' '/Pkg.Revision/{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' \
      "${ANDROID_NDK_HOME}/source.properties"
  )"
fi

mkdir -p "$(dirname "$OUTPUT")"

python3 - \
  "$OUTPUT" \
  "$SOURCE_COMMIT" \
  "$LOCK_DIGEST" \
  "$PLATFORM" \
  "$RUSTC_VERSION" \
  "$CARGO_VERSION" \
  "$HOST_TRIPLE" \
  "$CARGO_NDK_VERSION" \
  "$ANDROID_NDK_VERSION" \
  "$TARGET_ROWS" <<'PY'
import json
import sys

(
    output,
    source_commit,
    lock_digest,
    platform,
    rustc,
    cargo,
    host,
    cargo_ndk,
    android_ndk,
    target_rows_path,
) = sys.argv[1:]

targets = []
with open(target_rows_path, encoding="utf-8") as handle:
    for line in handle:
        target_id, path, digest = line.rstrip("\n").split("\t")
        targets.append({"id": target_id, "path": path, "sha256": digest})

toolchain = {
    "rustc": rustc,
    "cargo": cargo,
    "host": host,
}
if cargo_ndk:
    toolchain["cargoNdk"] = cargo_ndk
if android_ndk:
    toolchain["androidNdk"] = android_ndk

metadata = {
    "schemaVersion": 1,
    "sourceCommit": source_commit,
    "lockfileDigest": f"sha256:{lock_digest}",
    "toolchain": toolchain,
    "platform": platform,
    "targets": targets,
}

with open(output, "w", encoding="utf-8") as handle:
    json.dump(metadata, handle, indent=2)
    handle.write("\n")
PY

echo "Wrote native artifact metadata: $OUTPUT"
