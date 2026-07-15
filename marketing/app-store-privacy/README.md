# App Store Privacy

`privacy.json` is the canonical App Store privacy declaration for Simalytics.
It covers Sentry diagnostics and data synchronized to a user's Simkl account.

Review remote differences before applying or publishing:

```sh
/opt/homebrew/bin/asc web privacy plan \
  --app 6745519450 \
  --apple-id dev@kyter.com \
  --file marketing/app-store-privacy/privacy.json
```

`apply` updates the draft declaration but does not publish it. Publishing is a
separate explicit action. Re-audit this file whenever app data flows, Sentry
configuration, the Kyter API, or Simkl integration behavior changes.
