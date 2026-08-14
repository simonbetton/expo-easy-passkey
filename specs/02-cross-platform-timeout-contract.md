# Spec 02 — Cross-platform timeout contract

## Problem Statement

Public registration and authentication options include an optional `timeout` field in milliseconds. Android forwards that value into Credential Manager JSON, so it can affect native ceremony timing. iOS parses and stores `timeout` on the native request objects but never applies it to AuthenticationServices requests. Callers who set `timeout` therefore get different behavior by platform with no documented contract. Rejecting `timeout` on iOS would also break common Relying Party payloads (for example servers that always emit WebAuthn `timeout`), so a hard platform reject is the wrong product fix.

## Solution

Treat `timeout` as the WebAuthn hint it is: keep accepting it on every platform entry path, keep forwarding it to Android Credential Manager, keep ignoring it on iOS AuthenticationServices, and document that per-platform behavior in the public TypeScript types and Platforms documentation so app developers know what to expect.

## User Stories

1. As an app developer, I want to pass a standard WebAuthn `timeout` from my Relying Party without platform-specific branching, so that one options payload works on iOS and Android.
2. As an app developer on Android, I want `timeout` to continue being included in the Credential Manager public-key JSON, so that existing Android timing behavior does not regress.
3. As an app developer on iOS, I want ceremonies with `timeout` set to keep succeeding, so that I am not forced to strip fields my server always sends.
4. As an app developer reading the API types, I want `timeout` TSDoc to say Android may honor the hint and iOS AuthenticationServices ignores it, so that I do not assume a cross-platform timer.
5. As an app developer reading Platforms docs, I want an explicit note under iOS or shared options behavior about `timeout`, so that troubleshooting does not blame association when timing differs.
6. As a maintainer, I want TypeScript tests to keep asserting that `timeout` is forwarded on the native create/get request shape, so that the public mapping cannot drop the field.
7. As a maintainer, I want Android request-mapper tests to keep asserting `timeout` appears in Credential Manager JSON when provided, so that Android behavior stays characterized.
8. As a documentation consumer, I want the wording to call `timeout` a hint rather than a guaranteed cancel deadline, so that I do not depend on OS-enforced cancellation that platforms do not promise.
9. As an app developer omitting `timeout`, I want unchanged behavior on both platforms, so that optional field absence remains safe.
10. As a maintainer, I want this change to avoid rejecting `timeout` with `ERR_PASSKEY_VALIDATION` on iOS, so that standard simplewebauthn-style options keep working.

## Implementation Decisions

- Do not reject `timeout` on iOS at the TypeScript validation layer or in the iOS registration policy.
- Do not invent an unofficial iOS timer around AuthenticationServices solely to “honor” `timeout`; Apple’s API surface for platform passkeys does not expose an equivalent consumer timeout in the current adapter.
- Keep Android serialization of `timeout` into Credential Manager JSON when present.
- Document the asymmetry in public option type comments and in Platforms documentation near other iOS registration policy notes.
- Prefer short, precise wording: accepted everywhere; forwarded on Android; ignored on iOS AuthenticationServices; not a reliable cross-platform cancel guarantee.
- Prefer landing characterization coverage from Spec 05 before changing adapter code if any iOS adapter touch is needed; for this spec, documentation plus existing mapper/TS assertions may be sufficient if no behavior change is required.

## Testing Decisions

- Good tests assert the public native request mapping and Android JSON output, not private iOS property storage of unused fields.
- Reuse the TypeScript public API tests that already expect `timeout` on forwarded create/get requests.
- Reuse or extend Android request-mapper tests if `timeout` is not already asserted in Credential Manager JSON.
- Do not add a flaky wall-clock test that waits for native UI cancellation.
- Prior art: module Jest tests that mock the native bridge; Android `PasskeyRequestMapperTest`.

## Out of Scope

- Implementing a custom iOS ceremony cancel timer.
- Changing server Challenge TTL or example-backend `timeout` values.
- Web/browser ceremony timeout behavior (web remains unsupported).
- Rejecting or stripping `timeout` on any platform.

## Further Notes

Audit finding 2. Spec 05 (native adapter characterization) should precede any adapter refactor that claims to “apply” timeout. This spec’s intended outcome is an honest documented contract, not a fake cross-platform timer.
