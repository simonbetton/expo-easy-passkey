# Expo Easy Passkey

Expo Easy Passkey adds native passkey registration and sign-in to Expo apps.

```ts
import {
  authenticateWithPasskey,
  createPasskey,
  getPasskeyAvailability,
} from "expo-easy-passkey";
```

## Install

```sh
pnpm add expo-easy-passkey
```

Configure the same package as an Expo config plugin:

```json
{
  "expo": {
    "plugins": [
      [
        "expo-easy-passkey",
        {
          "domains": ["example.com"]
        }
      ]
    ]
  }
}
```

Expo Go cannot load custom native modules, so use a development build or production build.

## What the package includes

- Public TypeScript APIs for passkey registration, authentication, availability checks, and typed errors.
- Native iOS AuthenticationServices and Android Credential Manager bridge code.
- Rust-backed UniFFI helper libraries for shared WebAuthn normalization and validation.
- An Expo config plugin for Associated Domains and Android verified app links.
- Generated native binding files used by the runtime helper layer and repository validation.

Your relying-party server still creates challenges, verifies responses, stores credential public keys, and protects against replay.

See the full documentation at https://github.com/simonbetton/expo-easy-passkey.
