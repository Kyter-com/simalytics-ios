# @kyter/simalytics-ios

## 1.0.18

### Patch Changes

- Tighten episode rows and let their header scroll away under the native back button. Restore the original poster and watchlist-status alignment using natural stack spacing and keep ten-star ratings on one line while preserving the optional five-star scale. Larger accessibility text gives detail labels and values their own lines.

- Choose your default launch tab in Settings with a native selection screen and Liquid Glass styling. Simalytics still opens on Lists until you pick another tab, and Lists shows your saved counts right away instead of waiting for sync. The tab bar now makes more room while scrolling on iOS 26 and later, and detail transitions respect Reduce Motion.

  Search now shows loading and connection errors accurately, including the first query. Poster grids fit three columns on smaller iPhones, and detail screens share consistent headers, placeholders, and episode rows.

  Set half-star ratings in five-star mode, remove ratings, and recover from failed saves. Episode and list removals now detect rejected updates from Simkl.

  Pan and zoom fullscreen posters with sensible limits, retry failed loads, and receive save confirmation only after Photos finishes saving. Settings clearly labels and confirms the local reset that signs you out.

  Keep automated tests and screenshot fixtures out of crash reporting, and separate simulator and development diagnostics from production events.

  Recover from library storage failures with clear retry guidance, preserve saved titles when sync responses fail, and stop repeated work when the database cannot be written. Episode lists now show connection failures with a retry action.

  Open the library and calculate list counts away from the UI thread, load Explore shelves lazily, and keep the loading state accurate during overlapping operations.

  Explore adopts the native search tab on iOS 26 and later, with a floating search control and a search field beside the compact tabs. Detail actions use native Liquid Glass buttons with larger touch targets and an adaptive layout; older iOS versions keep standard controls.
- Browse TV and anime episodes with a native season or episode-range picker, watched progress, and a shortcut to the next unwatched episode. Mark episodes directly from the list or with a full swipe on iOS 27, with shared save protection and visible errors.

  Compact episode rows reserve consistent space for titles, description previews, and thumbnails to prevent long descriptions or loading images from shifting the list. Full descriptions open in a scrollable sheet, and larger text uses an adaptive layout.
- TV and anime details now open at your latest watched season or episode group and advance when it is complete, instead of returning to earlier seasons you skipped.

## 1.0.17

TestFlight-only; included in the 1.0.18 App Store release preparation.

### Patch Changes

- 389ea79: Poster taps now zoom into detail screens, Up Next grid cells support swipe-to-mark-watched on iOS 27, and badges adopt the Liquid Glass look on iOS 26 and later.
- 5159411: Open on Up Next by default, hide stale or unaired next episodes using SIMKL's authoritative watchlist data, and mark episodes watched with a single full left swipe. Keep tap and accessibility actions available and show errors when a watched update fails.

## 1.0.16

TestFlight-only; included in the 1.0.18 App Store release preparation.

### Patch Changes

- Show and anime detail now open on the first season with unwatched episodes instead of always starting on season 1.

## 1.0.15

### Patch Changes

- Updated the App Store presentation with clearer feature details and refreshed screenshots.
- Improved watch-history sync resilience, including titles that are not yet in your Simkl watchlist.
- Prevented duplicate episode updates and made cancelled background refreshes stop promptly.
- Reduced stalls while browsing image-heavy and preview-rich screens.

## 1.0.14

### Patch Changes

- Updated app dependencies and kept OAuth callback URL details out of diagnostics.
- Refreshed the Simalytics app icon for light, dark, and tinted appearances.

## 1.0.13

TestFlight-only; superseded by 1.0.14 before App Store release.

### Patch Changes

- Improved sync reliability and reduced database/cache write pressure that could cause hangs or local store errors.

  Improved Simkl request retry behavior and reduced noisy reporting for expected transient network interruptions.

## 1.0.12

Shipped to the App Store as build 122 (submitted 2026-07-03).

- Restored the parallax banner and refined spacing on title detail pages
- Re-centered the detail action controls and tidied poster and info layout
- Made the Where to Watch section more reliable
- Hardened Simkl requests and media views for smoother, more consistent loading

## 1.0.11

Current tracked app version when Changesets release tracking was adopted.

Historical Apple release/build data is pulled from App Store Connect with `npm run release:backfill`.
