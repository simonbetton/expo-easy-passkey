# Expo Easy Passkey

Expo Easy Passkey is an installable Expo module for adding passkey support to Expo projects.

```ts
import {
  authenticateWithPasskey,
  createPasskey,
  getPasskeyAvailability,
} from "expo-easy-passkey";

const availability = getPasskeyAvailability();

const registration = await createPasskey(optionsFromServer);
const assertion = await authenticateWithPasskey(optionsFromServer);
```

The public API uses task-oriented Expo names while keeping WebAuthn-compatible JSON request and response shapes. Browser-style `create` and `get` aliases are also available for developers who prefer WebAuthn terminology.

## Install

```sh
pnpm add expo-easy-passkey
```

## Platform Setup

Configure the Expo plugin with the relying-party domains your app should use:

```json
{
  "plugins": [
    [
      "expo-easy-passkey",
      {
        "domains": ["example.com"]
      }
    ]
  ]
}
```

You must also host platform association files:

- iOS: `/.well-known/apple-app-site-association`
- Android: `/.well-known/assetlinks.json`

Expo Go is not supported because passkeys require custom native modules. Use a development build or production build. Web and SSR imports are safe for capability detection; ceremonies reject with `ERR_PASSKEY_UNSUPPORTED` until browser WebAuthn support is added.

## Run the Example App

The example app calls `apps/example-backend` for registration and authentication options, then posts native ceremony responses back for verification. By default it uses the hosted demo at `https://expo-easy-passkey-example-backend.vercel.app` — you do not need a local backend for that path:

```sh
pnpm --filter @repo/example run android
pnpm --filter @repo/example run ios
```

On Android emulators, sign in with a Google account before running passkey ceremonies. Credential Manager needs that account (or another passkey-capable password manager) to create and assert passkeys; without it you typically get `No create options available`. Also set a screen lock on the emulator (PIN/pattern/password).

To run the backend locally instead, expose it over HTTPS with a tunnel such as ngrok, Tailscale Funnel, or Cloudflare Tunnel. Native passkey ceremonies require an HTTPS relying-party origin; `localhost` cannot be the RP ID. Then:

1. Start the backend with `pnpm --filter @repo/example-backend vercel:dev`.
2. Point a tunnel at that local port and set `EXPO_PUBLIC_PASSKEY_API_BASE_URL` to the tunnel HTTPS URL.
3. Keep `PASSKEY_RP_ID` / `PASSKEY_ORIGIN` (and the app plugin `domains`) on an associated domain you control, not the tunnel hostname, unless that hostname is also registered for Associated Domains / Digital Asset Links.

Before running native passkey ceremonies against your own domain, replace the committed demo values with values you control:

1. Set `apps/example/app.json` `expo.ios.appleTeamId` to your Apple Team ID.
2. Set `expo.ios.bundleIdentifier` to a bundle ID registered to that team.
3. Set the plugin `domains` entry to your relying-party domain, for example `login.example.com`.
4. Deploy `apps/example-backend` on that domain (or tunnel to it) with matching `PASSKEY_RP_ID` and `PASSKEY_ORIGIN` values.
5. Set the backend trust env vars so it serves `/.well-known/apple-app-site-association` and `/.well-known/assetlinks.json` for the installed app build. Include every trusted Android signing fingerprint in `ANDROID_SHA256_CERT_FINGERPRINTS`; the backend derives the exact Credential Manager APK-key-hash origins used for verification.
6. Set `EXPO_PUBLIC_PASSKEY_API_BASE_URL` for `apps/example` if the backend is not hosted at the default demo URL.

The backend example is API-only ElysiaJS and can deploy to Vercel, but its demo store is in memory. It is not durable across cold starts, multiple instances, or redeploys.

The project is a pnpm monorepo with:

- `packages/module` for the released `expo-easy-passkey` package: public TypeScript API, Expo native module bridge, and config plugin.
- `crates/passkey-core` for portable WebAuthn modeling and deterministic helpers.
- `crates/passkey-ffi` for UniFFI bindings consumed by Swift and Kotlin.
- `apps/example` for a working Expo demo.
- `apps/example-backend` for a Vercel-compatible ElysiaJS passkey backend example.
- `apps/docs` for the Fumadocs documentation site.
- `tooling/*` for shared repository configuration.

The native passkey ceremonies use platform authenticators: iOS AuthenticationServices and Android Credential Manager. Rust is used for spec-sensitive modeling, conversion, validation, and shared fixtures, not for app-managed private-key storage.

## Development

Native artifact builds need a Rust toolchain plus platform tooling:

- **Rust and Cargo:** install via [rustup](https://rustup.rs/) so `cargo`, `rustc`, and `rustup` are on your `PATH`.

- **Android:** [cargo-ndk](https://github.com/bbqsrc/cargo-ndk) and an Android NDK (`ANDROID_NDK_HOME`). CI uses `cargo-ndk` 4.1.2 and NDK r27c.

  ```sh
  cargo install cargo-ndk --version 4.1.2 --locked
  ```

- **Apple (macOS):** Xcode (`xcodebuild`, `lipo`) for the iOS xcframework

```sh
pnpm install
pnpm bindgen
pnpm build:rust-artifacts
pnpm check
pnpm build
cargo test --workspace
```

`pnpm install` installs lefthook. The pre-push hook runs `pnpm verify`, which mirrors the CI verify gate.

Run `pnpm bindgen:check` after changing `crates/passkey-ffi` to regenerate Swift/Kotlin UniFFI bindings and fail if committed bindings drift. Run `pnpm build:rust-artifacts` (macOS for the full matrix, or `android` / `apple` alone) before local native builds — that script fails fast if `cargo-ndk` is missing when building Android. The generated Android libraries, Apple xcframework, and artifact metadata are ignored because native outputs are not bit-reproducible across hosts. Release CI rebuilds artifacts from the release commit, smoke-tests the packed package against those trusted outputs, and stages only those outputs into the published package with release evidence.

## Testing

The test suite covers:

- Rust core validation and ceremony vectors.
- UniFFI exported helper functions and native runtime wiring.
- TypeScript option mapping, response validation, aliases, and error wrapping.
- Expo module bridge wiring.
- Native request and response mapping.

Manual real-device E2E is still required before release because platform passkey UI depends on OS accounts, app signing, associated domains, Digital Asset Links, and user verification. Maintainers should follow the acceptance plan in `Testing` and the Release evidence checklist in `Releasing` so contract, native artifact, web import, and device checks all block publication together.
