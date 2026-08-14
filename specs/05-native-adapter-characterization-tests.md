# Spec 05 — Native adapter characterization tests

## Problem Statement

Native ceremony adapters own cancellation mapping, credential response conversion, user-verification application, excluded-credential handling, and platform controller interaction. CI native tests today exercise request parsing, encoding, and iOS registration policy—not the adapters that call AuthenticationServices and Credential Manager. Regressions in those adapters therefore pass CI until manual device E2E. Specs that change timeout documentation touch points, Android error mapping, or iOS presentation anchors become safer only if adapters can be tested without launching system passkey UI.

## Solution

Introduce one injectable platform-controller facade per native ceremony adapter (iOS and Android) at the highest practical seam, and add characterization tests for success, cancellation, unsupported/malformed responses, and key OS-version or policy branches. Keep real-device E2E as the final association and biometric check; do not replace it.

## User Stories

1. As a maintainer, I want adapter success paths tested with fake platform controllers, so that response mapping regressions fail in CI.
2. As a maintainer, I want user-cancellation paths tested, so that `ERR_PASSKEY_CANCELED` mapping cannot silently break.
3. As a maintainer, I want unsupported or unexpected credential response types to assert `ERR_PASSKEY_NATIVE` (or the platform’s existing equivalent), so that weird platform replies stay classified.
4. As a maintainer, I want malformed registration responses missing attestation objects to fail as they do in production mapping, so that incomplete native payloads are caught.
5. As a maintainer, I want iOS `excludeCredentials` on older OS versions to keep asserting the existing validation failure before UI, so that the iOS 17.4 gate remains covered at the adapter boundary.
6. As a maintainer, I want user-verification preferences applied on create/get requests in tests, so that `required` / `preferred` / `discouraged` wiring cannot drift unnoticed.
7. As a maintainer, I want Android create/get cancellation and mapped Credential Manager errors covered at the adapter or shared mapper seam, so that Spec 03 fixes stay locked in.
8. As a contributor changing native adapters, I want a documented fake/controller injection point, so that I do not need a device to verify mapping changes.
9. As a release maintainer, I want native CI scripts to run the new characterization suites, so that PRs cannot skip them.
10. As an app developer, I want no public API changes from this testing work, so that characterization is an internal quality improvement.
11. As a maintainer, I want the number of new seams minimized—one facade per platform adapter—so that production call sites stay readable.
12. As a maintainer, I want real-device E2E to remain mandatory before publish, so that association and biometrics are not falsely claimed as covered by unit tests.

## Implementation Decisions

- Add an injectable platform-controller (or authorization-controller / credential-manager) facade inside each ceremony adapter. Production code constructs the real platform implementation; tests inject fakes.
- Prefer the fewest new types that still let tests drive: perform requests, complete with a credential, complete with an error, and (on Android) return create/get responses or throw library exceptions.
- Do not mock at the Expo module bridge layer as the primary seam for adapter mapping; the adapters are the behavior under test. Module-level missing activity/presentation tests may be added opportunistically but are Spec 04/bridge concerns.
- Keep generated UniFFI bindings out of scope except as already used by encoding helpers.
- Wire new tests into the existing `test:native:ios` and `test:native:android` scripts / schemes so CI android-compile and ios-compile jobs pick them up.
- Avoid snapshotting full WebAuthn JSON blobs unless necessary; assert critical fields and error codes.
- Treat this spec as a prerequisite for Specs 02–04 when those change adapter behavior; pure documentation work in Spec 02 may proceed without it.

## Testing Decisions

- Good tests exercise external adapter behavior through the facade: inputs in, WebAuthn-shaped maps or typed exceptions out.
- Do not assert private continuation storage or UIKit layout details.
- Cover at least for iOS: registration success mapping; assertion success mapping including null userHandle; cancellation; unsupported credential type; missing attestation object; excludeCredentials on unsupported OS (if testable via facade/version gate).
- Cover at least for Android: create success JSON normalization; get success JSON normalization; cancellation exceptions; mapper integration for no-credential / DOM / fallback (may share Spec 03 tests).
- Prior art: `ExpoEasyPasskeyRegistrationPolicyTests`, `ExpoEasyPasskeyEncodingTests`, `PasskeyRequestMapperTest`, and the native test shell scripts.

## Out of Scope

- Automating real-device biometric E2E in CI.
- Browser WebAuthn tests.
- Rewriting TypeScript contract acceptance tests to call native adapters.
- Changing public TypeScript APIs to expose test hooks.

## Further Notes

Audit finding 9. This is the only intentionally new seam in the audit follow-up set. Execute before Specs 03 and 04 when those touch adapters; Spec 02 may remain docs-only.
