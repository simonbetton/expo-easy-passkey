# Spec 03 — Robust Android error mapping

## Problem Statement

Android ceremony failures are mapped to stable `PasskeyError` codes that apps are documented to switch on (`ERR_PASSKEY_NO_CREDENTIAL`, `ERR_PASSKEY_INVALID_CREDENTIAL`, `ERR_PASSKEY_CANCELED`, `ERR_PASSKEY_NATIVE`). The mapper currently classifies some Credential Manager failures by Java `simpleName` string equality. Under release R8/ProGuard, those class names can be renamed unless kept, and consumer ProGuard rules today keep JNA/UniFFI classes, not necessarily androidx.credentials exception type names. Apps can therefore see generic `ERR_PASSKEY_NATIVE` in release builds for failures that debug builds classify correctly, breaking cancellation and “no credential” UX branches.

## Solution

Classify Credential Manager failures with typed `is` checks against the real androidx.credentials exception classes (and documented subclasses), so mapping survives minification. Keep public error codes and messages stable. Cover the mapper with unit tests that throw the real library exception types rather than local classes that only share a simple name.

## User Stories

1. As an app developer, I want `ERR_PASSKEY_CANCELED` when the user dismisses the Credential Manager sheet in release builds, so that I can treat cancellation as non-fatal.
2. As an app developer, I want `ERR_PASSKEY_NO_CREDENTIAL` when no matching Passkey Credential is available, so that I can prompt registration.
3. As an app developer, I want `ERR_PASSKEY_INVALID_CREDENTIAL` for DOM/public-key credential response failures the platform reports that way, so that my error handling matches the API docs.
4. As an app developer, I want unknown Credential Manager failures to remain `ERR_PASSKEY_NATIVE`, so that unexpected errors stay distinguishable.
5. As a maintainer, I want mapping based on type identity rather than `simpleName`, so that R8 renaming cannot silently change codes.
6. As a maintainer, I want unit tests to construct real androidx.credentials exception instances where practical, so that the suite proves the production classifier.
7. As a maintainer, I want create and get ceremony paths to share the same mapping helper, so that registration and authentication stay consistent.
8. As a documentation reader, I want existing API error-code guidance to remain valid after the fix, so that docs do not need a breaking change.
9. As an app developer on debug builds, I want the same codes as release builds for the same failure classes, so that local testing predicts production.
10. As a maintainer, I want ProGuard consumer rules updated only if still required after typed checks, so that we do not rely on keep-rules as the primary fix.

## Implementation Decisions

- Replace string `simpleName` branching in the Credential Manager error mapper with Kotlin type checks against androidx.credentials exception types used by create/get cancellation and no-credential/DOM failure paths.
- Preserve existing cancellation mapping that already uses typed cancellation exceptions where present; extend the same pattern to the remaining cases currently keyed by name.
- Keep the public error code set unchanged.
- Prefer importing and testing real library exception types. If a type cannot be constructed in unit tests, document why and use the closest constructible subclass that production catching would still match.
- Do not change iOS error mapping in this spec.
- Prefer Spec 05’s adapter characterization seam if broader ceremony adapter refactor is needed; the mapper function itself is already a testable seam.

## Testing Decisions

- Good tests assert which `Passkey*` exception (and thus error code) is produced for a given thrown type; they do not assert string class names.
- Update the existing Android unit test that currently defines local classes sharing production simple names so it cannot give a false pass after the fix.
- Cover cancellation, no-credential, DOM/invalid credential, and fallback native paths for both create and get where applicable.
- Prior art: `PasskeyRequestMapperTest` error-mapping cases.

## Out of Scope

- Changing the public TypeScript error code enum or documented app-facing switch cases.
- iOS `ASAuthorizationError` mapping.
- Broader Credential Manager request/response mapping changes unrelated to errors.
- Guaranteeing every OEM-specific wrapper exception maps to a specific code beyond what androidx types allow.

## Further Notes

Audit finding 4. Typed checks are the primary fix; keep-rules alone are insufficient and easy to forget. Spec 05 improves confidence for adapter-level integration but is not a substitute for fixing the mapper’s classification mechanism.
