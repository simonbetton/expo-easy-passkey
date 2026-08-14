# Spec 06 — Example backend verification hardening

## Problem Statement

The example Relying Party backend is a demo, but docs describe in-process overlapping ceremonies and single-use verification as safe within one process, and the hosted demo is a copy-paste template. Two gaps undermine that claim:

1. Verification awaits the WebAuthn verifier while the Ceremony remains pending, then persists Passkey Credential side effects (for example registration saves) before consuming the ceremony. Two concurrent verifies of the same ceremony can both verify and write; only one later consume succeeds. The concurrent test asserts one fulfill and one reject without asserting a single credential write.
2. Public verify routes accept unbounded, untyped bodies (`t.Unknown()`), the Vercel adapter buffers the entire request body with no size ceiling, CORS is open (`*`), and error responses return raw exception messages. Unauthenticated clients can force large allocations and receive dependency-specific parse details.

## Solution

Make Demo Store ceremony consumption atomic with verification effects for the in-memory demo: claim a ceremony before side effects, ensure at most one successful registration/authentication mutation per ceremony, and tighten HTTP input handling with a body-size ceiling, typed verification request schemas, and stable public error messages. Keep the Demo Store non-durable across instances; do not turn the example into a production IdP.

## User Stories

1. As a demo operator, I want two concurrent registration verifies for one ceremony to result in at most one stored Passkey Credential, so that single-use Challenges stay meaningful in-process.
2. As a demo operator, I want two concurrent authentication verifies for one ceremony to update the sign counter at most once, so that replay within one process cannot double-apply.
3. As a developer reading Server docs, I want the in-process safety claim to match actual Demo Store behavior, so that I am not misled when studying the example.
4. As a client of the example API, I want oversized POST bodies rejected before full buffering when practical, so that the demo process resists trivial memory exhaustion.
5. As a client sending a well-formed `{ ceremonyId, response }` body, I want verification to keep succeeding, so that the example app flow does not break.
6. As a client sending a malformed body, I want a stable generic error payload without stack or library internals, so that the public API does not leak implementation details.
7. As a maintainer, I want typed schemas for registration and authentication verify bodies, so that unknown shapes fail validation early.
8. As a maintainer, I want tests that assert exactly one credential write under concurrent registration verify, so that the race cannot return unnoticed.
9. As a maintainer, I want failed cryptographic verification to leave the ceremony available for a legitimate retry only when that matches the chosen claim/rollback design, so that transient verifier failures remain intentional and documented.
10. As an app developer copying the example, I want comments or docs to still say production needs a shared durable store with atomic conditional consumption, so that hardening the demo does not imply production readiness.
11. As a Demo Session consumer, I want successful authentication to keep returning the placeholder session shape, so that the example app UI keeps working.
12. As a maintainer, I want OPTIONS/CORS behavior for the example to remain usable from the Expo app, so that browser-like clients are not accidentally locked out of the demo.

## Implementation Decisions

- Introduce an atomic claim (pending → processing/consumed) in the Demo Store before lasting side effects. Preferred shape: claim/consume that can only succeed once per ceremony ID; run verification against the claimed Challenge; on success commit credential writes; on verification failure either restore pending for retry or leave consumed—pick one policy and document it in Server docs / code comments. Prefer “failed verification does not consume” only if it cannot re-open the double-write race; otherwise claim-first with explicit rollback of claim on verifier failure.
- Extend concurrent tests to assert store credential cardinality / counter updates, not only Promise settlement counts.
- Add a maximum request body size in the Vercel Node adapter before concatenating chunks; reject with HTTP 413 or 400 and a stable message.
- Replace `t.Unknown()` verify body schemas with constrained TypeBox/Elysia schemas for `ceremonyId` (string) and `response` (object with required WebAuthn JSON fields at a practical depth—enough to reject non-objects and missing keys, not a full CBOR validator).
- Map public errors to stable messages; log detailed errors server-side only if logging already exists or can be added minimally without new infrastructure.
- Do not remove `Access-Control-Allow-Origin: *` for the demo unless a documented reason appears; size/schema fixes are the priority.
- Do not add durable database persistence in this spec.

## Testing Decisions

- Good tests drive `createPasskeyService` / `createDemoStore` and HTTP `app.handle(Request)` / adapter body limits as external behavior.
- Add or extend concurrency tests proving a single Passkey Credential write for duplicate registration verifies.
- Add schema tests for missing `ceremonyId`, non-object response, and oversized bodies at the adapter or HTTP boundary.
- Prior art: `passkeys.test.ts`, `store.test.ts`, `config.test.ts`.

## Out of Scope

- Multi-instance or durable production storage.
- Real session issuance / auth cookies replacing the Demo Session placeholder.
- Changing association trust file generation.
- Hardening the published `expo-easy-passkey` npm package (this is example-backend only).

## Further Notes

Audit findings 6 and 7. This is example-backend risk, not a flaw in the released native module. Production adopters still need a shared durable store as Server docs already require.
