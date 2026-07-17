#!/usr/bin/env bash
# Stage immutable trusted native artifacts into the publishable package.
# Never rebuilds natives and never treats previously committed binaries as
# release evidence — trusted inputs are wiped into place and checksum-verified.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/packages/module"
ANDROID_FROM=""
APPLE_FROM=""
EXPECTED_SOURCE_COMMIT=""
EVIDENCE_OUTPUT=""
VERIFY_TARBALL=""

usage() {
  cat <<'EOF' >&2
Usage: prepare-trusted-native-artifacts.sh \
  --android-from <trusted-android-dir> \
  --apple-from <trusted-apple-dir> \
  --expected-source-commit <sha> \
  --evidence-output <release-evidence.json> \
  [--package-dir <packages/module>]

   or: prepare-trusted-native-artifacts.sh \
  --verify-tarball <expo-easy-passkey-*.tgz> \
  --evidence-output <release-evidence.json>

Wipes package native paths, copies immutable trusted Android and Apple
artifacts validated by prior smoke jobs, verifies metadata checksums and
source commit, and writes combined release evidence for publication.

The --verify-tarball mode checks that a packed tarball's native files match
release evidence checksums across the packing boundary.
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --package-dir)
      PACKAGE_DIR="${2:-}"
      shift 2
      ;;
    --android-from)
      ANDROID_FROM="${2:-}"
      shift 2
      ;;
    --apple-from)
      APPLE_FROM="${2:-}"
      shift 2
      ;;
    --expected-source-commit)
      EXPECTED_SOURCE_COMMIT="${2:-}"
      shift 2
      ;;
    --evidence-output)
      EVIDENCE_OUTPUT="${2:-}"
      shift 2
      ;;
    --verify-tarball)
      VERIFY_TARBALL="${2:-}"
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

if [[ -n "$VERIFY_TARBALL" ]]; then
  [[ -n "$EVIDENCE_OUTPUT" ]] || usage
  [[ -f "$VERIFY_TARBALL" ]] || {
    echo "Packed tarball does not exist: $VERIFY_TARBALL" >&2
    exit 1
  }
  [[ -f "$EVIDENCE_OUTPUT" ]] || {
    echo "Release evidence does not exist: $EVIDENCE_OUTPUT" >&2
    exit 1
  }
  EXTRACT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/verify-trusted-tarball.XXXXXX")"
  trap 'rm -rf "$EXTRACT_DIR"' EXIT
  tar -xzf "$VERIFY_TARBALL" -C "$EXTRACT_DIR"
  PACKAGE_ROOT="$(find "$EXTRACT_DIR" -maxdepth 1 -mindepth 1 -type d | head -n 1)"
  [[ -n "$PACKAGE_ROOT" && -d "$PACKAGE_ROOT" ]] || {
    echo "Packed tarball did not contain a package directory" >&2
    exit 1
  }
  python3 - "$PACKAGE_ROOT" "$EVIDENCE_OUTPUT" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

package_root = Path(sys.argv[1])
evidence = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
for platform_key, platform in evidence.get("platforms", {}).items():
    for target in platform.get("targets", []):
        path = package_root / target["path"]
        if not path.is_file():
            raise SystemExit(f"Packed tarball missing {platform_key} artifact: {path}")
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != target["sha256"]:
            raise SystemExit(
                f"Packed tarball drift for {target['id']}: "
                f"expected sha256 {target['sha256']}, got {digest}"
            )
print("Verified packed tarball natives match release evidence")
PY
  echo "Packing boundary identity verified against release evidence"
  exit 0
fi

[[ -n "$ANDROID_FROM" && -n "$APPLE_FROM" && -n "$EXPECTED_SOURCE_COMMIT" && -n "$EVIDENCE_OUTPUT" ]] || usage
[[ -d "$PACKAGE_DIR" ]] || {
  echo "Package directory does not exist: $PACKAGE_DIR" >&2
  exit 1
}
[[ -d "$ANDROID_FROM" ]] || {
  echo "Trusted Android artifact root does not exist: $ANDROID_FROM" >&2
  exit 1
}
[[ -d "$APPLE_FROM" ]] || {
  echo "Trusted Apple artifact root does not exist: $APPLE_FROM" >&2
  exit 1
}

ANDROID_META="$ANDROID_FROM/.rust-artifacts/android-native-artifacts.json"
APPLE_META="$APPLE_FROM/.rust-artifacts/apple-native-artifacts.json"
[[ -f "$ANDROID_META" ]] || {
  echo "Missing Android immutable metadata: $ANDROID_META" >&2
  exit 1
}
[[ -f "$APPLE_META" ]] || {
  echo "Missing Apple immutable metadata: $APPLE_META" >&2
  exit 1
}

verify_platform_metadata() {
  local root="$1"
  local meta="$2"
  local platform="$3"
  python3 - "$root" "$meta" "$platform" "$EXPECTED_SOURCE_COMMIT" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
meta_path = Path(sys.argv[2])
platform = sys.argv[3]
expected_commit = sys.argv[4]
meta = json.loads(meta_path.read_text(encoding="utf-8"))

if meta.get("platform") not in {platform, "all"}:
    raise SystemExit(f"{platform} metadata platform is {meta.get('platform')!r}")
if meta.get("sourceCommit") != expected_commit:
    raise SystemExit(
        f"{platform} metadata sourceCommit {meta.get('sourceCommit')!r} "
        f"does not match expected {expected_commit!r}"
    )

expected = {
    "android": {
        "android-arm64-v8a",
        "android-armeabi-v7a",
        "android-x86",
        "android-x86_64",
    },
    "apple": {
        "apple-ios-arm64",
        "apple-ios-arm64_x86_64-simulator",
    },
}[platform]

targets = meta.get("targets") or []
ids = {t["id"] for t in targets}
missing = expected - ids
if missing:
    raise SystemExit(f"{platform} metadata missing targets: {sorted(missing)}")

for target in targets:
    if target["id"] not in expected:
        continue
    path = root / target["path"]
    if not path.is_file():
        raise SystemExit(f"Missing trusted {platform} artifact: {path}")
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != target["sha256"]:
        raise SystemExit(
            f"Stale or mismatched trusted {platform} artifact for {target['id']}: "
            f"expected sha256 {target['sha256']}, got {digest}"
        )

print(f"Verified trusted {platform} metadata and checksums")
PY
}

wipe_package_natives() {
  rm -rf "$PACKAGE_DIR/android/src/main/jniLibs"
  rm -rf "$PACKAGE_DIR/ios/rust/ExpoEasyPasskeyFfi.xcframework"
  mkdir -p "$PACKAGE_DIR/android/src/main" "$PACKAGE_DIR/ios/rust" "$PACKAGE_DIR/.rust-artifacts"
}

copy_tree() {
  local from="$1"
  local relative="$2"
  local source="$from/$relative"
  local dest="$PACKAGE_DIR/$relative"
  [[ -e "$source" ]] || {
    echo "Trusted input missing path: $source" >&2
    exit 1
  }
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest"
  cp -R "$source" "$dest"
}

echo "Preparing trusted native artifacts for publication"
echo "Package dir: $PACKAGE_DIR"
echo "Expected source commit: $EXPECTED_SOURCE_COMMIT"

verify_platform_metadata "$ANDROID_FROM" "$ANDROID_META" android
verify_platform_metadata "$APPLE_FROM" "$APPLE_META" apple

wipe_package_natives
copy_tree "$ANDROID_FROM" "android/src/main/jniLibs"
copy_tree "$APPLE_FROM" "ios/rust/ExpoEasyPasskeyFfi.xcframework"
cp "$ANDROID_META" "$PACKAGE_DIR/.rust-artifacts/android-native-artifacts.json"
cp "$APPLE_META" "$PACKAGE_DIR/.rust-artifacts/apple-native-artifacts.json"

# Re-verify staged package contents match trusted metadata (identity across boundaries).
verify_platform_metadata "$PACKAGE_DIR" "$PACKAGE_DIR/.rust-artifacts/android-native-artifacts.json" android
verify_platform_metadata "$PACKAGE_DIR" "$PACKAGE_DIR/.rust-artifacts/apple-native-artifacts.json" apple

mkdir -p "$(dirname "$EVIDENCE_OUTPUT")"
python3 - \
  "$EVIDENCE_OUTPUT" \
  "$EXPECTED_SOURCE_COMMIT" \
  "$PACKAGE_DIR/.rust-artifacts/android-native-artifacts.json" \
  "$PACKAGE_DIR/.rust-artifacts/apple-native-artifacts.json" <<'PY'
import json
import sys
from pathlib import Path

evidence_output, source_commit, android_meta_path, apple_meta_path = sys.argv[1:]
android_meta = json.loads(Path(android_meta_path).read_text(encoding="utf-8"))
apple_meta = json.loads(Path(apple_meta_path).read_text(encoding="utf-8"))

if android_meta.get("lockfileDigest") != apple_meta.get("lockfileDigest"):
    raise SystemExit("Android and Apple lockfile digests disagree")
if android_meta.get("sourceCommit") != apple_meta.get("sourceCommit"):
    raise SystemExit("Android and Apple source commits disagree")
if android_meta.get("sourceCommit") != source_commit:
    raise SystemExit("Staged metadata source commit does not match expected commit")

evidence = {
    "schemaVersion": 1,
    "sourceCommit": source_commit,
    "lockfileDigest": android_meta["lockfileDigest"],
    "platforms": {
        "android": {
            "toolchain": android_meta.get("toolchain", {}),
            "targets": android_meta.get("targets", []),
        },
        "apple": {
            "toolchain": apple_meta.get("toolchain", {}),
            "targets": apple_meta.get("targets", []),
        },
    },
}

Path(evidence_output).write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
print(f"Wrote release evidence: {evidence_output}")
PY

echo "Trusted native artifacts staged for publication"
