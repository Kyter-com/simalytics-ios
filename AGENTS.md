# Agent Notes

## App Store Connect CLI

Use the Homebrew `asc` binary for App Store Connect automation:

```sh
/opt/homebrew/bin/asc
```

This repo uses Xcode Cloud for archive, upload, and TestFlight distribution. Do not run local `asc publish testflight` for normal releases. The agent should only update local version/build settings, push to the configured branch, and then use ASC commands for metadata or build notes after Xcode Cloud has produced the build.

For release scripts, prefer the 1Password item-backed auth flow instead of storing private key paths in repo-local files:

```sh
ASC_OP_ITEM=<1password-item-id-or-name> npm run release:status
```

The script reads `key_id`, `issuer_id`, and `credential` from the 1Password item, writes the private key to a temporary `0600` file for `asc`, and deletes it on exit.

To discover the right item, inspect only 1Password item metadata and field labels/types. Do not print field values.

```sh
op item list --format json --long
op item get <candidate-item> --format json
```

If calling `asc` directly, use a private environment outside this repo and never print credential values.

Do not commit API keys, issuer IDs, private key contents, local key paths, or private env filenames to this repo.

Useful commands:

```sh
/opt/homebrew/bin/asc auth status --output json --pretty
/opt/homebrew/bin/asc status --app <app-id-or-bundle-id> --include app,builds,testflight --output table
/opt/homebrew/bin/asc builds next-build-number --app <app-id> --version <version> --platform IOS --output json --pretty
/opt/homebrew/bin/asc apps info edit --app <app-id> --version <version> --platform IOS --locale en-US --whats-new "• Release note text"
/opt/homebrew/bin/asc builds test-notes update --build-id <build-id> --locale en-US --whats-new "• What to test text"
```

When using Xcode Cloud:

1. Check the next available build number in ASC.
2. Set `CURRENT_PROJECT_VERSION` to that number in the Xcode project.
3. Commit and push to the branch configured in Xcode Cloud.
4. Verify the Xcode Cloud run and wait for the App Store Connect build to exist.
5. Update TestFlight build notes on the Cloud-produced build.

## Release Tracking

ASC plus git plus Changesets are the release source of truth.

- Use `npm run changeset` for user-facing changes.
- Use `npm run version` to snapshot `docs/next-release-notes.md`, consume changesets into `CHANGELOG.md`, and sync Xcode `MARKETING_VERSION`.
- Use `ASC_OP_ITEM=<1password-item-id-or-name> npm run release:next-build -- --apply` to get the next build number from ASC and sync Xcode `CURRENT_PROJECT_VERSION`.
- Use `ASC_OP_ITEM=<1password-item-id-or-name> npm run release:backfill` to regenerate `docs/apple-release-history.md` from ASC and git.
- Keep Simalytics commits conventional where practical (`feat:`, `fix:`, `perf:`, `refactor:`, `chore:`).

## Observability (Sentry)

Crash reporting via Sentry, org `kyter`, project `simalytics-ios`. dSYMs upload automatically — no manual step in the normal release flow:

- **Xcode Cloud** archives run `ci_scripts/ci_post_xcodebuild.sh` (downloads `sentry-cli`, uploads `$CI_ARCHIVE_PATH/dSYMs` with `--include-sources`). It warns but never fails the build.
- **Local** archives use the Xcode "Upload Debug Symbols to Sentry" build phase, which is dev-machine-only and self-skips on Xcode Cloud (`CI_XCODE_CLOUD`).

`SENTRY_AUTH_TOKEN` must be an **org-`kyter`** auth token (scope `org:ci`):

- Xcode Cloud: set as a **secret** env var on the workflow via the App Store Connect UI — the ASC API cannot set Xcode Cloud env vars/secrets.
- Local dev: read from `.sentryclirc` (gitignored). Never commit tokens.
- If symbols stop appearing, check the archive's `ci_post_xcodebuild.log`. `error: Project not found` means the token is bound to the wrong Sentry org (not `kyter`).
