# Release Workflow

Simalytics uses App Store Connect (`asc`) as the source of truth for Apple versions/builds and Changesets as the source of truth for upcoming changelog and release-note text.

## Tools

- Node/npm for Changesets release tooling.
- Homebrew `asc` at `/opt/homebrew/bin/asc` for App Store Connect.
- 1Password CLI (`op`) for injecting ASC credentials into the shell.

Keep ASC secrets in 1Password or a private local env file. Do not commit API key IDs, issuer IDs, private keys, private key paths, or private env filenames.

Preferred private env shape:

```sh
ASC_OP_ACCOUNT=<optional-account-domain>
ASC_OP_VAULT=<optional-vault-name>
ASC_OP_ITEM=<1password-item-id-or-name>
ASC_BYPASS_KEYCHAIN=1
```

The script reads `key_id`, `issuer_id`, and `credential` from that 1Password item, writes the private key to a temporary `0600` file for `asc`, and deletes it on exit.

The 1Password item must have fields labeled exactly `key_id`, `issuer_id`, and `credential`. `credential` should contain the App Store Connect `.p8` private key contents. Keep the actual item ID/name in a private env file or local shell history, not in git.

Run ASC-backed commands through `op run`:

```sh
op run --env-file <private-asc-env> -- npm run release:status
```

Or pass the item reference inline:

```sh
ASC_OP_ITEM=<1password-item-id-or-name> npm run release:status
```

Safe credential discovery for agents:

```sh
op item list --format json --long | node -e '<filter item titles/tags only; do not print fields>'
op item get <candidate-item> --format json | node -e '<print field labels/types only; do not print values>'
```

Never print `credential`, `key_id`, `issuer_id`, `.p8` contents, or private key paths in logs.

## Daily Development

For each user-facing change, add a changeset before merging or releasing:

```sh
npm run changeset
```

Use this syntax:

```md
---
"@kyter/simalytics-ios": patch
---

Fixed grid title spacing so poster rows stay aligned.
```

Keep commit messages conventional where practical, for example `feat:`, `fix:`, `perf:`, `refactor:`, and `chore:`. Changeset bodies should be user-facing and App Store-ready.

## Release Prep

1. Review pending notes:

```sh
npm run release:notes
```

2. Snapshot the App Store notes, consume changesets into `CHANGELOG.md`, bump `package.json`, and sync Xcode `MARKETING_VERSION`:

```sh
npm run version
```

This writes `docs/next-release-notes.md` before Changesets consumes the pending changesets, so the exact notes can still be applied after the Apple build finishes processing.
It also refreshes `package-lock.json`, syncs Xcode `MARKETING_VERSION`, and runs
the local release consistency check. `package.json`, the lockfile, the Xcode
marketing version, `CHANGELOG.md`, release notes, and canonical App Store
metadata must all identify the same version.

3. Ask ASC for the next configured Xcode Cloud workflow build number and apply
   it to Xcode:

```sh
op run --env-file <private-asc-env> -- npm run release:next-build -- --apply
```

4. Commit the release files and push to the branch configured in Xcode Cloud.

5. After the Xcode Cloud build exists in App Store Connect, update TestFlight and App Store notes from pending changesets or `docs/next-release-notes.md`:

```sh
op run --env-file <private-asc-env> -- npm run release:apply-notes -- --target both --confirm
```

Keep the canonical storefront copy in `marketing/app-store-metadata/` aligned
with the screenshots. Before applying copy changes, run `asc metadata plan` and
review the generated artifact; screenshots, age ratings, categories,
accessibility declarations, privacy labels, and copyright remain separate ASC
workflows.

Keep `marketing/app-store-privacy/privacy.json` aligned with the app, its
third-party SDK manifests, the Kyter API, and Simkl data flows. Use `asc web
privacy plan`, review the exact additions and removals, then run `apply` and the
separate explicit `publish` command. Confirm the final state with `privacy pull`.

Run the same consistency check independently with:

```sh
npm run release:check
```

6. Tag the exact git commit that produced the Apple build. If the processed
   Cloud build differs from the staged setting, pass its actual number with
   `--build-number`:

```sh
npm run release:tag -- --confirm
# npm run release:tag -- --build-number <cloud-build-number> --confirm
git push --tags
```

Tags use `simalytics-ios@<marketing-version>+<build-number>`.

## Backfill

When ASC credentials are active, generate correlated Apple release history:

```sh
op run --env-file <private-asc-env> -- npm run release:backfill
```

This rewrites `docs/apple-release-history.md`; do not edit that generated file by
hand. App Store version records and attached builds come from ASC. Exact release
tags and Xcode Cloud source commits provide authoritative git correlation, with
Xcode project snapshots used only as a historical fallback. Processed build
trains without an App Store version record are listed as TestFlight-only.
