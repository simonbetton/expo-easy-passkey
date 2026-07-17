#!/usr/bin/env bash
# Smoke-test packaged native Rust artifacts from immutable trusted builds.
# Never rebuilds artifacts — consumes pre-placed outputs (e.g. downloaded CI
# artifacts) and fails on missing, stale, mismatched, or unloadable binaries.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS_C="$ROOT_DIR/scripts/ffi-smoke/uniffi-contract-version.c"
PACKAGE_DIR="$ROOT_DIR/packages/module"
PLATFORM=""
WORK_DIR=""
SKIP_PACK=0
SKIP_FFI=0

ANDROID_ABIS=(
  "arm64-v8a|ARM aarch64|ELF.*shared object"
  "armeabi-v7a|ARM,|ELF.*shared object"
  "x86|80386|ELF.*shared object"
  "x86_64|x86-64|ELF.*shared object"
)

usage() {
  cat <<'EOF' >&2
Usage: smoke-test-packaged-native-artifacts.sh --platform <android|apple> \
  [--package-dir <packages/module>] \
  [--work-dir <dir>] \
  [--skip-pack] \
  [--skip-ffi]

Consumes immutable native artifacts already present under --package-dir.
Does not rebuild Rust artifacts. Packs the module, installs the tarball into
a disposable consumer, inspects every required target, and executes one
exported FFI helper from the packaged runtime.
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      PLATFORM="${2:-}"
      shift 2
      ;;
    --package-dir)
      PACKAGE_DIR="${2:-}"
      shift 2
      ;;
    --work-dir)
      WORK_DIR="${2:-}"
      shift 2
      ;;
    --skip-pack)
      SKIP_PACK=1
      shift
      ;;
    --skip-ffi)
      SKIP_FFI=1
      shift
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

[[ -n "$PLATFORM" ]] || usage
case "$PLATFORM" in
  android | apple) ;;
  *)
    echo "Unsupported platform: $PLATFORM" >&2
    usage
    ;;
esac

[[ -d "$PACKAGE_DIR" ]] || {
  echo "Package directory does not exist: $PACKAGE_DIR" >&2
  exit 1
}

if [[ -z "$WORK_DIR" ]]; then
  WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/smoke-packaged-native.XXXXXX")"
  CLEANUP_WORK=1
else
  mkdir -p "$WORK_DIR"
  CLEANUP_WORK=0
fi

if [[ "${CLEANUP_WORK}" -eq 1 ]]; then
  trap 'rm -rf "$WORK_DIR"' EXIT
fi

metadata_path() {
  echo "$PACKAGE_DIR/.rust-artifacts/${PLATFORM}-native-artifacts.json"
}

require_metadata_and_checksums() {
  local meta
  meta="$(metadata_path)"
  [[ -f "$meta" ]] || {
    echo "Missing immutable artifact metadata: $meta" >&2
    echo "Download trusted build artifacts before smoke-testing." >&2
    exit 1
  }

  python3 "$ROOT_DIR/scripts/lib/verify-native-artifact-metadata.py" \
    "$PACKAGE_DIR" "$meta" "$PLATFORM"
}

inspect_android() {
  local root="$1"
  local abi expected_arch expected_kind path description
  for entry in "${ANDROID_ABIS[@]}"; do
    IFS='|' read -r abi expected_arch expected_kind <<<"$entry"
    path="$root/android/src/main/jniLibs/$abi/libexpo_easy_passkey_ffi.so"
    [[ -f "$path" ]] || {
      echo "Missing Android ABI library: $path" >&2
      exit 1
    }
    description="$(file -b "$path")"
    if [[ ! "$description" =~ $expected_kind ]]; then
      echo "Android $abi library has unexpected format: $description" >&2
      exit 1
    fi
    if [[ ! "$description" =~ $expected_arch ]]; then
      echo "Android $abi library has unexpected architecture: $description" >&2
      exit 1
    fi
    echo "OK Android $abi: $description"
  done
}

inspect_apple() {
  local root="$1"
  local xc plist device_lib sim_lib
  xc="$root/ios/rust/ExpoEasyPasskeyFfi.xcframework"
  plist="$xc/Info.plist"
  device_lib="$xc/ios-arm64/libexpo_easy_passkey_ffi.a"
  sim_lib="$xc/ios-arm64_x86_64-simulator/libexpo_easy_passkey_ffi.a"

  [[ -f "$plist" ]] || {
    echo "Missing xcframework Info.plist: $plist" >&2
    exit 1
  }
  [[ -f "$device_lib" ]] || {
    echo "Missing Apple device slice: $device_lib" >&2
    exit 1
  }
  [[ -f "$sim_lib" ]] || {
    echo "Missing Apple simulator slice: $sim_lib" >&2
    exit 1
  }
  [[ -f "$xc/ios-arm64/Headers/expo_easy_passkey_ffiFFI.h" ]] || {
    echo "Missing Apple device headers" >&2
    exit 1
  }
  [[ -f "$xc/ios-arm64_x86_64-simulator/Headers/expo_easy_passkey_ffiFFI.h" ]] || {
    echo "Missing Apple simulator headers" >&2
    exit 1
  }

  python3 - "$plist" <<'PY'
import plistlib
import sys
from pathlib import Path

plist = plistlib.loads(Path(sys.argv[1]).read_bytes())
if plist.get("CFBundlePackageType") != "XFWK":
    raise SystemExit("xcframework Info.plist missing CFBundlePackageType=XFWK")
libs = {entry.get("LibraryIdentifier"): entry for entry in plist.get("AvailableLibraries", [])}
for required in ("ios-arm64", "ios-arm64_x86_64-simulator"):
    if required not in libs:
        raise SystemExit(f"xcframework Info.plist missing library {required}")
device = libs["ios-arm64"]
if device.get("SupportedArchitectures") != ["arm64"]:
    raise SystemExit(f"ios-arm64 SupportedArchitectures unexpected: {device.get('SupportedArchitectures')}")
if device.get("SupportedPlatform") != "ios":
    raise SystemExit("ios-arm64 SupportedPlatform must be ios")
sim = libs["ios-arm64_x86_64-simulator"]
arches = set(sim.get("SupportedArchitectures") or [])
if arches != {"arm64", "x86_64"}:
    raise SystemExit(f"simulator SupportedArchitectures unexpected: {sorted(arches)}")
if sim.get("SupportedPlatformVariant") != "simulator":
    raise SystemExit("simulator slice missing SupportedPlatformVariant=simulator")
print("OK Apple xcframework Info.plist metadata")
PY

  local device_archs sim_archs
  device_archs="$(lipo -info "$device_lib")"
  sim_archs="$(lipo -info "$sim_lib")"
  [[ "$device_archs" == *"architecture: arm64"* || "$device_archs" == *"architectures: arm64"* ]] || {
    echo "Apple device slice architecture mismatch: $device_archs" >&2
    exit 1
  }
  [[ "$sim_archs" == *"arm64"* && "$sim_archs" == *"x86_64"* ]] || {
    echo "Apple simulator slice architecture mismatch: $sim_archs" >&2
    exit 1
  }
  echo "OK Apple device slice: $device_archs"
  echo "OK Apple simulator slice: $sim_archs"
}

inspect_platform() {
  local root="$1"
  case "$PLATFORM" in
    android) inspect_android "$root" ;;
    apple) inspect_apple "$root" ;;
  esac
}

pack_module() {
  local tarball
  [[ -f "$PACKAGE_DIR/build/index.js" ]] || {
    echo "Missing package build output at $PACKAGE_DIR/build/index.js" >&2
    echo "Run the package TypeScript build before smoke-testing." >&2
    exit 1
  }

  (
    cd "$PACKAGE_DIR"
    npm pack --pack-destination "$WORK_DIR" >/dev/null
  )
  tarball="$(find "$WORK_DIR" -maxdepth 1 -name 'expo-easy-passkey-*.tgz' | head -n 1)"
  [[ -n "$tarball" && -f "$tarball" ]] || {
    echo "npm pack did not produce expo-easy-passkey-*.tgz" >&2
    exit 1
  }
  printf '%s\n' "$tarball"
}

install_consumer() {
  local tarball="$1"
  local consumer_name="$2"
  local consumer_dir="$WORK_DIR/$consumer_name"
  mkdir -p "$consumer_dir"
  cat >"$consumer_dir/package.json" <<EOF
{
  "name": "$consumer_name",
  "private": true,
  "version": "0.0.0",
  "dependencies": {
    "expo-easy-passkey": "file:$tarball"
  }
}
EOF
  (
    cd "$consumer_dir"
    npm install --ignore-scripts >/dev/null
  )

  local installed="$consumer_dir/node_modules/expo-easy-passkey"
  [[ -d "$installed" ]] || {
    echo "Consumer did not install packed package at $installed" >&2
    exit 1
  }

  python3 - "$installed" "$PACKAGE_DIR" <<'PY'
import os
import sys
from pathlib import Path

installed = Path(sys.argv[1]).resolve()
package_dir = Path(sys.argv[2]).resolve()
if installed == package_dir:
    raise SystemExit("Consumer resolved to the workspace package instead of the packed tarball")
if installed.is_symlink():
    target = Path(os.readlink(installed))
    if not target.is_absolute():
        target = (installed.parent / target).resolve()
    if target == package_dir:
        raise SystemExit("Consumer symlink points at the workspace package")
print(f"OK consumer install at {installed}", file=sys.stderr)
PY

  printf '%s\n' "$installed"
}

find_ndk_prebuilt() {
  local ndk_home="${ANDROID_NDK_HOME:-}"
  if [[ -z "$ndk_home" ]]; then
    return 1
  fi
  local candidate
  for candidate in \
    "$ndk_home/toolchains/llvm/prebuilt/linux-x86_64" \
    "$ndk_home/toolchains/llvm/prebuilt/darwin-x86_64" \
    "$ndk_home/toolchains/llvm/prebuilt/"*; do
    if [[ -d "$candidate/sysroot/usr/lib" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

execute_android_ffi() {
  local installed="$1"
  local lib="$installed/android/src/main/jniLibs/x86_64/libexpo_easy_passkey_ffi.so"
  [[ -f "$lib" ]] || {
    echo "Missing packaged Android x86_64 library for FFI smoke: $lib" >&2
    exit 1
  }

  if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
    echo "Android FFI execution requires Linux x86_64 (CI smoke job)." >&2
    exit 1
  fi

  local prebuilt sysroot_lib
  prebuilt="$(find_ndk_prebuilt)" || {
    echo "ANDROID_NDK_HOME must point at an NDK with llvm prebuilt toolchains for Android FFI smoke." >&2
    exit 1
  }
  sysroot_lib=""
  for api in 28 27 26 24 23 22 21; do
    if [[ -d "$prebuilt/sysroot/usr/lib/x86_64-linux-android/$api" ]]; then
      sysroot_lib="$prebuilt/sysroot/usr/lib/x86_64-linux-android/$api"
      break
    fi
  done
  [[ -n "$sysroot_lib" ]] || {
    echo "Could not locate x86_64 Android sysroot libraries under $prebuilt" >&2
    exit 1
  }

  python3 - "$lib" "$sysroot_lib" <<'PY'
import ctypes
import os
import sys
from pathlib import Path

lib_path = Path(sys.argv[1])
sysroot_lib = Path(sys.argv[2])
os.environ["LD_LIBRARY_PATH"] = f"{sysroot_lib}:{os.environ.get('LD_LIBRARY_PATH', '')}"

try:
    lib = ctypes.CDLL(str(lib_path))
except OSError as exc:
    raise SystemExit(f"Failed to load packaged Android FFI library: {exc}") from exc

try:
    fn = lib.ffi_expo_easy_passkey_ffi_uniffi_contract_version
except AttributeError as exc:
    raise SystemExit("Packaged Android library is missing uniffi contract version export") from exc

fn.restype = ctypes.c_uint32
version = int(fn())
if version == 0:
    raise SystemExit("Android FFI smoke returned contract version 0")
print(f"OK Android FFI uniffi_contract_version={version}")
PY
}

pick_ios_simulator_udid() {
  local udid
  udid="$(
    xcrun simctl list devices available \
      | awk -F '[()]' '
          /iPhone/ && /(Shutdown|Booted)/ {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1)
            print $2
            exit
          }
        '
  )"
  [[ -n "$udid" ]] || {
    echo "No available iPhone simulator for Apple FFI smoke" >&2
    exit 1
  }
  echo "$udid"
}

execute_apple_ffi() {
  local installed="$1"
  local lib="$installed/ios/rust/ExpoEasyPasskeyFfi.xcframework/ios-arm64_x86_64-simulator/libexpo_easy_passkey_ffi.a"
  [[ -f "$lib" ]] || {
    echo "Missing packaged Apple simulator library for FFI smoke: $lib" >&2
    exit 1
  }
  [[ -f "$HARNESS_C" ]] || {
    echo "Missing FFI smoke harness: $HARNESS_C" >&2
    exit 1
  }
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Apple FFI execution requires macOS with Xcode." >&2
    exit 1
  fi

  local sdk out udid
  sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
  out="$WORK_DIR/ffi-smoke-apple"
  xcrun -sdk iphonesimulator clang \
    -target arm64-apple-ios16.0-simulator \
    -isysroot "$sdk" \
    -o "$out" \
    "$HARNESS_C" \
    "$lib" \
    -lc++ \
    -lm

  udid="$(pick_ios_simulator_udid)"
  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  xcrun simctl spawn "$udid" "$out"
  echo "OK Apple FFI executed from packaged simulator slice"
}

echo "Smoke-testing packaged native artifacts for platform: $PLATFORM"
echo "Package dir: $PACKAGE_DIR"
echo "Work dir: $WORK_DIR"

require_metadata_and_checksums

if [[ "$SKIP_PACK" -eq 0 ]]; then
  TARBALL="$(pack_module)"
  echo "Packed module: $TARBALL"
  INSTALLED="$(install_consumer "$TARBALL" "${PLATFORM}-consumer")"
  echo "Inspecting packed consumer install at $INSTALLED"
  inspect_platform "$INSTALLED"
else
  INSTALLED="$PACKAGE_DIR"
  echo "Skipping pack; inspecting package dir directly"
  inspect_platform "$INSTALLED"
fi

if [[ "$SKIP_FFI" -eq 0 ]]; then
  case "$PLATFORM" in
    android) execute_android_ffi "$INSTALLED" ;;
    apple) execute_apple_ffi "$INSTALLED" ;;
  esac
else
  echo "Skipping FFI execution"
fi

echo "Packaged native artifact smoke test passed for platform: $PLATFORM"
