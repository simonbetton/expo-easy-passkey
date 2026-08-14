# Spec 04 — iOS presentation anchor failure

## Problem Statement

iOS ceremonies need a presentation anchor for AuthenticationServices. When the Expo module can find a view controller but that controller has no window, the adapter falls back to a freshly created `UIWindow()`. That detached window is not a valid place to present the system passkey UI. Instead of failing with the existing `ERR_PASSKEY_PRESENTATION_CONTEXT` code that apps already handle as “cannot run ceremony here,” the ceremony may attempt presentation in a broken context and produce confusing native failures.

## Solution

If the current view controller has no usable window, throw the existing presentation-context exception (`ERR_PASSKEY_PRESENTATION_CONTEXT`) and do not create a placeholder `UIWindow()`. Keep successful presentation when a real window exists.

## User Stories

1. As an app developer, I want missing presentation context to surface as `ERR_PASSKEY_PRESENTATION_CONTEXT`, so that I can show another sign-in method.
2. As an app developer, I want ceremonies that have a real key window / view-controller window to keep working unchanged, so that the happy path does not regress.
3. As an app developer reading API docs, I want `ERR_PASSKEY_PRESENTATION_CONTEXT` to remain listed with unsupported/activity failures, so that my error handling stays valid.
4. As a maintainer, I want the module to stop allocating a blank `UIWindow()` as a presentation fallback, so that we never present on a detached window.
5. As a maintainer, I want tests or characterization coverage for the missing-window path, so that the fallback cannot return silently.
6. As an app developer presenting from a normal foreground Expo screen, I want no new permission or lifecycle requirements, so that the fix is a failure-mode change only.
7. As a user of the example app, I want registration and authentication on a typical simulator/device foreground screen to keep succeeding, so that demos still work.
8. As a maintainer, I want Android missing-activity behavior (`ERR_PASSKEY_ACTIVITY`) left alone, so that this remains an iOS presentation-context fix.
9. As an app developer during navigation transitions, I want a clear presentation-context error rather than a hung or opaque native error when no window is ready, so that retries after the UI settles are obvious.
10. As a maintainer, I want the existing `PasskeyMissingPresentationContextException` to remain the thrown type for this case, so that bridge error codes stay stable.

## Implementation Decisions

- In the iOS module’s ceremony-adapter factory, require a non-nil window from the current view controller (or an equivalently documented valid presentation anchor already used by the app). If absent, throw `PasskeyMissingPresentationContextException`.
- Remove the `UIWindow()` fallback.
- Do not change the exception code string `ERR_PASSKEY_PRESENTATION_CONTEXT`.
- Prefer Spec 05’s injectable presentation/controller seam for automated coverage of the missing-window branch; if Spec 05 is not yet landed, add the smallest module-level test the existing XCTest harness allows, or land Spec 05 first per the dependency order.
- Do not change AuthenticationServices delegate error mapping in this spec.

## Testing Decisions

- Good tests assert the error code/exception for a missing window and assert that a provided window is used when present; they do not launch real biometric UI.
- Prefer the Spec 05 adapter/module facade if available; otherwise extend iOS unit tests with a controllable presentation-anchor provider.
- Prior art: iOS XCTest suites for encoding and registration policy; Spec 05 defines the preferred seam for ceremony presentation.

## Out of Scope

- Android activity resolution.
- Redesigning how Expo supplies the current view controller.
- Changing canceled / no-credential / invalid-credential mapping.
- Adding a retry API for presentation-context failures.

## Further Notes

Audit finding 5. The exception type already exists; this spec makes the failure mode honest. Execute Spec 05 first when possible so the missing-window branch is characterized without device UI.
