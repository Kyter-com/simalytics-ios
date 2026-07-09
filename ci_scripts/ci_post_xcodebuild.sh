#!/bin/sh
# ci_scripts/ci_post_xcodebuild.sh
#
# Xcode Cloud runs this hook automatically after the `xcodebuild` step. We use
# it to upload debug symbols (dSYMs) + source context to Sentry for ARCHIVE
# builds, so crashes in TestFlight / the App Store are symbolicated.
#
# Why this lives here and NOT in the Xcode "Upload Debug Symbols to Sentry"
# build phase (which now only runs on local dev machines):
#   1. Timing: during an archive the build phase runs BEFORE `dsymutil`
#      generates the app dSYM, so it has nothing to upload. This hook runs
#      after the archive completes, when $CI_ARCHIVE_PATH/dSYMs is populated.
#   2. Install: installing sentry-cli via `curl https://sentry.io/get-cli | sh`
#      inside the build phase fails on Xcode Cloud because the installer falls
#      back to `sudo` and the runner has no interactive TTY
#      ("sudo: a password is required"). Here we download the binary directly,
#      which never needs sudo.
#
# Requirement (already configured on the workflow):
#   * SENTRY_AUTH_TOKEN - secret environment variable (org auth token, scope org:ci).
#
# This script NEVER fails the build: every fallible step warns and exits 0.

set -u

SENTRY_ORG="${SENTRY_ORG:-kyter}"
SENTRY_PROJECT="${SENTRY_PROJECT:-simalytics-ios}"
SENTRY_CLI_VERSION="${SENTRY_CLI_VERSION:-3.6.0}"

# --- Only act on archive builds ---------------------------------------------
# CI_ARCHIVE_PATH is populated by Xcode Cloud only for the archive action and
# points at the .xcarchive that contains the dSYMs.
if [ -z "${CI_ARCHIVE_PATH:-}" ]; then
  echo "ci_post_xcodebuild: no CI_ARCHIVE_PATH (not an archive build); skipping Sentry dSYM upload"
  exit 0
fi

# --- Require the auth token --------------------------------------------------
if [ -z "${SENTRY_AUTH_TOKEN:-}" ]; then
  echo "warning: sentry-cli - SENTRY_AUTH_TOKEN is not set on this workflow; skipping dSYM upload"
  exit 0
fi

# --- Locate the dSYMs --------------------------------------------------------
if [ -d "$CI_ARCHIVE_PATH/dSYMs" ]; then
  DSYM_PATH="$CI_ARCHIVE_PATH/dSYMs"
else
  DSYM_PATH="$CI_ARCHIVE_PATH"
fi

# --- Find or install sentry-cli (no sudo) ------------------------------------
# Xcode Cloud does not pre-install sentry-cli. Download the prebuilt universal
# macOS binary directly and run it by absolute path. This avoids the get-cli
# installer's sudo fallback, which cannot work on the TTY-less Cloud runner.
if command -v sentry-cli >/dev/null 2>&1; then
  SENTRY_CLI_BIN="$(command -v sentry-cli)"
else
  DEST_DIR="${CI_DERIVED_DATA_PATH:-${TMPDIR:-/tmp}}"
  SENTRY_CLI_BIN="$DEST_DIR/sentry-cli"
  DOWNLOAD_URL="https://downloads.sentry-cdn.com/sentry-cli/${SENTRY_CLI_VERSION}/sentry-cli-Darwin-universal"
  echo "ci_post_xcodebuild: downloading sentry-cli ${SENTRY_CLI_VERSION}"
  if ! curl -fSL --retry 3 -o "$SENTRY_CLI_BIN" "$DOWNLOAD_URL"; then
    echo "warning: sentry-cli - download failed ($DOWNLOAD_URL); skipping dSYM upload"
    exit 0
  fi
  if ! chmod +x "$SENTRY_CLI_BIN"; then
    echo "warning: sentry-cli - could not make binary executable; skipping dSYM upload"
    exit 0
  fi
fi

# --- Upload dSYMs + source context ------------------------------------------
# sentry-cli reads SENTRY_AUTH_TOKEN / SENTRY_ORG / SENTRY_PROJECT from the
# environment, so no .sentryclirc (gitignored, absent on the runner) is needed.
export SENTRY_ORG
export SENTRY_PROJECT
export SENTRY_AUTH_TOKEN

echo "ci_post_xcodebuild: uploading dSYMs from '$DSYM_PATH' to $SENTRY_ORG/$SENTRY_PROJECT"
if "$SENTRY_CLI_BIN" debug-files upload --include-sources "$DSYM_PATH"; then
  echo "ci_post_xcodebuild: sentry-cli dSYM upload complete"
else
  status=$?
  echo "warning: sentry-cli - dSYM upload failed (exit $status); not failing the build"
fi

exit 0
