# Changesets

Use Changesets for user-facing release notes and version bumps.

```sh
npm run changeset
```

Write the changeset body as App Store-ready prose. The release script converts each note into a `•` bullet for App Store Connect.

Example:

```md
---
"@kyter/simalytics-ios": patch
---

Fixed grid title spacing so poster rows stay aligned.
```

Use `patch` for fixes and polish, `minor` for user-visible feature work, and `major` only for coordinated compatibility or data-model-breaking changes.

Run `npm run version` only during release prep. It consumes pending changesets,
updates both package manifests, syncs Xcode, and runs `npm run release:check`.
Do not hand-copy App Store version/build history into `CHANGELOG.md`; regenerate
`docs/apple-release-history.md` with `npm run release:backfill`. If a version was
distributed only through TestFlight, label that explicitly in the changelog.
