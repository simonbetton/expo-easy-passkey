#!/usr/bin/env bash
# Detect drift between committed native binaries and independently generated
# trusted outputs. Committed files are never treated as release evidence.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMITTED_ROOT=""
GENERATED_ROOT=""
PLATFORM=""

ANDROID_TARGETS=(
  "android-arm64-v8a|android/src/main/jniLibs/arm64-v8a/libexpo_easy_passkey_ffi.so"
  "android-armeabi-v7a|android/src/main/jniLibs/armeabi-v7a/libexpo_easy_passkey_ffi.so"
  "android-x86|android/src/main/jniLibs/x86/libexpo_easy_passkey_ffi.so"
  "android-x86_64|android/src/main/jniLibs/x86_64/libexpo_easy_passkey_ffi.so"
)

APPLE_TARGETS=(
  "apple-ios-arm64|ios/rust/ExpoEasyPasskeyFfi.xcframework/ios-arm64/libexpo_easy_passkey_ffi.a"
  "apple-ios-arm64_x86_64-simulator|ios/rust/ExpoEasyPasskeyFfi.xcframework/ios-arm64_x86_64-simulator/libexpo_easy_passkey_ffi.a"
)

usage() {
  cat <<'EOF' >&2
Usage: check-native-artifact-drift.sh \
  --committed-root <dir> \
  --generated-root <dir> \
  --platform <android|apple|all>

Compares required native artifact checksums between committed repository
binaries and independently generated trusted outputs. Exits non-zero on drift.
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --committed-root)
      COMMITTED_ROOT="${2:-}"
      shift 2
      ;;
    --generated-root)
      GENERATED_ROOT="${2:-}"
      shift 2
      ;;
    --platform)
      PLATFORM="${2:-}"
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

[[ -n "$COMMITTED_ROOT" && -n "$GENERATED_ROOT" && -n "$PLATFORM" ]] || usage
[[ -d "$COMMITTED_ROOT" ]] || {
  echo "Committed root does not exist: $COMMITTED_ROOT" >&2
  exit 1
}
[[ -d "$GENERATED_ROOT" ]] || {
  echo "Generated root does not exist: $GENERATED_ROOT" >&2
  exit 1
}

case "$PLATFORM" in
  android | apple | all) ;;
  *)
    echo "Unsupported platform: $PLATFORM" >&2
    usage
    ;;
esac

# shellcheck source=scripts/lib/sha256.sh
source "$ROOT_DIR/scripts/lib/sha256.sh"

collect_targets() {
  case "$1" in
    android)
      printf '%s\n' "${ANDROID_TARGETS[@]}"
      ;;
    apple)
      printf '%s\n' "${APPLE_TARGETS[@]}"
      ;;
    all)
      collect_targets android
      collect_targets apple
      ;;
  esac
}

drift=0
while IFS='|' read -r target_id relative_path; do
  [[ -n "$target_id" ]] || continue
  committed_path="$COMMITTED_ROOT/$relative_path"
  generated_path="$GENERATED_ROOT/$relative_path"

  if [[ ! -f "$committed_path" ]]; then
    echo "Missing committed native artifact for $target_id: $committed_path" >&2
    drift=1
    continue
  fi
  if [[ ! -f "$generated_path" ]]; then
    echo "Missing generated native artifact for $target_id: $generated_path" >&2
    drift=1
    continue
  fi

  committed_digest="$(sha256_file "$committed_path")"
  generated_digest="$(sha256_file "$generated_path")"
  if [[ "$committed_digest" != "$generated_digest" ]]; then
    echo "Native artifact drift for $target_id:" >&2
    echo "  committed sha256: $committed_digest" >&2
    echo "  generated sha256: $generated_digest" >&2
    drift=1
  else
    echo "OK $target_id checksums match"
  fi
done < <(collect_targets "$PLATFORM")

if [[ "$drift" -ne 0 ]]; then
  echo "Committed native binaries drifted from independently generated trusted outputs." >&2
  echo "Update committed binaries for local/dev use; release publication must still consume trusted CI artifacts." >&2
  exit 1
fi

echo "No native artifact drift detected for platform: $PLATFORM"
