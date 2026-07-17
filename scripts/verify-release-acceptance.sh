#!/usr/bin/env bash
# Verify the cross-platform contract acceptance plan remains release-blocking.
#
# Checks that CI and release automation still gate publication on:
# - package-to-relying-party registration/authentication contracts
# - origin trust, ceremony isolation, iOS policy, and web/SSR regressions
# - trusted native artifact build, packaged-target inspection, FFI smoke,
#   and exact-artifact publication checks
# - documented real-device evidence that fixtures cannot prove
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="verify"

usage() {
  cat <<'EOF' >&2
Usage: scripts/verify-release-acceptance.sh [--list] [--root <path>]

Verify that the cross-platform contract acceptance plan is still wired into
CI, release automation, and maintainer documentation.

  --list          Print the acceptance evidence inventory and exit 0
  --root <path>   Verify a repository root other than this checkout
  --help          Show this help and exit non-zero
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list)
      MODE="list"
      shift
      ;;
    --root)
      [[ $# -ge 2 ]] || usage
      ROOT_DIR="$(cd "$2" && pwd)"
      shift 2
      ;;
    --help | -h)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

require_file() {
  local relative="$1"
  [[ -f "$ROOT_DIR/$relative" ]] || fail "missing required acceptance file: $relative"
}

require_contains() {
  local relative="$1"
  local needle="$2"
  local label="${3:-$needle}"
  grep -Fq -- "$needle" "$ROOT_DIR/$relative" ||
    fail "$relative must include release-blocking gate: $label"
}

print_inventory() {
  cat <<'EOF'
Cross-platform contract acceptance evidence

Automated package-to-relying-party seam
- packages/module/src/contract.acceptance.test.ts
  HTTPS iOS origin and configured Android APK-key-hash origins for
  registration and authentication through the public package API

Regression coverage
- packages/module/src/contract.acceptance.test.ts
  Exact origin trust and iOS pre-presentation policy validation
- apps/example-backend/src/server/config.test.ts
  Trusted fingerprint conversion and malformed origin rejection
- apps/example-backend/src/server/store.test.ts
  Concurrent and replayed ceremony isolation
- apps/example-backend/src/server/passkeys.test.ts
  Ceremony identifiers carried through verification
- packages/module/src/unsupported.runtime.test.ts
  Web/SSR import and unsupported ceremony behavior

Native adapter coverage (CI)
- pnpm test:native:android
- pnpm test:native:ios

Trusted release artifact coverage
- .github/workflows/release.yml build-*-native-artifacts jobs
- .github/workflows/release.yml smoke-*-native-artifacts jobs
- .github/workflows/release.yml check-native-artifact-drift job
- prepare-trusted-native-artifacts + packed tarball evidence verification

Publication blockers
- pnpm check (includes contract, ceremony, and web import suites)
- pnpm test:acceptance
- pnpm verify:release-acceptance
- pnpm pack:check
- trusted native smoke / drift / exact-artifact staging failures

Required real-device evidence (Device E2E)
- Association files (AASA / Digital Asset Links)
- App signing certificates and Android fingerprint trust
- System passkey UI presentation
- User verification behavior
- Recorded in release notes before publication

Compatibility
- Preserve existing WebAuthn response shapes and public error codes
  unless an explicit compatibility note is added to the release
EOF
}

if [[ "$MODE" == "list" ]]; then
  print_inventory
  exit 0
fi

require_file "packages/module/src/contract.acceptance.test.ts"
require_file "packages/module/src/unsupported.runtime.test.ts"
require_file "apps/example-backend/src/server/config.test.ts"
require_file "apps/example-backend/src/server/store.test.ts"
require_file "apps/example-backend/src/server/passkeys.test.ts"
require_file ".github/workflows/ci.yml"
require_file ".github/workflows/release.yml"
require_file "apps/docs/content/docs/releasing.mdx"
require_file "apps/docs/content/docs/manual-e2e.mdx"
require_file "apps/docs/content/docs/testing.mdx"
require_file "package.json"

require_contains "package.json" '"check"' "pnpm check script"
require_contains "package.json" '"test:acceptance"' "pnpm test:acceptance script"
require_contains "package.json" '"verify:release-acceptance"' "pnpm verify:release-acceptance script"

require_contains ".github/workflows/ci.yml" "pnpm check" "CI contract suite via pnpm check"
require_contains ".github/workflows/ci.yml" "pnpm test:acceptance" "CI named acceptance suite"
require_contains ".github/workflows/ci.yml" "pnpm verify:release-acceptance" "CI acceptance-plan verification"
require_contains ".github/workflows/ci.yml" "pnpm test:native:android" "CI Android native policy coverage"
require_contains ".github/workflows/ci.yml" "pnpm test:native:ios" "CI iOS native policy coverage"

require_contains ".github/workflows/release.yml" "build-android-native-artifacts" "trusted Android artifact build"
require_contains ".github/workflows/release.yml" "build-apple-native-artifacts" "trusted Apple artifact build"
require_contains ".github/workflows/release.yml" "smoke-android-native-artifacts" "Android packaged-target / FFI smoke"
require_contains ".github/workflows/release.yml" "smoke-apple-native-artifacts" "Apple packaged-target / FFI smoke"
require_contains ".github/workflows/release.yml" "check-native-artifact-drift" "committed vs trusted artifact drift check"
require_contains ".github/workflows/release.yml" "prepare-trusted-native-artifacts.sh" "exact-artifact publication staging"
require_contains ".github/workflows/release.yml" "- run: pnpm check" "release contract/web import gate"
require_contains ".github/workflows/release.yml" "pnpm test:acceptance" "release named acceptance suite"
require_contains ".github/workflows/release.yml" "pnpm verify:release-acceptance" "release acceptance-plan verification"
require_contains ".github/workflows/release.yml" "pnpm pack:check" "release pack inspection gate"
require_contains ".github/workflows/release.yml" "Verify packed natives match release evidence" "packed tarball identity check"

require_contains "apps/docs/content/docs/testing.mdx" "Acceptance plan" "testing acceptance plan"
require_contains "apps/docs/content/docs/releasing.mdx" "Release evidence" "releasing evidence review"
require_contains "apps/docs/content/docs/releasing.mdx" "association" "association real-device evidence"
require_contains "apps/docs/content/docs/releasing.mdx" "user verification" "user verification real-device evidence"
require_contains "apps/docs/content/docs/releasing.mdx" "response shapes" "compatibility for response shapes"
require_contains "apps/docs/content/docs/manual-e2e.mdx" "Release notes" "device evidence recording"

echo "OK: cross-platform contract acceptance plan is release-blocking"
