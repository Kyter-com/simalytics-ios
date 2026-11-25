# Simkl sign-in (AUTH V2, with AUTH V1 until it retires)

Simkl launched AUTH V2 on 2026-09-18 and expects AUTH V1 to stop working around
April 2027 (date not fixed; watch the
[migration guide](https://api.simkl.org/guides/migrating-v1-to-v2) and Simkl's
Discord `#api`). New sign-ins use V2. People signed in with V1 keep working
until they upgrade, which keeps their library when the same Simkl account
approves.

## Registrations

| | AUTH V1 | AUTH V2 |
|---|---|---|
| Simkl app | #49868 | #8275966, "Mobile, desktop & browser apps" (public client, no secret) |
| Client ID | `SimklClient.v1` | `SimklClient.v2` (also in 1Password: "Simkl API — Simalytics iOS (AUTH V2)") |
| Redirect | `simalytics://` (old builds only) | `simalytics://auth/simkl`; `http://127.0.0.1/auth/simkl` is registered for local end-to-end checks |
| Code exchange | `api.simalytics.kyter.com/oauth` (Worker holds the secret) | On device, PKCE S256, `POST https://api.simkl.com/oauth2/token` |
| Tokens | One long-lived token | 7-day access token + 180-day sliding, non-rotating refresh token |

Client IDs are public. Never commit an access token, a refresh token, or the
V1 client secret: Simkl revokes any it finds on GitHub, private repos included.

## How it fits together

- `SimklSession` (actor) is the only owner of the credential. Requests never
  carry a token: call sites mark them `request.simklAuth = .user`, and
  `prepare` attaches the current token, plus the client ID that matches it,
  as each one is sent. One refresh serves every request that hits the same
  expiry: a refresh kills the previous access token at once, so independent
  refreshes would cut each other off.
- On a 401 from Simkl the pipeline refreshes once and retries. A refused
  refresh (`invalid_grant`), or any 401 on a V1 token, moves to "reconnect
  required": the library stays, syncing stops, Lists, Up Next, Explore and
  Search show a Reconnect card, and Settings shows a Reconnect button.
  `user_token_required` is a missing header, never a reason to refresh.
- `Auth` (`@MainActor`, observable) mirrors the session for views:
  `hasAccount` (show the library) versus `isConnected` (network features and
  edits work).
- Syncs are keyed by `accountSessionID`, not the token, so a weekly refresh
  never cancels one. Signing out or replacing the library with another account
  changes it.
- Reconnecting compares Simkl `account.id`: the same account keeps the
  library; another account asks first; an unknown previous account means the
  library is cleared and resynced. V1 sign-ins record their account at launch
  (`backfillAccountIfNeeded`) so the upgrade can keep the library.
- Storage: V2 credentials are one Keychain item, `simkl-credential`, with
  `afterFirstUnlockThisDeviceOnly`, so a restored backup can't put one grant on
  two devices. The V1 token stays in `simkl-access-token` until V2 replaces it.
  `simklLibraryOwner` in UserDefaults remembers whose library is on the device,
  so a restore to a new iPhone asks to reconnect instead of looking signed out.
  Launch writes it again when a reinstall cleared it (UserDefaults goes with
  the app; the Keychain doesn't).
- Daily limits are per user on V2 (Free 500, PRO 1,000, VIP 10,000; reset at
  midnight US Eastern). V1 shares one allowance across the app, so its card
  offers the upgrade. A daily-limit 429 isn't retried: it ends a running sync,
  pauses syncing until the reset, and the app syncs again a minute after. Only
  a 429 for the token in use sets the pause, and a new sign-in clears it. The
  per-second 429 and the 400 write lock are retried. Catalog lookups, episode lists, `/redirect` and the
  discovery files are free, but search isn't, so "All" uses one `/search/all`
  request and an actor page spends at most six title searches (cached).
- Only `invalid_grant` on a refresh ends a sign-in. Other refresh failures
  (an outage, a proxy error page, a malformed reply) keep the credential and
  wait a minute (`refreshRetryDelay`) before asking again. Meanwhile a token
  that hasn't expired keeps working, and an expired one fails fast.
- Each request goes out for one account: whoever was signed in when it
  started, or the account its sync started for (`SyncFailureScope.account`).
  If another account replaces it, the request is cancelled rather than sent
  with the new token, on retries and after waiting on a refresh too.
- The Simalytics Worker verifies tokens for the TMDB proxy routes with the
  client ID that matches the token (`simkl_at_` = V2). Deployed 2026-11-23
  (simalytics-api #151).

## Prompting V1 users

`SimklMigrationSchedule` drives the upgrade prompt. It's quiet until
2027-01-15 (Settings row only), then a dismissible card at most every two weeks,
then a persistent card from 2027-03-01. Move the dates if Simkl announces a
different retirement. After retirement, V1 tokens get 401s and land in the
Reconnect state with V1-specific copy.

## After AUTH V1 retires

Once Simkl has retired V1 and old builds have aged out:

1. Delete `SimklClient.v1`, the `.v1` cases, the legacy Keychain read, the
   migration schedule and the upgrade copy.
2. Remove the Worker's `/oauth` route, `SIMKL_V1_CLIENT_ID` and the
   `SIMKL_CLIENT_SECRET` secret.
3. Delete the V1 app registration (#49868), and the `127.0.0.1` redirect on
   the V2 app if it's no longer used.

## Testing

- Run the full suite on an iOS simulator: `xcodebuild test -project
  simalytics.xcodeproj -scheme simalytics -destination 'platform=iOS
  Simulator,name=<device>'`, for example `name=iPhone 17 Pro`.
- `simalyticsTests/Auth` covers PKCE (RFC 7636 vector), callback checks, scope
  traps, refresh (single flight, cooldown, waiting after a failed refresh,
  `invalid_grant`), client ID pairing, requests pinned to their account
  (retries, refreshes, syncs), sign-out revoke, daily limits, and the Auth
  sign-in flows.
- To see the Reconnect, upgrade and daily-limit cards without a Simkl account,
  temporarily change the credential `SimklSession.live()` uses in screenshot
  mode (don't commit it). Check them at accessibility text sizes too: a card
  that can't scroll away covers the content beneath it.
- A live check on 2026-11-23 ran the real flow against Simkl: PKCE sign-in,
  refresh (old token 401, new 200), crossed client IDs (401), revoke, the
  pipeline, `/search/all`, and the Worker with real V1 and V2 tokens.
