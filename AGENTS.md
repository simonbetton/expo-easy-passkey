# Agent guide

Use [CONTEXT.md](CONTEXT.md) for Relying Party, Ceremony, Challenge, Passkey Credential, Demo Session, and Demo Store.

Human tutorials live in [README.md](README.md), [Testing](apps/docs/content/docs/testing.mdx), and [Releasing](apps/docs/content/docs/releasing.mdx). Trust env vars for association files are documented on [Platforms](apps/docs/content/docs/platform.mdx) and [Server](apps/docs/content/docs/server.mdx).

## Layout

- `packages/module` — published `expo-easy-passkey` (TypeScript API, Expo native module, config plugin)
- `crates/passkey-core`, `crates/passkey-ffi` — Rust helpers and UniFFI bindings
- `apps/example`, `apps/example-backend`, `apps/docs` — demo app, demo Relying Party, docs
- `scripts/`, `tooling/` — verify, bindgen, native artifact, and shared config

## Toolchain

- Node `>=24`, pnpm `>=10` (`packageManager` in root `package.json`)
- Rust via rustup; CI pins `1.89.0`
- Android natives: `cargo-ndk` 4.1.2 and NDK r27c (`ANDROID_NDK_HOME`)
- Apple natives: Xcode (`xcodebuild`, `lipo`)

## Generated and host-dependent artifacts

- Regenerate UniFFI Swift/Kotlin with `pnpm bindgen`. Check drift with `pnpm bindgen:check`.
- Do not hand-edit `packages/module/ios/generated` or `packages/module/android/src/main/java/expo/modules/easypasskey/generated`.
- Native `.so` / xcframework outputs are host-dependent and gitignored. Release CI rebuilds and stages trusted artifacts. Do not commit local native drift.

## Verify

Canonical gates (same names CI uses):

- `pnpm check` — lint, format, typecheck, JS tests (includes acceptance Jest files)
- `pnpm verify` — Rust fmt/clippy, `bindgen:check`, `check`, `build`
- `cargo test --workspace`
- `pnpm test:acceptance` — local acceptance subset only; CI does not re-run it
- `pnpm verify:release-acceptance` — inventory/wiring that acceptance stays release-blocking
- `pnpm test:native:android` / `pnpm test:native:ios` — native characterization after `expo prebuild`

Do not mutate lockfiles or skip git hooks unless the user asks.

## Demo backend

`apps/example-backend` is an in-process Demo Store. It is not durable across instances. Production needs a shared store with atomic conditional Ceremony consumption.

## Device E2E

Unit and characterization tests do not cover association files, signing, system passkey UI, or biometrics. Real-device E2E is required before publish. See Testing and Releasing.
