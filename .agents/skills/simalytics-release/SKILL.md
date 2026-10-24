---
name: simalytics-release
description: Use when shipping a Simalytics App Store release — bumping the version, writing release notes and App Store metadata, refreshing screenshots, pushing to main for Xcode Cloud, and staging, submitting, or swapping the build in App Store Connect with the asc CLI. Triggers on release, ship, new version, submit for review, cut a build, push to main for Xcode Cloud.
---

# Simalytics Release

## The rule

**The release commit is the last commit on `main`, and it goes up in one push.**
Every push to `main` starts an Xcode Cloud build, and the Cloud run number becomes
the build number. So everything that ships lands *before* that push: code,
changelog, release notes, App Store metadata, screenshots, and the version bump.
After the push, only App Store Connect changes, never the repo. A later push means
another build, and a release commit that no longer matches the build in review.

No `Co-Authored-By` trailers on commits in this repo.

## 1. Verify the code

- Run the full `xcodebuild test` suite on an iOS 27 simulator, plus a Release build
  (`-configuration Release -destination 'generic/platform=iOS Simulator'`) with zero
  Swift warnings. Use a `-derivedDataPath` outside the repo.
- If a test fails intermittently, find the race and fix it; don't rerun until it
  passes. Repeat suspect suites with `-test-iterations 15 -run-tests-until-failure`.

## 2. Screenshots, if the UI changed

Follow the `app-store-screenshots` skill and `marketing/app-store-screenshots/README.md`.

- Capture into a scratch directory, then copy in only the slides that changed.
- Compose with `uv run --no-project --with pillow python3 generate.py`. A different
  Pillow re-encodes unchanged slides; put their committed bytes back
  (`git checkout HEAD -- …`, or `git show HEAD:<old path> > <new path>` after a
  renumber with `git mv`).
- Run `asc screenshots validate --path output/iphone-6.9 --device-type IPHONE_67` and
  `--path output/ipad-13 --device-type IPAD_PRO_3GEN_129`. Look at every new slide on
  both devices before committing.

## 3. Version, notes, and metadata

1. Add a changeset (`npm run changeset`) for any user-facing work not covered yet.
   `minor` bumps X.(Y+1).0, and `patch` bumps X.Y.(Z+1).
2. In a fresh worktree run `npm ci --ignore-scripts` first, then `npm run version`.
   That updates `package.json`, `CHANGELOG.md`, and Xcode `MARKETING_VERSION`.
3. Copy the previous `marketing/app-store-metadata/version/<prev>/en-US.json` to
   `<new>/en-US.json`. Write a fresh, user-facing `whatsNew` (bullets, at most 4,000
   characters), and update `description` if features changed. Make
   `docs/next-release-notes.md` match `whatsNew` exactly.
4. Set `CURRENT_PROJECT_VERSION` (all build configurations) to the **next Xcode Cloud
   run number**, the latest run + 1:
   `asc xcode-cloud build-runs --workflow-id <workflow-id> --paginate --output json`.
   `npm run release:next-build` asks App Store Connect instead, which doesn't match
   Cloud's run numbering.
5. `npm run release:check` must print `Release files are consistent for <ver> (<build>)`.

## 4. Commit and push once

```sh
git commit -m "feat: …"                                   # the code, if not already committed
git commit -m "chore: release Simalytics <ver> (<build>)" # everything else
git fetch origin                                          # confirm origin/main hasn't moved
git push origin HEAD:main                                 # fast-forward; the PR-rule warning is bypassed for the owner
```

The release commit body says what shipped, which slides changed, and which Cloud
build it produces.

## 5. Wait for the build

Poll until the build is `VALID`. Filter by version, because a local TestFlight build
under another version can share the build number:

```sh
asc builds list --app <app-id> --version <ver> --build-number <build> --processing-state all --output json
```

## 6. App Store Connect

```sh
asc release stage --app <app-id> --version <ver> --build-id <BUILD_ID> \
  --copy-metadata-from <prev> --exclude-fields whatsNew --platform IOS --confirm
asc apps info edit --app <app-id> --version <ver> --platform IOS --locale en-US \
  --whats-new "<whatsNew from the JSON>" --description "<description from the JSON>"
```

- Check that every localization field (`asc localizations list --version <VERSION_ID>`)
  matches the committed JSON.
- Screenshots, per device:
  `asc screenshots upload --version-localization <LOC_ID> --path output/<device> --device-type <slug> --replace --confirm`
  (run `--dry-run` first).
- Reviewer notes: `asc review details-for-version --version-id <VERSION_ID>`. Staging
  copies the previous notes verbatim, so remove anything stale. The app needs a demo
  account: on `asc review details-update`, re-supply `--demo-account-required
  --demo-account-name … --demo-account-password …` together with `--notes`, reading
  the password with `details-get --include-sensitive` straight into a variable.
  Never print it.
- `asc validate --app <app-id> --version <ver> --platform IOS`. A lone info
  `privacy.publish_state.unverified` is expected.
- `asc review submit --app <app-id> --version <ver> --build-id <BUILD_ID> --confirm`,
  then confirm `WAITING_FOR_REVIEW` with `npm run release:status`.

## Swapping the build in review

When a new build has to replace the one in review (a fix, or a rewritten release commit):

1. Wait until the new build is `VALID`. The old one stays in review in the meantime.
2. `asc review submissions-cancel --id <SUBMISSION_ID> --confirm`. The state goes
   `CANCELING` → `COMPLETE` within about 20 seconds, and the version becomes editable.
3. `asc versions attach-build --version-id <VERSION_ID> --build-id <NEW_BUILD_ID>`, then
   `asc validate`, then `asc review submit … --build-id <NEW_BUILD_ID> --confirm`.
   Metadata and screenshots belong to the version and carry over.
4. If `review submit` times out on the client (`context deadline exceeded`), check
   `asc review submissions-get` before retrying; it often went through.

## Rewriting a pushed release commit

Avoid it. If it has to happen, for example to fix a commit message:

1. Rebuild the commits with the same trees. Bump the release commit and
   `CURRENT_PROJECT_VERSION` to the next Cloud run number, since the force push starts
   that run.
2. `git push --force-with-lease=main:<old sha> origin HEAD:main`.
3. Wait for the new build, then swap it into review as above, so the commit on `main`
   matches the build Apple reviews.
