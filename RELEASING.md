# Releasing Expo Easy Passkey

The full release process is documented in `apps/docs/content/docs/releasing.mdx`.

Quick path:

```sh
pnpm changeset
pnpm build:rust-artifacts
pnpm verify
pnpm bindgen:check
pnpm --filter expo-easy-passkey prepublishOnly
pnpm --filter expo-easy-passkey pack --dry-run
```

Release automation runs from GitHub Actions on `main`. Trusted jobs rebuild every supported Android ABI and Apple device/simulator slice from the release commit and locked Cargo graph, upload those outputs as immutable workflow artifacts with toolchain/lockfile/checksum metadata, smoke-test the packed package against those exact artifacts, detect drift between committed binaries and trusted outputs, and stage only the trusted natives into the publication job. npm provenance (`publishConfig.provenance`) plus `release-evidence.json` ties the published package to source commit, lockfile digest, toolchain, target inventory, and checksums.

Required repository setup:

- `NPM_TOKEN` GitHub Actions secret.
- `CHANGESETS_TOKEN` GitHub Actions secret, if repository settings do not allow `GITHUB_TOKEN` to create pull requests. Use a fine-grained personal access token with read/write access to contents and pull requests for this repository.
- Workflow permissions for `contents: write`, `pull-requests: write`, and `id-token: write`.
- npm permissions to publish `expo-easy-passkey` with provenance.

Only `expo-easy-passkey` is published to npm. Internal workspaces and Rust crates are not published by this release process.
