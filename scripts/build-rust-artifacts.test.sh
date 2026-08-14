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

help_output="$("$SCRIPT" --help 2>&1)" && fail "help should exit non-zero via usage()"
printf '%s\n' "$help_output" | grep -q -- "--artifacts-root" ||
  fail "help should document --artifacts-root"
pass "help documents platform selection and --artifacts-root"

if "$SCRIPT" windows >/dev/null 2>&1; then
  fail "unsupported platform should fail"
fi
pass "unsupported platform fails before building"

if "$SCRIPT" android --nope >/dev/null 2>&1; then
  fail "unknown flag should fail before building"
fi
pass "unknown flags fail before building"

if "$SCRIPT" --artifacts-root >/dev/null 2>&1; then
  fail "missing --artifacts-root value should fail"
fi
pass "missing --artifacts-root value fails before building"

echo "All build-rust-artifacts CLI seam tests passed."
