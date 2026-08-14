# Spec 07 — CI deduplication

## Problem Statement

The CI verify job runs `pnpm check`, then `pnpm test:acceptance`, then `pnpm build`. `pnpm check` already runs the full JS test suite (including the acceptance Jest files) via `pnpm test`, and package tests already build the module. The explicit acceptance script rebuilds and re-runs the same contract, unsupported-runtime, and backend suites. That doubles work on every PR in a pipeline that also pays for Rust and native compile jobs.

## Solution

Keep a named, release-blocking acceptance signal without executing the same Jest files twice in one verify job. Prefer making acceptance ownership clear (either `check`/`test` excludes those files and `test:acceptance` owns them, or verify relies on `check` plus a non-executing inventory/`verify:release-acceptance` gate). Remove redundant final rebuilds where `check`/`test` already produced equivalent confidence.

## User Stories

1. As a contributor, I want PR verify to finish faster without losing acceptance coverage, so that feedback loops stay short.
2. As a maintainer, I want a single clear owner for acceptance Jest execution per CI run, so that logs are easier to read.
3. As a release maintainer, I want `pnpm verify:release-acceptance` (or `--list`) to keep proving acceptance gates are wired, so that inventory drift still fails CI.
4. As a maintainer, I want contract, unsupported-runtime, and backend store/passkey/config tests to remain release-blocking, so that security-sensitive ceremony coverage cannot be dropped accidentally.
5. As a local developer, I want `pnpm test:acceptance` to remain a convenient way to run only the acceptance subset, so that focused iteration stays possible.
6. As a local developer, I want `pnpm check` / `pnpm verify` semantics documented if scripts change, so that README and Testing docs stay accurate.
7. As a CI consumer, I want android-compile and ios-compile jobs left functionally intact, so that native compile confidence is unchanged.
8. As a maintainer, I want script tests for any changed acceptance wiring, so that CI YAML and package scripts cannot drift.
9. As a contributor, I want format/lint/typecheck to keep running once per verify job, so that static checks are not sacrificed for speed.
10. As a maintainer, I want failure attribution to remain obvious when acceptance fails, so that debugging does not require guessing which duplicate step failed.

## Implementation Decisions

- Choose one ownership model and apply it consistently in root package scripts and `.github/workflows/ci.yml`:
  - **Preferred:** keep acceptance files in normal package `test` runs OR in `test:acceptance`, not both in the same CI job; use `verify:release-acceptance` for inventory/wiring.
  - Avoid dropping acceptance from CI entirely.
- Update Testing / releasing docs only if command lists change.
- Prefer minimal script churn: do not invent a second parallel test stack.
- Keep lefthook `pnpm verify` behavior coherent with CI when changing `check`/`verify` composition.
- Do not weaken frozen-lockfile install, rust fmt/clippy, or bindgen checks.

## Testing Decisions

- Good tests assert script inventories and workflow references, not wall-clock CI duration.
- Extend or add shell tests alongside `verify-release-acceptance.test.sh` if acceptance ownership moves.
- Manually reason about `ci.yml` step order when changing it; no need for a live Actions run in the unit suite.
- Prior art: `scripts/verify-release-acceptance.sh` and its `.test.sh` companion; other `scripts/*.test.sh` patterns.

## Out of Scope

- Speeding up Android NDK / iOS xcodebuild compile jobs beyond removing duplicate JS work.
- Changing release workflow artifact trust model.
- Removing native compile jobs.
- Introducing a new CI provider.

## Further Notes

Audit finding 8. The goal is fewer duplicate Jest/module-build executions per verify run while preserving the named acceptance plan described in Testing docs.
