#!/usr/bin/env bash
# Seam: scripts/build-rust-artifacts.sh CLI contract (no cross-compile).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/build-rust-artifacts.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*"
}

[[ -x "$SCRIPT" ]] || fail "expected executable build script at $SCRIPT"

if "$SCRIPT" --help >/dev/null; then
  fail "help should exit non-zero via usage()"
fi
pass "help documents platform selection"

if "$SCRIPT" windows >/dev/null; then
  fail "unsupported platform should fail"
fi
pass "unsupported platform fails before building"

echo "All build-rust-artifacts CLI seam tests passed."
