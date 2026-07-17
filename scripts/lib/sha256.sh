# Shared SHA-256 digest helper for release artifact scripts.
# Source from other scripts: source "$ROOT_DIR/scripts/lib/sha256.sh"

sha256_file() {
  shasum -a 256 "$1" | awk '{print $1}'
}
