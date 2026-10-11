# Up Next feedback: review and validation

Validated October 11, 2026 with Xcode 27.0 (27A266a).

## Scope

Implements the three reported requests: remove phantom next episodes during a hiatus, open on Up Next, and mark watched with a single full left swipe.

- Feature branch: `NickReisenauer/up-next-feedback`.
- Base: `origin/main`, commit `6a1d25b392bef6fbe108e8b4c017638af83d0021`. This repository uses `main`, not `master`.
- No new dependencies, SwiftData schema changes, version/build bump, archive, or distribution.
- Reviewed current SIMKL endpoint references, Sync guide, rate limits, and Apple's iOS 27 SwiftUI guidance. Performed public/read-only API requests followed by an explicitly authorized reversible TV episode mutation; final watch state was restored.

## Root cause and live API evidence

The old view displayed any Watching row with a next-episode title. A second local sync path reconstructed next episodes from watched counts and catalog `aired` flags and never cleared old details when no next episode remained. Neither should override SIMKL's authoritative per-user `next_to_watch` marker.

Sequential public requests using the app's existing client metadata returned:

| Request | Result |
| --- | --- |
| `GET /anime/episodes/38636?extended=full` | HTTP 200, JSON; 1,235 catalog rows |
| `GET /anime/38636?extended=full` | HTTP 200, JSON; One Piece, status `airing`, total_episodes 1184 |
| `GET /sync/all-items/anime/watching` without a user token | HTTP 401, `user_token_failed`, as expected |

Selected live catalog rows:

| Episode | aired | date |
| --- | --- | --- |
| 1179 | true | 2026-09-20T23:15:00+09:00 |
| 1180 | true | 2026-09-27T23:15:00+09:00 |
| 1181 | true | null |
| 1182 | true | null |

This reproduces the suspicious input to the old computation: `aired: true` is present even on undated episodes. It does **not** establish that the user's authoritative next marker is null or prove a broadcast schedule. No production exception for One Piece is hardcoded. Full responses are retained only in ignored local validation output, with no access tokens or client keys in the report.

## Implementation

1. **Authoritative eligibility.** Require a non-empty `next_to_watch` and valid regular-episode coordinates. Titles alone and counts no longer decide availability. Reject explicitly future or malformed supplied air dates; parse timezone offsets and fractional seconds. Missing dates/titles do not override an authoritative marker with valid coordinates.
2. **Remove local prediction.** Delete the catalog/count-based `processUpNextEpisodes`. Watching summaries own the next marker and details. A nil marker clears stale next-episode detail fields.
3. **Refresh correctly.** Keep activity-driven deltas incremental. Forced/six-hour active-sync refreshes read Watching summaries without `date_from`, after checking activities, to pick up catalog corrections. No background polling timer. Stamp freshness only after both summary requests succeed.
4. **Handle empty responses.** SIMKL documents `{}` as a valid empty list, and authenticated testing also observed HTTP 200 top-level JSON `null`. Accept both and empty arrays, but reject error envelopes, explicit null arrays, missing IDs, invalid IDs/statuses, and malformed JSON. Full responses clear queue metadata for absent Watching titles; deltas never clear absent siblings. Preserve library rows, ratings, memos, and separate catalog enrichment instead of guessing a new list status or deleting titles.
5. **Preserve catalog data.** Update existing summary fields in place rather than replacing models with nil catalog fields. Regression tests verify release dates and enriched catalog IDs survive refreshes.
6. **Launch on Up Next.** Initialize tab selection to Up Next. Existing DEBUG screenshot-tab overrides remain intact. Release signed-out content stays sign-in-gated.
7. **Full-swipe behavior.** Attach list swipe actions to the row, set `allowsFullSwipe: true`, and keep Watched first. On iOS 27, coordinate grid actions with `swipeActionsContainer()`; gate APIs for older systems. Keep partial-swipe/tap, context-menu Mark Watched, and custom accessibility actions.
8. **Avoid duplicate writes and false success.** Up Next accepts only one action at a time across all rows through reconciliation, following SIMKL's per-user write serialization. Episode-history responses validate `added.episodes` and all documented `not_found` buckets; a 201 with unresolved input is a failure. An already-watched zero-count retry remains idempotent success. Show safe errors; don't silently hide failed writes.
9. **Offline interaction harness.** DEBUG-only screenshot mode includes authoritative markers and handles gestures by updating its in-memory fixtures. The sentinel token never reaches the episode-write API. Release contains no fixture branch.
10. **Release tracking.** `.changeset/up-next-feedback.md` records all three user-facing changes without bumping version 1.0.16/build 137.

## Second-review repairs

The additional review identified and repaired these issues before PR creation:

- The first implementation incorrectly treated documented `{}` empty-list responses as schema failures.
- Absent stale rows retained old queue information after full Watching pulls.
- Forced refreshes with nil activity timestamps could never run.
- More frequent model upserts could erase separately enriched catalog data.
- Episode writes previously treated any successful HTTP status as success without examining resolver failures.
- Per-title guarding still allowed simultaneous Up Next writes to different titles.
- iOS 27 grid actions lacked the documented coordinating container.

## Final checks

| Check | Result |
| --- | --- |
| Complete Xcode 27 Debug build/typecheck + suite on iOS 27.0, iPhone 18 Pro | Passed: 67 definitions / 86 parameterized executions; zero failures/skips |
| Same complete suite on iOS 18.5, iPhone 16 Pro | Passed: 67 definitions / 86 executions; zero failures/skips |
| Final Release simulator build, arm64 + x86_64 | Passed |
| Final Release signed-out cold launch | Up Next selected; sign-in-required content |
| Debug fixture cold launch, no tab override | Up Next selected |
| Full list left swipe | Target marked without tapping Watched |
| Partial list swipe then Watched tap | Partial swipe retained target; tap marked it |
| Full iOS 27 grid swipe | One target removed; other items retained |
| Grid swipe-container coordination | Opening another cell's actions leaves only one Watched action open |
| Strict formatting lint: request utility, response decoder, new/expanded contract tests | Passed |
| `npm run release:check` | Passed; 1.0.16/build 137 unchanged |
| `git diff --check` | Passed |

Offline HTTP contract tests exercise the **actual** TV/anime `markEpisodeWatched` methods, not only a duplicated request builder. Their fixture validates POST path, headers, required app metadata, one title/season/episode, absolute anime numbering, watched_at, and no allow_rewatch. Response cases include success, already-watched zero additions, not_found.shows (including anime), not_found.episodes, malformed acknowledgements, excessive episode counts, HTTP 401, and cancellation.

Watching tests cover One Piece episode 1181 as a stale regression scenario, nil markers with retained info, empty object/array/top-level-null responses, nil activity forced reads, full-vs-delta semantics, absent rows, preserving enriched model fields, invalid IDs/envelopes/arrays, cache boundaries, specials, timezone offsets, fractional seconds, and request metadata. Existing mutation coordination tests cover double submission, cancellation and rollback.

Ignored local evidence is under `build/validation/review/`: live API summaries/catalog output, both xcresult bundles and JSON summaries, Release log, launch/gesture AX snapshots, and a Release screenshot. The final builds have the existing AppIntents metadata-extraction warning (no AppIntents dependency) and Sentry always-run build-phase note. No Swift typecheck errors, failed test cases, or runtime warnings were reported.

Early simulator gestures during layout transition only opened the swipe button and failed automation assertions. They were not counted as successes; verification was repeated after layout settled, using fresh AX frames and verified before/after state. No app assertion/test was weakened to accommodate tooling issues.

## Sources

- [SIMKL Sync guide](https://api.simkl.org/guides/sync): authoritative next marker, activities-first sequential sync, catalog/count freshness caveat.
- [SIMKL all-items reference](https://api.simkl.org/api-reference/simkl/get-all-items): empty object, response shapes, next_watch_info, delta semantics.
- [SIMKL history reference](https://api.simkl.org/api-reference/simkl/add-to-history): granular episode requests, idempotent rewrites, added/not_found response.
- [SIMKL anime guide](https://api.simkl.org/guides/anime): absolute anime numbering.
- [SIMKL date conventions](https://api.simkl.org/conventions/dates): broadcast offsets.
- [SIMKL rate limits](https://api.simkl.org/resources/rate-limits): per-user write serialization, GET/POST limits.
- [Apple swipeActions](https://developer.apple.com/documentation/swiftui/view/swipeactions(edge:allowsfullswipe:content:)): first full-swipe action.
- [Apple swipeActionsContainer](https://developer.apple.com/documentation/SwiftUI/View/swipeActionsContainer()).
- [Apple WWDC26 SwiftUI](https://developer.apple.com/videos/play/wwdc2026/269/): swipe actions beyond List.
- [Apple TabView](https://developer.apple.com/documentation/swiftui/tabview).
- [Apple accessibility testing](https://developer.apple.com/documentation/accessibility/performing-accessibility-testing-for-your-app).

## Authorized authenticated validation

After initial PR creation, the user supplied credentials and explicitly authorized live mutations. A temporary, uncommitted Swift test exercised the actual app methods on iOS 27:

- Activities and both Watching endpoints returned HTTP 200. TV responses decoded and persisted; the account had 31 Watching TV entries and 17 eligible Up Next entries.
- The anime Watching response was JSON `null`. Added top-level-null empty-response support and a permanent regression case; null arrays inside a nonempty envelope still fail validation.
- One existing unwatched regular TV episode was marked through `ShowDetailView.markEpisodeWatched`, acknowledged, verified watched through `/sync/watched`, and reconciled through the Watching-summary persistence path. Count increased by exactly one and next marker advanced.
- `markEpisodeUnwatched` then restored the episode to unwatched, the original count, list status and next marker. Ratings and memos were unchanged. Watch/mutation activity timestamps necessarily changed; the server's full activity/audit trail is not reversible.
- Both temporary live tests passed. Removed the temporary test, credential file, raw private responses, private logs/result bundle, and scripts. Retained only sanitized boolean outcome evidence. No credentials or private title/watchlist details are committed.
- Reran the complete permanent suite after the decoder repair (86 executions on iOS 27 and iOS 18.5) and the Release simulator build. Earlier launch/swipe checks remain applicable; UI files did not change.

## Remaining limitations

- This account has no Watching anime and no One Piece entry in that bucket, so the affected user's specific One Piece next marker remains unverified. The contradictory public One Piece catalog data was reproduced. Live anime writes were not attempted; anime request/response targeting remains covered by offline contract tests. A reversible live TV write and full summary reconciliation were verified.
- A successful zero-additions/no-not_found response is treated as the documented already-watched no-op; the response alone cannot prove account watch state. Authoritative summary reconciliation follows.
- Full refresh clears absent queue metadata but intentionally does not guess the title's new status or delete its whole library row. Existing status/deletion sync remains responsible for library membership.
- AX labels/actions and controls were checked, but a complete VoiceOver, Dynamic Type, contrast, or automated accessibility audit was not performed.
- Runtime coverage: iOS 27.0 and 18.5. Deployment target stays iOS 17; no iOS 17 runtime was installed. iPad, macOS, and visionOS interactions were not tested.
- SIMKL catalog data can still be wrong upstream. The app follows the per-user marker rather than deriving schedules from catalog flags or counts.
