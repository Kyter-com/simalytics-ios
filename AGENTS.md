# Agent Notes

## App Store Connect CLI

Use the Homebrew `asc` binary for App Store Connect automation:

```sh
/opt/homebrew/bin/asc
```

This repo uses Xcode Cloud for archive, upload, and TestFlight distribution. Do not run local `asc publish testflight` for normal releases. The agent should only update local version/build settings, push to the configured branch, and then use ASC commands for metadata or build notes after Xcode Cloud has produced the build.

For local ASC credentials, source the appropriate environment file outside this public repo. Some local env files may use an older private-key path variable name; map it to the Homebrew CLI name before running `asc`:

```sh
set -a
source /path/to/private/env
set +a

export ASC_PRIVATE_KEY_PATH="$ASC_KEY_PATH"
export ASC_BYPASS_KEYCHAIN=1
```

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

