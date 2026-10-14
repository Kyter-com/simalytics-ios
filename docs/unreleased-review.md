# Unreleased version review

Reviewed October 12, 2026, using Xcode 27.0 (27A266a).

## Scope and release baseline

Reviewed all eight open GitHub issues and the changes since `simalytics-ios@1.0.15+134`, including the iOS 27 UI work, dependency update, detail cleanup, and authoritative Up Next changes. App Store Connect reported 1.0.15 as the publicly released version and 1.0.17 (139) as the latest valid beta build. The starting commit was `fcc6e97` on `NickReisenauer/issues-prs`.

The initial review kept version 1.0.17/build 139 unchanged and recorded the user-facing changes in patch changesets. Release preparation subsequently consumed those changesets into version 1.0.18/build 140. It adds no dependencies or SwiftData schema changes. No archive, upload, or distribution was performed. After the initial review, the user explicitly authorized live testing and supplied an access token; those results are recorded below.

## Changes and issue disposition

| Request | Implementation and evidence |
| --- | --- |
| User-selectable default tab | Settings → On Launch → Default Tab offers Up Next, Lists, Explore, and Settings. Native picker rows include glass icons, descriptions, checkmarks, and selection feedback. Decorative icons are omitted at accessibility text sizes. The preference applies on the next launch; Up Next remains the fallback. Screenshot overrides do not overwrite it. Unit tests cover all choices and invalid preferences; selecting Lists and cold-launching without an override opened Lists. |
| [#21: fullscreen posters](https://github.com/Kyter-com/simalytics-ios/issues/21) | Simultaneous pan/pinch, scale limits of 1–5, image-aware pan bounds, double-tap zoom/reset, load failure/retry UI, and actual Photos completion/error feedback. Photos saving was exercised on the simulator. This exposed an actor-isolation crash in the Photos change callback; an explicit `@Sendable` callback fixed it, and the repeated save completed successfully. Geometry tests cover bounds and viewport changes. |
| [#22: premature empty search](https://github.com/Kyter-com/simalytics-ios/issues/22) | Search now runs for the initial query and distinguishes debounce/loading, completed empty results, and failed requests. Task cancellation and a request generation prevent stale results. Category, query, hidden-anime preference, and retry all participate in task identity. Contract tests cover initial results, hidden anime, errors, empty results, and cancellation. |
| [#23: small-phone grids](https://github.com/Kyter-com/simalytics-ios/issues/23) | All poster grids use the shared 8-point horizontal padding, fitting three 110-point columns with two 12-point gaps within 375 points. Verified visually on an iPhone SE simulator. |
| [#24: rating controls](https://github.com/Kyter-com/simalytics-ios/issues/24) | Five-star mode can select half stars. Tapping the selected score or Remove Rating clears it through `/sync/ratings/remove`. Rating writes validate acknowledgements, prevent duplicate submissions, roll back failed optimistic updates, and update local confirmed values immediately. Shared controls provide 44-point targets and an adjustable accessibility element. The actual UI changed 4 to 3½ stars and then cleared the rating using offline fixtures. |
| [#25: misleading local-data reset](https://github.com/Kyter-com/simalytics-ios/issues/25) | Adopted the issue's rename option: “Reset & Sign Out,” a destructive confirmation, and explanatory text explicitly describe the sign-out and local-data removal. The action is disabled during sync. Server lists, ratings, and history are not deleted by this action. |
| [#26: duplicated detail UI](https://github.com/Kyter-com/simalytics-ios/issues/26) | Movie, TV, and anime details share poster/header, rating, action-button, and episode-row components. Headers use the same poster/placeholder dimensions and stack vertically at accessibility text sizes. Season-specific logic remains with its detail view. |
| [#27: platform glass treatment](https://github.com/Kyter-com/simalytics-ios/issues/27) | Glass poster controls and default-tab icons use availability-gated platform styling. The tab bar minimizes while scrolling on iOS 26+. Detail zoom transitions now respect Reduce Motion. Older systems retain supported controls. |
| [#47: anime removals](https://github.com/Kyter-com/simalytics-ios/issues/47) | Anime episode and whole-title removal use the `shows` envelope supported by the SIMKL reference. Removal calls validate deleted counts and resolver failures instead of treating every successful HTTP response as success. Offline tests exercise the actual TV/anime methods, absolute anime numbering, and documented/live-shaped acknowledgement fixtures. An authorized live probe subsequently verified anime watch/unwatch and whole-title removal through the actual app methods; the original library state was restored and compared with the baseline. |

Typed episode-history decoding also rejects boolean/fractional counts previously accepted through loosely typed JSON conversion. Rating tests cover all 33 media-type/score combinations, HTTP failures, rejected IDs, malformed acknowledgements, cancellation, and persistence that preserves list membership.

## Sentry-driven recovery and performance changes

The [Sentry review](sentry-review.md) led to additional local fixes: recoverable store opening and sync storage alerts; rollback and stop-on-storage-failure behavior; validated library reads that preserve rows and cursors on failure; bounded retries for transient episode GET failures; and visible episode retry UI. Trending refreshes retain cached results on failure. Tests cover malformed, rejected, valid, and empty full-list responses for movies, TV, and anime.

Store opening and the 13 Lists status counts now run off the UI actor, Explore shelves create cells lazily, and overlapping operations keep the loading indicator active until all finish. These address identifiable work on launch/tab transitions without claiming the unsymbolicated physical-device hang has been reproduced or conclusively fixed.

## Validation

| Check | Result |
| --- | --- |
| Full Swift Testing suite, iOS 27.0 | 111 definitions / 238 executions passed; zero failures or skips, including recovery and telemetry isolation |
| Full Swift Testing suite, iOS 18.5 | 111 definitions / 238 executions passed; zero failures or skips, including recovery and telemetry isolation |
| Debug simulator build | Passed, including final accessibility layout adjustment |
| Release simulator build, arm64 and x86_64 | Passed after recovery changes |
| Release signed-out launch | Opened the on-disk store asynchronously and reached Up Next with sign-in-required content |
| Default-tab UI and preference | Native picker checked visually; Lists persisted across a cold launch |
| Small-phone grid | Three columns visible at 375-point width |
| Shared detail and rating UI | Checked in dark mode; half-star selection and removal worked |
| Poster flow | Open/close, double-tap zoom, pan, and successful Photos save checked |
| Largest accessibility text, default-tab screen | Text wraps and rows remain scrollable; decorative icons no longer crowd text |
| Recovery UI, iOS 27 | Store-open retry reached populated Lists; sync-storage retry dismissed the alert; episode retry restored a visible row using offline fault fixtures |
| Explore and Lists | Horizontal shelf scrolling, largest-text layout, background counts, and search focus checked on iOS 27 |
| Strict Swift formatting lint, new source and test files | Passed |
| `npm run release:check` | Passed; 1.0.17 (139) remains consistent |
| `git diff --check` | Passed |

Both full suites and the Release build were repeated after the final Photos callback, accessibility, and decoder naming fixes.

The initial Sentry follow-up added eight telemetry definitions (17 executions). The recovery follow-up adds 21 more definitions (47 executions). Temporary offline startup/sync/episode fault-injection hooks were removed after UI verification; the permanent tests inject dependencies and verify persisted state. Final suites and Release builds run against the implementation without those UI hooks.

Local evidence is retained under ignored `build/validation/issues-review/`, including xcresult bundles, test summaries, build logs, accessibility snapshots, and screenshots. Build output includes the existing AppIntents metadata warning and simulator Sentry fallback/telephony messages. The final xcresult summary reports no runtime warnings or test failures.

## Native Apple interface follow-up

On iOS 26 and later, the modern `Tab` API marks Explore with the native search role. Query state belongs to the tab container, while the search field and category scopes attach to Explore's root content inside its navigation stack. This keeps catalog search out of other tabs and detail banners while retaining the native bottom search field. Selecting Explore activates native search; cancellation returns to the previously selected tab, while a downward drag dismisses just the keyboard. The saved default-tab values remain unchanged. Earlier iOS versions retain the original tab arrangement and search presentation.

Detail actions use `.buttonStyle(.glass)` within a `GlassEffectContainer`, with large controls and the existing horizontal-to-vertical adaptive layout. Earlier systems use bordered buttons. Existing tab minimization, native zoom transitions with Reduce Motion support, and glass poster controls remain in place.

Validation for this follow-up: Debug build passed; iOS 27 simulator checks covered native search activation/dismissal, a public read-only “Nosferatu” query, the Movies category scope, navigation into a local Completed list without carrying the global query into its filter, compact tabs while scrolling, and selecting Explore as the default then cold-launching without a screenshot-tab override. Typing “His Girl” in the local list independently filtered it to His Girl Friday while keeping Lists selected. The public query used the app's search client, with no account mutations or private token. Poster requests continued to use the public-domain fixture interceptor, so non-fixture search art appeared as placeholders. Native detail actions, their stacked layout at the largest accessibility text size, and the iOS 18.5 bordered fallback were inspected visually. The final focused AppTab/SearchResults run passed all 6 test definitions (12 executions), with no failures, skips, or runtime warnings. The final Release simulator build passed for arm64 and x86_64.

Useful next larger integrations are an Up Next widget and App Shortcuts for opening Up Next/searching the catalog. They are recommendations, not part of this patch. A tracker has no ongoing playback session, so a persistent mini-player or Live Activity would need a separate, useful product use case.

The App Store screenshot refresh captured all five existing slides on iPhone 18 Pro Max and iPad Pro 13-inch (M5), both running iOS/iPadOS 27. The original headlines, backdrop, frames, and layout are preserved: pixel comparison found all changes confined to the device screens. All ten RGB exports retain the required dimensions. Headline plates prevent host font updates from changing the approved typography. The same public-domain artwork is used; the featured title now demonstrates a 3½-star rating. The fixture generator also preserves the authoritative `next_to_watch` marker already present in its generated Swift file.

Fresh captures exposed an inherited catalog search field over non-Explore content. Search now attaches inside Explore's navigation stack, and interactive keyboard dismissal keeps its native field visible while browsing. The corrected UI was checked through a public read-only “His Girl Friday” search and category selection; marketing captures contain only offline fixtures. After this correction, the focused AppTab/SearchResults run again passed 6 definitions / 12 executions, and the dual-architecture Release simulator build passed. The iPhone Explore capture was retaken after dismissing the keyboard through the Orca emulator. Capture logs, comparison results, and contact sheets are under ignored `build/validation/screenshot-refresh/`.

References: [Apple’s Liquid Glass adoption guide](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass), [native tab search activation](https://developer.apple.com/documentation/swiftui/view/tabviewsearchactivation(_:)), [SwiftUI updates](https://developer.apple.com/documentation/updates/swiftui), [WidgetKit](https://developer.apple.com/documentation/widgetkit), and [App Intents](https://developer.apple.com/documentation/appintents).

## Authorized live validation

A temporary Swift Testing integration test ran the actual app methods on iOS 27, sequentially, with the user-supplied token loaded from a private simulator input file. It passed 39 boolean checks across these flows:

- Movie, TV, and anime details and watched-state decoders; TV/anime episode catalogs; all three search categories; and TV/anime Watching-summary decoding.
- Rating an existing unrated movie, TV show, and anime to 7/10, confirming each score through a fresh library read, removing each rating, and confirming the original score and list status. The anime rating requests used `shows`.
- Marking one initially unwatched, aired anime episode watched, verifying exactly one watched episode, unmarking it through the new `shows` removal envelope, and verifying zero watched episodes.
- Removing that existing anime entry after it had no watch history, rating, or memo, verifying its absence, and restoring its original Plan to Watch status and added date. The original empty watch history and rating were also verified.

Fresh full-library responses for movies, TV, and anime were compared with the private pre-test snapshots by Simkl ID. Membership was identical and **zero rows had changed field values** across all three categories. This comparison excludes server activity/audit timestamps, which write tests can advance.

The tested live contracts required no additional production API changes beyond this patch's corrected envelopes and acknowledgement validation. In particular, the successful HTTP responses were followed by authoritative read-back checks rather than treated as proof by themselves. This resolves the earlier live-validation gap for #47 without claiming every possible account or catalog case was exercised.

The temporary integration source, token input, raw private responses, build logs, and xcresult bundles were removed. Only sanitized boolean outcomes and baseline-comparison totals remain in ignored `build/validation/issues-review/live-validation.json`. No token was written to tracked source or retained in the app keychain. The permanent offline suite was rerun after removing the integration harness.

## Season resume follow-up

TV and anime details now share a progress-based initial season selector. It starts
at the highest numbered season containing a watched regular episode, stays there
if it is unfinished, and advances to the next available season when it is complete.
Earlier skipped seasons no longer pull the selection backward. With no watched
regular episodes, the first season remains the default; when caught up, the last
season remains selected. Specials do not influence this selection. Anime uses
absolute episode numbers in SIMKL's watchlist season 1 to resolve its display groups.
This changes the detail screen's initial selection, not the authoritative Up Next queue.

Added ten regression tests across the existing TV and anime season suites,
including South Park season 28 watched / season 29 unwatched with season 1 skipped,
partially watched later seasons, caught-up titles with older gaps, unsorted catalogs,
missing season numbers, specials, and unrelated watched entries. Eight cases failed
against the previous implementation. After the fix, all 29 season tests passed on
iOS 27 with no failures or skips. The Debug app/test build, focused formatting lint,
release consistency check, and `git diff --check` passed. Evidence is under ignored
`build/validation/season-resume/`. No live account writes were needed for this change.

## Episode browser and stable descriptions

TV and anime now share an episode browser with a native checked menu, watched
progress, and a “Next unwatched” jump within the selected group. TV uses season
names; anime uses its actual absolute episode ranges while retaining SIMKL's
season-1 watch coordinates. The progress-based initial selection described above
is preserved. This navigation shortcut does not change the authoritative Up Next
queue or predict unannounced episodes.

The lazy episode section lets its header scroll away at every text size, avoiding
a second sticky bar under navigation. Compact rows reserve one line each for
titles and description previews (two at accessibility sizes), plus consistent
metadata and thumbnail space. Preview whitespace is normalized, while a shared,
scrollable detail sheet retains the full description. Loaded, missing, and failed
images occupy the same frame. Larger text uses a vertical row layout.

Watch buttons work directly in the list on supported deployment targets. iOS 27
also uses native `swipeActionsContainer()` and full trailing swipes. A shared
observable model coordinates list and sheet writes, blocks overlapping actions
through reconciliation, restores failed optimistic changes, and presents errors
on the currently visible surface. Anime specials retain their existing read-only
actions. No new API endpoints or production dependencies were needed.

Validation for this follow-up:

- Full iOS 27 suite: 130 definitions / 257 executions passed, zero failures,
  skips, or runtime warnings. Full iOS 18.5 suite: 128 definitions / 255 executions
  passed; after adding the final two catalog edge cases, the focused browser and
  coordinator suite passed all 17 definitions on iOS 18.5.
- Fourteen browser tests exercise the actual production model, replacing five
  tests that duplicated the old inline optimistic-update implementation. Cases
  cover season resume, anime coordinates, forward navigation with older gaps,
  specials, missing seasons, duplicate IDs, first writes, rollback, cancellation,
  refresh, and overlapping actions during reconciliation.
- Simulator interaction checks covered iOS 27 native full swipe, checked range
  selection, scroll reset, next-episode jump, watch buttons, light/dark appearance,
  largest accessibility text, long-description scrolling, and errors from both
  the list and sheet. iOS 18.5 watch buttons updated the row and progress.
- Accessibility-frame comparisons verified equal heights for short and long
  descriptions and unchanged row frames after a watch update. Largest-text rows
  also have equal heights. The failed-save fixture restored both the row state
  and watched count.
- Final Debug and dual-architecture Release simulator builds passed after the
  accessibility header and tap-target fixes. Strict formatting passed for new
  source and test files. Existing `simkl_id` naming lint remains in the two detail
  views. Release consistency and `git diff --check` passed.

Evidence is under ignored `build/validation/episode-browser/`. DEBUG-only synthetic
catalogs extend the existing screenshot mode with long descriptions, later-season
progress, missing images, and controllable save failures. These interaction checks
made no live account mutations. The existing marketing slides depict other screens
and did not need to be regenerated for this episode-list change.

## Limits

The subsequent [Sentry review](sentry-review.md) covers all 16 issues active in the last 90 days, distinguishes test traffic from real-device failures, and records the telemetry isolation, recovery, data-integrity, and performance changes alongside remaining physical-device follow-ups.

- Live writes covered one title per rating category and one anime episode/title removal round trip. Other account, rewatch, and catalog combinations remain covered only to the extent of the offline tests. No Infisical credentials were needed or accessed.
- Simulator interaction coverage used iOS 27, iOS 18.3, and iOS 18.5; automated logic coverage used iOS 27 and iOS 18.5. iOS 17, iPad episode browsing, macOS, and visionOS interactions were not exercised.
- No physical device was connected. The MetricKit/tab hangs still require on-device profiling and post-release recurrence checks; simulator responsiveness alone cannot establish resolution.
- Accessibility work includes larger text, labeled/adjustable controls, minimum tap targets, and Reduce Motion handling; this is not a complete VoiceOver or contrast audit.
- At review completion, no GitHub issues had been closed and no changes had been pushed or released. The subsequent 1.0.18 release preparation uses the repository's Xcode Cloud workflow; remaining physical-device investigations are still open.

## API references

- [SIMKL remove from history](https://api.simkl.org/api-reference/simkl/remove-from-history): removal envelopes, deleted counts, and resolver failures.
- [SIMKL add ratings](https://api.simkl.org/api-reference/simkl/add-ratings): supported rating values and acknowledgement shape.
- [SIMKL remove ratings](https://api.simkl.org/api-reference/simkl/remove-ratings): explicit rating removal rather than submitting zero to add-ratings.

## Release preparation: 1.0.18 (140)

Prepared October 13, 2026. ASC reported 1.0.15 as the current App Store version
and 1.0.17 (139) as the newest processed TestFlight build. The configured Xcode
Cloud workflow builds `main`; its next build number was 140. Changesets updated
the package manifests, changelog, and Xcode marketing version. The saved App Store
notes also include the earlier TestFlight-only Up Next improvements since 1.0.15.
Canonical 1.0.18 metadata contains the same notes and current feature descriptions.

All ten refreshed screenshots are included, retaining the approved headlines,
frames, and layouts. ASC's local validator accepted five iPhone screenshots as
`APP_IPHONE_67` (1290×2796) and five iPad screenshots as `APP_IPAD_PRO_3GEN_129`
(2064×2752), with no errors. Canonical metadata validation also passed. Screenshot
folders retain their existing `iphone-6.9` and `ipad-13` names; the ASC display types
above identify the upload sets. Release preparation does not constitute an App
Store review submission or a public release.


## UI polish and replacement release: 1.0.18 (141)

Follow-up to device feedback on build 140, prepared October 13, 2026:

- Standard episode rows are approximately 75 points tall, down from 149, with
  fixed thumbnail and preview space. Long descriptions remain available in the
  detail sheet. Short/long rows and missing/loaded artwork have equal heights.
- The episode header scrolls away at all text sizes. TV, anime, and movie detail
  screens explicitly use an inline navigation bar. DEBUG navigation fixtures now
  exercise the real back button instead of only presenting details at the root.
- Ten-star ratings use one continuous, 44-point-high rating strip and stay on one
  line. Five-star mode retains half-star selection. VoiceOver adjustment and rating
  removal remain available; the animation task follows the view's lifetime.
- Restored the compact poster-side year, runtime, progress, and watchlist-button
  spacing. Accessibility sizes place each label above its value to avoid squeezed
  words. The standard layout remains side by side.

Validation: all 133 test definitions passed on iOS 27; all 21 focused rating and
episode-browser definitions passed on iOS 18.5. Parameterized rating tests exercise
every whole/half-star position, different widths, scale edges, and zero width.
Final Debug and arm64/x86_64 Release simulator builds passed. Simulator inspection
covered compact TV/anime rows, navigation scrolling, full descriptions, ten-star
selection, five-star half selection, and the largest accessibility text size.

The iPhone and iPad detail screenshots were recaptured from the offline PD
fixtures and regenerated with the existing headlines, frames, and composition.
The other eight screenshots are unchanged. The user-facing Changeset was folded
into the existing 1.0.18 changelog and cumulative release notes because 1.0.18 is
still unreleased; the marketing version remains 1.0.18 and ASC selected build 141
for the replacement Xcode Cloud build. No App Store review submission is implied.
