#!/usr/bin/env bash
# Seam: scripts/verify-release-acceptance.sh
# Asserts the cross-platform contract acceptance plan stays release-blocking.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/verify-release-acceptance.sh"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/verify-release-acceptance.XXXXXX")"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*"
}

[[ -x "$SCRIPT" ]] || fail "expected executable verify-release-acceptance script at $SCRIPT"

if "$SCRIPT" --help >/dev/null; then
  fail "help should exit non-zero via usage()"
fi
pass "help documents acceptance verification usage"

list_output="$("$SCRIPT" --list)"
printf '%s\n' "$list_output" | grep -q "contract.acceptance.test.ts" ||
  fail "list should include package-to-relying-party contract tests"
printf '%s\n' "$list_output" | grep -q "unsupported.runtime.test.ts" ||
  fail "list should include web/SSR unsupported-runtime tests"
printf '%s\n' "$list_output" | grep -q "passkeys.test.ts" ||
  fail "list should include ceremony isolation tests"
printf '%s\n' "$list_output" | grep -q "Device E2E" ||
  fail "list should include required real-device evidence"
pass "list enumerates automated and real-device acceptance evidence"

"$SCRIPT" || fail "repository acceptance plan should currently pass"
pass "repository acceptance gates are wired"

mkdir -p "$FIXTURE_ROOT/.github/workflows" "$FIXTURE_ROOT/packages/module/src" \
  "$FIXTURE_ROOT/apps/example-backend/src/server" \
  "$FIXTURE_ROOT/apps/docs/content/docs"
cp "$ROOT_DIR/.github/workflows/ci.yml" "$FIXTURE_ROOT/.github/workflows/ci.yml"
cp "$ROOT_DIR/.github/workflows/release.yml" "$FIXTURE_ROOT/.github/workflows/release.yml"
cp "$ROOT_DIR/packages/module/src/contract.acceptance.test.ts" \
  "$FIXTURE_ROOT/packages/module/src/contract.acceptance.test.ts"
cp "$ROOT_DIR/packages/module/src/unsupported.runtime.test.ts" \
  "$FIXTURE_ROOT/packages/module/src/unsupported.runtime.test.ts"
cp "$ROOT_DIR/apps/example-backend/src/server/passkeys.test.ts" \
  "$FIXTURE_ROOT/apps/example-backend/src/server/passkeys.test.ts"
cp "$ROOT_DIR/apps/example-backend/src/server/store.test.ts" \
  "$FIXTURE_ROOT/apps/example-backend/src/server/store.test.ts"
cp "$ROOT_DIR/apps/example-backend/src/server/config.test.ts" \
  "$FIXTURE_ROOT/apps/example-backend/src/server/config.test.ts"
cp "$ROOT_DIR/apps/docs/content/docs/releasing.mdx" \
  "$FIXTURE_ROOT/apps/docs/content/docs/releasing.mdx"
cp "$ROOT_DIR/apps/docs/content/docs/manual-e2e.mdx" \
  "$FIXTURE_ROOT/apps/docs/content/docs/manual-e2e.mdx"
cp "$ROOT_DIR/apps/docs/content/docs/testing.mdx" \
  "$FIXTURE_ROOT/apps/docs/content/docs/testing.mdx"
printf '{\n  "scripts": {\n    "check": "true",\n    "test:acceptance": "true",\n    "verify:release-acceptance": "true"\n  }\n}\n' \
  >"$FIXTURE_ROOT/package.json"

# Strip the release-blocking pnpm check gate from a fixture release workflow.
python3 - <<'PY' "$FIXTURE_ROOT/.github/workflows/release.yml"
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
path.write_text(text.replace("- run: pnpm check\n", "- run: pnpm lint\n"))
PY

if "$SCRIPT" --root "$FIXTURE_ROOT" >/dev/null 2>&1; then
  fail "missing release pnpm check gate should fail verification"
fi
pass "release workflow missing contract check fails verification"

# Restore release workflow and remove an acceptance regression suite.
cp "$ROOT_DIR/.github/workflows/release.yml" "$FIXTURE_ROOT/.github/workflows/release.yml"
rm -f "$FIXTURE_ROOT/packages/module/src/unsupported.runtime.test.ts"

if "$SCRIPT" --root "$FIXTURE_ROOT" >/dev/null 2>&1; then
  fail "missing unsupported-runtime regression suite should fail verification"
fi
pass "missing web/SSR regression coverage fails verification"

# Restore suite and strip real-device evidence requirements from releasing docs.
cp "$ROOT_DIR/packages/module/src/unsupported.runtime.test.ts" \
  "$FIXTURE_ROOT/packages/module/src/unsupported.runtime.test.ts"
python3 - <<'PY' "$FIXTURE_ROOT/apps/docs/content/docs/releasing.mdx"
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
for needle in (
    "Release evidence",
    "association",
    "user verification",
    "response shapes",
):
    text = text.replace(needle, "omitted")
path.write_text(text)
PY

if "$SCRIPT" --root "$FIXTURE_ROOT" >/dev/null 2>&1; then
  fail "releasing docs without real-device evidence requirements should fail"
fi
pass "releasing docs must record real-device and compatibility evidence"

echo "All verify-release-acceptance seam tests passed."
