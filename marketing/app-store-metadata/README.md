# App Store Metadata

Canonical App Store localization metadata for Simalytics. Keep this copy aligned
with the current screenshots in `marketing/app-store-screenshots/`.

Review a change before applying it:

```sh
/opt/homebrew/bin/asc --profile simalytics metadata plan \
  --app 6745519450 \
  --app-info 46b77b70-5bfb-4b82-9e54-a5914ac3aa73 \
  --version 1.0.15 \
  --platform IOS \
  --dir marketing/app-store-metadata
```

Apply only an approved review artifact. App Store screenshots, age ratings,
categories, accessibility declarations, privacy labels, and copyright are
managed separately by ASC.

The canonical privacy declaration and its ASC Web workflow live in
`marketing/app-store-privacy/`.
