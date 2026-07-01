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

Expo Go is not supported because passkeys require custom native modules. Use a development build or production build.

## Run the Example App

The example app calls `apps/example-backend` for registration and authentication options, then posts native ceremony responses back for verification. The committed values target `expo-easy-passkey.vercel.app`. Before running native passkey ceremonies against your own domain, replace them with values you control:

1. Set `apps/example/app.json` `expo.ios.appleTeamId` to your Apple Team ID.
2. Set `expo.ios.bundleIdentifier` to a bundle ID registered to that team.
3. Set the plugin `domains` entry to your relying-party domain, for example `login.example.com`.
4. Start or deploy `apps/example-backend` on that domain with matching `PASSKEY_RP_ID` and `PASSKEY_ORIGIN` values.
5. Set the backend trust env vars so it serves `/.well-known/apple-app-site-association` and `/.well-known/assetlinks.json` for the installed app build.
6. Set `EXPO_PUBLIC_PASSKEY_API_BASE_URL` for `apps/example` if the backend is not hosted at the default demo URL.

Then rebuild the native app:

```sh
pnpm --filter @repo/example-backend vercel:dev
pnpm --filter @repo/example run android
pnpm --filter @repo/example run ios
```

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

```sh
pnpm install
pnpm bindgen
pnpm build:rust-artifacts
pnpm check
pnpm build
cargo test --workspace
```

`pnpm install` installs lefthook. The pre-push hook runs `pnpm verify`, which mirrors the CI verify gate.

Run `pnpm bindgen:check` after changing `crates/passkey-ffi` to regenerate Swift/Kotlin UniFFI bindings and fail if committed bindings drift. Run `pnpm build:rust-artifacts` from macOS before packaging a release so the npm package includes the iOS xcframework and Android shared libraries used by the UniFFI runtime.

## Testing

The test suite covers:

- Rust core validation and ceremony vectors.
- UniFFI exported helper functions and native runtime wiring.
- TypeScript option mapping, response validation, aliases, and error wrapping.
- Expo module bridge wiring.
- Native request and response mapping.

Manual real-device E2E is still required before release because platform passkey UI depends on OS accounts, app signing, associated domains, Digital Asset Links, and user verification.
