# Spec 08 — AGENTS.md agent guide

## Problem Statement

This repository spans TypeScript, Rust, Swift, Kotlin, Expo config plugins, UniFFI bindings, and release artifact scripts. Contributors and coding agents must reconstruct prerequisites, generated-artifact boundaries, and safe verification commands from README, package scripts, Testing, and Releasing docs. There is no root `AGENTS.md` or `CLAUDE.md`, so agents often run incomplete checks, regenerate the wrong artifacts, or treat ignored native outputs as source of truth.

## Solution

Add a concise root `AGENTS.md` that points agents at repository layout, toolchains, what not to commit, canonical verify commands, and when real-device E2E is required. Keep it short and aligned with existing CI/scripts rather than duplicating full human tutorials.

## User Stories

1. As a coding agent, I want a single root guide naming packages and crates, so that I know where the published module versus example apps live.
2. As a coding agent, I want prerequisites listed (Node/pnpm, Rust, cargo-ndk, Xcode/NDK as relevant), so that I do not invent alternate toolchains.
3. As a coding agent, I want to know that UniFFI bindings are regenerated via bindgen scripts and checked with `bindgen:check`, so that I do not hand-edit generated Swift/Kotlin FFI dumps.
4. As a coding agent, I want to know native `.so` / xcframework outputs are host-dependent and release-CI trusted, so that I do not commit local artifact drift.
5. As a coding agent, I want canonical commands (`pnpm check`, `pnpm verify`, `cargo test --workspace`, acceptance and native test entry points), so that I validate the same gates as CI.
6. As a coding agent, I want to know when real-device E2E is mandatory, so that I do not claim release readiness from unit tests alone.
7. As a human contributor, I want the agent guide to link or defer to README / Testing / Releasing for depth, so that AGENTS.md stays short.
8. As a maintainer, I want AGENTS.md to use CONTEXT.md glossary terms, so that agents speak Relying Party / Ceremony language consistently.
9. As a maintainer, I want the guide to warn against mutating lockfiles or skipping hooks unless asked, so that agents follow repo norms.
10. As a maintainer, I want updates to AGENTS.md whenever canonical scripts rename, so that the guide does not go stale (called out in Further Notes).

## Implementation Decisions

- Create root `AGENTS.md` only (no requirement for `CLAUDE.md` unless desired as a stub pointing at AGENTS.md).
- Cover: monorepo layout (`packages/module`, `crates/*`, `apps/*`, `scripts/`, `tooling/*`); package manager/engines; Rust/UniFFI/bindgen; native artifact policy; verify matrix; example-backend demo caveats; pointer to `CONTEXT.md`.
- Do not paste entire CI YAML; reference scripts by name.
- Do not include secrets, tokens, or demo fingerprint values beyond telling agents where trust env vars are documented.
- Keep the file maintainable: prefer bullets and command names over prose essays.

## Testing Decisions

- Documentation-only change; no automated test required beyond optional link/path sanity if the repo already checks markdown.
- Manually confirm listed commands match root `package.json` and Testing docs at authoring time.
- Prior art: README Development / Testing sections; `apps/docs` Testing and Releasing pages.

## Out of Scope

- Rewriting human-oriented README tutorials.
- Adding editor-specific configs.
- Changing CI.
- Documenting every Expo consumer app pattern.

## Further Notes

Audit finding 10. When package scripts or release gates change, update AGENTS.md in the same change set. This spec does not include the direction spikes (browser WebAuthn, durable server adapter, security keys).
