# Spec 01 — Config plugin domain contract

## Problem Statement

Installers and app developers configure the Expo Easy Passkey plugin with Relying Party domains so iOS Associated Domains receive `webcredentials:` entries. Two problems confuse that setup:

1. Marketing and package docs claim the config plugin configures “Android verified app links,” but the plugin only writes iOS Associated Domains. Android association comes from a hosted Digital Asset Links file and is not applied by the plugin.
2. The plugin prefixes any non-empty `domains` string with `webcredentials:` without validating that the value is a domain. A mistaken URL such as `https://example.com` becomes `webcredentials:https://example.com`, which ships a broken entitlement and fails association at ceremony time.

Developers follow the docs, copy a URL into `domains`, and then spend time debugging passkey association that never had a chance to work.

## Solution

Make the plugin reject invalid Relying Party domain inputs at config time, and make public docs describe only what the plugin actually does: iOS Associated Domains for passkey webcredentials. Android Digital Asset Links remain a hosted-file responsibility, documented separately as they already are on the Platforms page.

## User Stories

1. As an Expo app developer, I want the plugin docs to state that it configures iOS Associated Domains only, so that I do not expect Android intent filters or App Links from the plugin.
2. As an Expo app developer, I want the package README feature list to match Platforms documentation, so that I trust a single source of truth about the plugin boundary.
3. As an Expo app developer, I want `domains: ["example.com"]` to continue producing `webcredentials:example.com`, so that my existing correct config keeps working.
4. As an Expo app developer, I want `domains` entries that already start with `webcredentials:` to remain accepted and de-duplicated, so that advanced Associated Domains merges still work.
5. As an Expo app developer, I want `domains: ["https://example.com"]` to fail during prebuild with a clear error, so that I fix the Relying Party ID before a native build.
6. As an Expo app developer, I want domains that include a path (for example `example.com/login`) to be rejected, so that I cannot ship a non-domain RP ID into Associated Domains.
7. As an Expo app developer, I want domains that include a port (for example `example.com:443`) to be rejected, so that I cannot ship a URL-like value as an RP ID.
8. As an Expo app developer, I want empty or whitespace-only `domains` entries to be ignored or rejected consistently with existing empty-value filtering, so that accidental blanks do not create empty entitlements.
9. As a documentation reader, I want Install and Platforms pages to keep saying the plugin does not add Android intent filters, so that the corrected marketing bullets do not contradict the deep docs.
10. As a maintainer, I want plugin unit tests to cover valid domains, pre-prefixed webcredentials entries, and invalid URL/path/port inputs, so that the contract cannot regress quietly.
11. As a maintainer, I want the plugin error message to name the invalid value and state that Relying Party domains must be hostnames without scheme, path, or port, so that support questions are self-serve.
12. As an app developer using `associatedDomains` plugin options alongside `domains`, I want validation to apply to values that will be turned into webcredentials entries from `domains`, while preserving existing merge behavior with `config.ios.associatedDomains`, so that multi-source configuration remains predictable.

## Implementation Decisions

- Keep the plugin’s Android behavior unchanged: do not add intent filters, App Links, or Digital Asset Links generation.
- Validate each entry in `options.domains` before calling the webcredentials prefix helper. Reject values that contain `://`, `/`, `:`, `@`, or leading/trailing whitespace after trim that still look like URLs; accept bare hostnames (labels compatible with Relying Party ID expectations used elsewhere in the product).
- Allow values that already begin with `webcredentials:` when the remainder is a valid domain, matching today’s prefix-passthrough intent.
- Correct the inaccurate “Android verified app links” wording in the docs home features list and the package README feature bullets so they describe iOS Associated Domains (and, if needed, point readers to Platforms for Android Digital Asset Links).
- Do not change the Platforms or Install deep docs beyond ensuring they remain consistent; they already describe the correct plugin boundary.
- Keep de-duplication and merge order with existing `config.ios.associatedDomains` and `options.associatedDomains` as they work today, unless validation requires stripping invalid `domains` inputs only.
- Prefer failing prebuild loudly over silently skipping bad domains.

## Testing Decisions

- Good tests assert observable plugin output and thrown errors for given Expo config objects; they do not assert internal helper names.
- Extend the existing pure-function plugin suite that already exercises Associated Domains merges without Android intent-filter mutation.
- Cover at least: valid bare domain; already-prefixed `webcredentials:` domain; rejection of `https://…`; rejection of path and port forms; unchanged Android config when only domains are supplied.
- Prior art: the existing plugin unit test file next to the config plugin.

## Out of Scope

- Implementing Android App Links or Digital Asset Links generation inside the plugin.
- Changing server-side trust file generation in the example backend.
- Changing Rust or TypeScript Relying Party ID validation used at ceremony time (plugin validation is a config-time guardrail, not a replacement for ceremony validation).
- Renaming plugin options (`domains` vs `associatedDomains`).

## Further Notes

Audit findings 1 and 3. Platforms documentation is the correct reference for the intended plugin boundary. Align marketing copy to that page rather than expanding the plugin surface.
