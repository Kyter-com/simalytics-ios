# Apple Release History

Generated from App Store Connect and git on 2026-07-16T01:46:07.886Z.

ASC is the source of truth for Apple versions and builds. Release tags and Xcode Cloud source commits are authoritative for git correlation; Xcode project snapshots are used only as a historical fallback.

The Created column is the App Store version-record creation date. Apple does not expose every historical storefront release date through the public API.

## App Store Versions

| Version | State | Created | Attached Build | Matched Git Commit | What's New |
| --- | --- | --- | --- | --- | --- |
| 1.0 | READY_FOR_SALE | 2025-05-06 | 22 |  |  |
| 1.0.1 | READY_FOR_SALE | 2025-05-28 | 35 |  | • Added JustWatch integration to find where to watch your shows and movies. • Added swipe-to-watch functionality in the show detail view. • Fixed issues with movie vs tv show in Anime listings. • Bug fixes and dependency updates. |
| 1.0.2 | READY_FOR_SALE | 2025-06-06 | 43 |  | • Fixed issues with trending data sorting • Added new episode modal for marking as watched • Fixed sync issues on watching items • Ability to sort by completed at instead of added at in completed item views • Updated dependencies |
| 1.0.3 | READY_FOR_SALE | 2025-06-14 | 62 |  | • Rebuilt up-next section to be cache-first with SwiftData. • Fixed some issues with specials episodes. • Fixed issues with sync process. • Changed image caching on JustWatch and Trending sections. • Fixed marking later seasons of anime shows as watched. • Updated Sentry dependency. |
| 1.0.4 | READY_FOR_SALE | 2025-06-15 | 65 |  | • Fixed an issue with anime seasons reported in the latest update. |
| 1.0.5 | READY_FOR_SALE | 2025-06-23 | 69 |  | • Added new "no image" icon for missing images. • Fixed an issue with login and authentication. • Fixed an issue with syncing up-next in background. |
| 1.0.6 | READY_FOR_SALE | 2025-10-27 | 74 |  | • Updated for iOS26 • Updated Settings screen • Updated sync process to be concurrent • Update package versions • Other small bug fixes |
| 1.0.7 | READY_FOR_SALE | 2026-01-23 | 90 |  | • View full size posters for sharing or downloading • Version number in settings • 5 star or 10 star view • Optionally hide anime • Support older iOS versions and iPadOS versions • Dependency and license lists in settings • Update synced metadata in background • Update dependencies |
| 1.0.8 | READY_FOR_SALE | 2026-04-20 | 102 |  | • More reliable sign-in — now retries automatically if your connection hiccups • Modernized internals for better performance on iOS 18+ • Updated to the latest versions of all dependencies |
| 1.0.9 | READY_FOR_SALE | 2026-04-21 | 104 |  | • Fixes for empty API responses • General updates and improvements |
| 1.0.10 | READY_FOR_SALE | 2026-05-14 | 111 |  | • Adds actor pages from cast credits, with filmographies that link back into Simalytics movie, show, and anime details. • Improves actor page loading with native skeleton states while filmography links resolve. • Improves cast image quality by loading higher-resolution actor profile photos and preserving Retina-scale sharpness in cached images. |
| 1.0.11 | READY_FOR_SALE | 2026-05-22 | 117 | 7973fba (2026-06-03; project) | • Adds per-screen list/grid toggles for Movies, TV, Anime, Up Next, and Search Results. • Expands Explore “See All” into full trending grids with year labels, plus cleaner poster-grid alignment. • Hardens Simkl sync and mark-as-watched flows so Up Next updates more consistently, anime episodes mark correctly, and API failures are easier to recover from. • Fixes an image-cache crash seen while switching layouts and improves auth error reporting. |
| 1.0.12 | READY_FOR_SALE | 2026-07-03 | 122 | e033dbb (2026-07-03; tag) | • Restored the parallax banner and refined spacing on title detail pages • Re-centered the detail action controls and tidied poster and info layout • Made the Where to Watch section more reliable • Hardened Simkl requests and media views for smoother, more consistent loading |
| 1.0.14 | READY_FOR_SALE | 2026-07-09 | 129 | b701890 (2026-07-13; tag) | • Updated app dependencies and kept OAuth callback URL details out of diagnostics. |
| 1.0.15 | PREPARE_FOR_SUBMISSION | 2026-07-14 | 131 | f37542b (2026-07-15; tag) | • Updated the App Store presentation with clearer feature details and refreshed screenshots. |

## TestFlight-Only Versions

These versions have processed builds but no App Store version record.

| Version | Builds | First Upload | Last Upload |
| --- | ---: | --- | --- |
| 0.0.1 | 13 | 2025-05-06 | 2025-05-20 |
| 1.0.13 | 3 | 2026-07-07 | 2026-07-09 |

## Builds

| Version | Build | Uploaded | Processing State | Expired | Matched Git Commit |
| --- | --- | --- | --- | --- | --- |
| 0.0.1 | 9 | 2025-05-06 | VALID | true |  |
| 0.0.1 | 10 | 2025-05-06 | VALID | true |  |
| 0.0.1 | 11 | 2025-05-06 | VALID | true |  |
| 0.0.1 | 12 | 2025-05-07 | VALID | true |  |
| 0.0.1 | 14 | 2025-05-07 | VALID | true |  |
| 0.0.1 | 15 | 2025-05-07 | VALID | true |  |
| 0.0.1 | 16 | 2025-05-09 | VALID | true |  |
| 0.0.1 | 17 | 2025-05-09 | VALID | true |  |
| 0.0.1 | 18 | 2025-05-09 | VALID | true |  |
| 0.0.1 | 19 | 2025-05-09 | VALID | true |  |
| 0.0.1 | 20 | 2025-05-09 | VALID | true |  |
| 0.0.1 | 21 | 2025-05-09 | VALID | true |  |
| 0.0.1 | 22 | 2025-05-20 | VALID | true |  |
| 1.0.1 | 25 | 2025-05-23 | VALID | true |  |
| 1.0.1 | 26 | 2025-05-24 | VALID | true |  |
| 1.0.1 | 27 | 2025-05-24 | VALID | true |  |
| 1.0.1 | 28 | 2025-05-27 | VALID | true |  |
| 1.0.1 | 29 | 2025-05-27 | VALID | true |  |
| 1.0.1 | 30 | 2025-05-28 | VALID | true |  |
| 1.0.1 | 31 | 2025-05-28 | VALID | true |  |
| 1.0.1 | 33 | 2025-05-28 | VALID | true |  |
| 1.0.1 | 34 | 2025-05-28 | VALID | true |  |
| 1.0.1 | 35 | 2025-05-28 | VALID | true |  |
| 1.0.2 | 37 | 2025-06-01 | VALID | true |  |
| 1.0.2 | 38 | 2025-06-01 | VALID | true |  |
| 1.0.2 | 39 | 2025-06-05 | VALID | true |  |
| 1.0.2 | 40 | 2025-06-05 | VALID | true |  |
| 1.0.2 | 41 | 2025-06-05 | VALID | true |  |
| 1.0.2 | 42 | 2025-06-06 | VALID | true |  |
| 1.0.2 | 43 | 2025-06-06 | VALID | true |  |
| 1.0.3 | 45 | 2025-06-07 | VALID | true |  |
| 1.0.3 | 46 | 2025-06-08 | VALID | true |  |
| 1.0.3 | 47 | 2025-06-08 | VALID | true |  |
| 1.0.3 | 48 | 2025-06-08 | VALID | true |  |
| 1.0.3 | 49 | 2025-06-10 | VALID | true |  |
| 1.0.3 | 50 | 2025-06-11 | VALID | true |  |
| 1.0.3 | 51 | 2025-06-11 | VALID | true |  |
| 1.0.3 | 52 | 2025-06-11 | VALID | true |  |
| 1.0.3 | 53 | 2025-06-11 | VALID | true |  |
| 1.0.3 | 54 | 2025-06-11 | VALID | true |  |
| 1.0.3 | 55 | 2025-06-13 | VALID | true |  |
| 1.0.3 | 56 | 2025-06-13 | VALID | true |  |
| 1.0.3 | 58 | 2025-06-13 | VALID | true |  |
| 1.0.3 | 59 | 2025-06-13 | VALID | true |  |
| 1.0.3 | 60 | 2025-06-14 | VALID | true |  |
| 1.0.3 | 61 | 2025-06-14 | VALID | true |  |
| 1.0.3 | 62 | 2025-06-14 | VALID | true |  |
| 1.0.4 | 65 | 2025-06-15 | VALID | true |  |
| 1.0.5 | 66 | 2025-06-18 | VALID | true |  |
| 1.0.5 | 67 | 2025-06-20 | VALID | true |  |
| 1.0.5 | 68 | 2025-06-23 | VALID | true |  |
| 1.0.5 | 69 | 2025-06-23 | VALID | true |  |
| 1.0.6 | 72 | 2025-09-25 | VALID | true |  |
| 1.0.6 | 73 | 2025-09-25 | VALID | true |  |
| 1.0.6 | 74 | 2025-10-27 | VALID | true |  |
| 1.0.7 | 77 | 2026-01-03 | VALID | true |  |
| 1.0.7 | 79 | 2026-01-03 | VALID | true |  |
| 1.0.7 | 80 | 2026-01-04 | VALID | true |  |
| 1.0.7 | 82 | 2026-01-04 | VALID | true |  |
| 1.0.7 | 83 | 2026-01-04 | VALID | true |  |
| 1.0.7 | 84 | 2026-01-04 | VALID | true |  |
| 1.0.7 | 86 | 2026-01-04 | VALID | true |  |
| 1.0.7 | 87 | 2026-01-08 | VALID | true |  |
| 1.0.7 | 88 | 2026-01-21 | VALID | true |  |
| 1.0.7 | 89 | 2026-01-22 | VALID | true |  |
| 1.0.7 | 90 | 2026-01-23 | VALID | true |  |
| 1.0.8 | 92 | 2026-03-13 | VALID | true |  |
| 1.0.8 | 93 | 2026-03-13 | VALID | true |  |
| 1.0.8 | 94 | 2026-03-13 | VALID | true |  |
| 1.0.8 | 95 | 2026-03-13 | VALID | true |  |
| 1.0.8 | 96 | 2026-03-14 | VALID | true |  |
| 1.0.8 | 97 | 2026-04-06 | VALID | true |  |
| 1.0.8 | 98 | 2026-04-20 | VALID |  |  |
| 1.0.8 | 99 | 2026-04-20 | VALID |  |  |
| 1.0.8 | 100 | 2026-04-20 | VALID |  |  |
| 1.0.8 | 102 | 2026-04-20 | VALID |  |  |
| 1.0.9 | 103 | 2026-04-21 | VALID |  |  |
| 1.0.9 | 104 | 2026-05-12 | VALID |  |  |
| 1.0.10 | 105 | 2026-05-14 | VALID |  |  |
| 1.0.10 | 106 | 2026-05-14 | VALID |  |  |
| 1.0.10 | 107 | 2026-05-17 | VALID |  | 0ea7356 (2026-05-17; project) |
| 1.0.10 | 109 | 2026-05-17 | VALID |  |  |
| 1.0.10 | 110 | 2026-05-17 | VALID |  | 03abb7d (2026-05-17; project) |
| 1.0.10 | 111 | 2026-05-17 | VALID |  |  |
| 1.0.11 | 112 | 2026-05-22 | VALID |  | aeb6957 (2026-05-22; project) |
| 1.0.11 | 113 | 2026-05-22 | VALID |  |  |
| 1.0.11 | 114 | 2026-05-22 | VALID |  |  |
| 1.0.11 | 115 | 2026-05-25 | VALID |  |  |
| 1.0.11 | 116 | 2026-05-25 | VALID |  |  |
| 1.0.11 | 117 | 2026-06-03 | VALID |  | 7973fba (2026-06-03; project) |
| 1.0.12 | 119 | 2026-06-08 | VALID |  | 727eb09 (2026-06-08; project) |
| 1.0.12 | 120 | 2026-07-02 | VALID |  | bb4714f (2026-07-02; cloud) |
| 1.0.12 | 121 | 2026-07-02 | VALID |  | 99ef8d1 (2026-07-02; cloud) |
| 1.0.12 | 122 | 2026-07-02 | VALID |  | e033dbb (2026-07-03; tag) |
| 1.0.13 | 123 | 2026-07-07 | VALID |  | 0e93a45 (2026-07-07; tag) |
| 1.0.13 | 124 | 2026-07-09 | VALID |  | 76fab1d (2026-07-09; cloud) |
| 1.0.13 | 125 | 2026-07-09 | VALID |  | fc735c2 (2026-07-09; cloud) |
| 1.0.14 | 126 | 2026-07-09 | VALID |  | 17dd825 (2026-07-09; cloud) |
| 1.0.14 | 127 | 2026-07-09 | VALID |  | 79f98e9 (2026-07-09; tag) |
| 1.0.14 | 128 | 2026-07-12 | VALID |  | abc228a (2026-07-12; cloud) |
| 1.0.14 | 129 | 2026-07-13 | VALID |  | b701890 (2026-07-13; tag) |
| 1.0.14 | 130 | 2026-07-14 | VALID |  | dffd478 (2026-07-14; cloud) |
| 1.0.15 | 131 | 2026-07-15 | VALID |  | f37542b (2026-07-15; tag) |

## Release Commits

### 1.0.11 (117)

Matched 7973fba from 2026-06-03: chore: stage Simalytics 1.0.11 build 117 [Xcode project snapshot]

No prior reliably correlated release commit; commit range omitted.

### 1.0.12 (122)

Matched e033dbb from 2026-07-03: docs: record 1.0.12 App Store release notes [release tag simalytics-ios@1.0.12+122]

- chore: add ASC-backed release tracking
- chore: bump release train to 1.0.12
- fix: harden Simkl requests and media views
- fix: restore parallax banner, align detail actions, harden Where to Watch
- fix: re-center detail controls and restore poster/info spacing
- chore: gitignore asc release staging checkpoints
- docs: record 1.0.12 App Store release notes

### 1.0.14 (129)

Matched b701890 from 2026-07-13: chore(marketing): add public-domain App Store screenshot pipeline (#30) [release tag simalytics-ios@1.0.14+129]

- fix: stabilize sync and prep 1.0.13 release
- chore: gitignore asc release staging checkpoints
- docs: record 1.0.12 App Store release notes
- fix: upload Sentry dSYMs from Xcode Cloud via ci_post_xcodebuild.sh
- chore(deps): bump transitive js-yaml to 3.15.0 (fix moderate DoS advisory)
- docs: note Sentry dSYM upload flow and token requirement in AGENTS.md
- chore: prep 1.0.14 release
- chore: sync 1.0.14 build number
- icon
- chore(marketing): add public-domain App Store screenshot pipeline (#30)

### 1.0.15 (131)

Matched f37542b from 2026-07-15: chore: stage App Store 1.0.15 release (#32) [release tag simalytics-ios@1.0.15+131]

- chore(marketing): add movie-detail screenshot slide and color PD posters (#31)
- chore: stage App Store 1.0.15 release (#32)

