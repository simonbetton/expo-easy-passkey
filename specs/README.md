# Specs

Self-contained implementation specs derived from the `/improve` audit at commit `5d4b288`. Each file is written for an executor with no prior conversation context.

Vocabulary follows root `CONTEXT.md` (Relying Party, Ceremony, Challenge, Passkey Credential, Demo Session, Demo Store).

## Recommended execution order

```text
05 ──► 02
  ├──► 03
  └──► 04

01, 06, 07, 08 — independent (any order)
```

- **05 before 02, 03, or 04** when those native contracts change: characterization tests make adapter and error-mapping work safe to execute.
- Specs **01**, **06**, **07**, and **08** do not depend on native adapter tests.

Direction items from the audit (browser WebAuthn ceremonies, durable server adapter, security-key registration) are intentionally not specified here.

## Status

| Spec                                               | Title                                  | Findings | Status |
| -------------------------------------------------- | -------------------------------------- | -------- | ------ |
| [01](01-config-plugin-domain-contract.md)          | Config plugin domain contract          | 1, 3     | done   |
| [02](02-cross-platform-timeout-contract.md)        | Cross-platform timeout contract        | 2        | done   |
| [03](03-robust-android-error-mapping.md)           | Robust Android error mapping           | 4        | done   |
| [04](04-ios-presentation-anchor-failure.md)        | iOS presentation anchor failure        | 5        | done   |
| [05](05-native-adapter-characterization-tests.md)  | Native adapter characterization tests  | 9        | done   |
| [06](06-example-backend-verification-hardening.md) | Example backend verification hardening | 6, 7     | done   |
| [07](07-ci-deduplication.md)                       | CI deduplication                       | 8        | done   |
| [08](08-agents-md.md)                              | AGENTS.md agent guide                  | 10       | done   |

Update the Status column when a spec is in progress, blocked, or done.
