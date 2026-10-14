# Sentry review — October 12, 2026

## Scope and method

Reviewed `kyter/simalytics-ios` using the **`sentry` CLI** and its existing, verified Kyter OAuth session. The separate `sentry-cli` build-upload credential was not changed. No new token, issue comment, resolution, archive, alert change, or release was created.

Queried all statuses over 90 days and retrieved every available event for the 16 returned issues: **191 events**, with no remaining event pages. All 16 also had activity in the last 30 days; explicit resolved and ignored queries returned zero issues in this window. Counts below are for the queried window, not lifetime totals. This does not establish that every historical issue is fixed.

Classification uses event stacks, simulator/build contexts, releases, timestamps, and the current implementation. An environment tag alone was unreliable: every retrieved event was labeled `production`, including tests. Raw event payloads, installation identifiers, private paths, and account data are excluded from this report.

## Testing and local development

| Issue | Events | Evidence and disposition |
| --- | ---: | --- |
| [IOS-19](https://kyter.sentry.io/issues/7773341592/) | 13 | Simulator queue assertions in 1.0.15 (134), with `simalyticsTests` in the crashing stack. These were real crashes during tests, not evidence of customer crashes. Current regression suites pass; retain actor-isolation coverage rather than claiming the original unsymbolicated application frame was conclusively identified. |
| [IOS-1A](https://kyter.sentry.io/issues/7773341839/) | 1 | Same test-only context, with a `Sequence.contains` actor assertion. No subsequent occurrence in the queried data. Same disposition as IOS-19. |
| [IOS-1C](https://kyter.sentry.io/issues/7786917728/) | 12 | Rejected episode acknowledgements. Every event has XCTest infrastructure in its stack. The contract tests deliberately exercise this failure. |
| [IOS-1D](https://kyter.sentry.io/issues/7786917730/) | 60 | Invalid mutation acknowledgements. 31 events include XCTest in their stacks; the other 29 came from the same simulator installations within two seconds of a confirmed test event. This matches the malformed-response cases in the tests. |
| [IOS-1E](https://kyter.sentry.io/issues/7786919206/) | 7 | Injected HTTP 401 failures: two events have XCTest stacks and five coincide with confirmed tests on the same simulator installation within two seconds. This does not justify suppressing real authentication failures. |
| [IOS-1G](https://kyter.sentry.io/issues/7788979233/) | 9 | Rejected media acknowledgements: six events have XCTest stacks, and three have the same close test correlation. Matches rating/removal rejection fixtures. |
| [IOS-1J](https://kyter.sentry.io/issues/7788992969/) | 8 | Malformed JSON on simulators, all within two seconds of confirmed test events on the same installation. Strongly attributable to the malformed-response fixtures; the sampled asynchronous stacks alone do not prove the specific test method. |
| [IOS-1B](https://kyter.sentry.io/issues/7786889329/) | 2 | Invalid JSON in 1.0.16 (137), simulator only. No close confirmed test event or test frame in the available evidence. Treat as an unclassified development failure, not a proven harmless test or a customer incident. |
| [IOS-1H](https://kyter.sentry.io/issues/7788987736/) | 1 | Simulator Photos callback → app → Swift executor check → dispatch assertion. Timestamp and stack match the poster-save crash reproduced during this review. The explicit `@Sendable` Photos change callback is already fixed in this patch, and saving was repeated successfully. This was a real defect found through manual testing. |

The first seven rows account for 110 testing-related events: 65 directly contain test infrastructure and 45 are strongly correlated by installation and time. The remaining two simulator JSON failures are deliberately kept separate.

## Implemented observability fix

`TelemetryConfiguration` now prevents Sentry initialization in hosted XCTest/Swift Testing processes, previews, and the DEBUG screenshot fixture mode. This stops intentional fault fixtures, test crashes, sessions, and traces from entering project metrics. A hosted integration assertion checks the SDK itself is disabled, not just a configuration Boolean.

Ordinary simulator runs remain observable under `simulator`, Debug device runs under `debug`, and device Release builds use an explicit deployment environment or fall back to `production`. A screenshot environment variable cannot disable a Release build. Genuine release decoding, authentication, storage, and crash events remain visible.

The existing request-header redaction callback is also explicitly `@Sendable` so SDK processing does not inherit the SwiftUI app initializer's main-actor isolation. Its redaction behavior is unchanged.

The built Debug app's Info.plist contained neither custom Sentry key despite the project's `INFOPLIST_KEY_SENTRY_*` settings. Previously, the fallback DSN started Sentry while its unspecified environment defaulted to production. The new policy derives safe local defaults from the build and target rather than depending on those generated keys being present. Existing DSN behavior and release naming are retained.

## Real-device findings and fixes

| Issue | Events | Finding and next action |
| --- | ---: | --- |
| [IOS-1F](https://kyter.sentry.io/issues/7787067779/) | 1 | **Latest-build follow-up:** MetricKit reports a 1.027-second hang on a physical device running 1.0.17 (139), iOS 27.0.1. The event contains system keyboard/XPC and filesystem stacks; the only named app frames are entry points. Keep open. Profile launch, search keyboard transitions, and tab navigation on a physical device with a large library. Store opening and the Lists status counts now run off the UI actor, and Explore shelves are lazy. These reduce identifiable launch/tab work; the payload still does not isolate the keyboard hang to an application method. No connected physical device was available for profiling. |
| [IOS-18](https://kyter.sentry.io/issues/7773168969/) | 1 | MetricKit 1.419-second hang on physical iOS 18.5, release 1.0.15 (134). SwiftUI/AttributeGraph and Core Animation work appear in the diagnostic; no actionable named app function beyond entry points. The same launch/count/shelf improvements apply here. Simulator tests pass on iOS 18.5, but a physical-device profiling pass is still required. |
| [IOS-Y](https://kyter.sentry.io/issues/7599385538/) | 4 | Physical-device 1.0.15 hangs, including a 2.4–3.2-second tab/list graph update in the latest event. Current image downsampling, removal of per-cell fades, and local media snapshots are relevant mitigations, but recurrence in build 134 means they are not proof of resolution. This patch also removes 13 synchronous main-actor count queries from Lists and avoids eagerly building all trending poster cells. Check large-list tab changes on a physical device before closing. |
| [IOS-S](https://kyter.sentry.io/issues/7597082725/) | 1 | Physical-device sync encountered SQLite code 13 (`SQLITE_FULL`) while saving anime Plan to Watch data. This is a real storage-capacity failure. Do not silently delete the database or hide the error. Implemented a recoverable storage alert, rollback of unsaved data and sync cursors, and attempt-scoped cancellation of remaining sync sections and queued automatic retries. Explicit retry starts a fresh attempt after capacity is available. Fault-injection tests cover these paths. |
| [IOS-W](https://kyter.sentry.io/issues/7598677488/) | 11 | The same installation and timestamp as IOS-S produced database-open errors across sync buckets. Underlying SQLite 4618 is `SQLITE_IOERR_SHMOPEN`. The shared incident strongly suggests a storage-related cascade, but does not prove every open failure is caused by disk capacity. Wrapped SQLite/POSIX errors are now classified, with shared-memory/open failures reported as unavailable storage rather than assuming disk-full. The first storage failure stops the sync cascade. Store-opening failures now offer a retry screen instead of terminating the app; the database is never deleted automatically. The existing 500 MB image-cache cap cannot guarantee available device storage. |
| [IOS-17](https://kyter.sentry.io/issues/7744185461/) | 2 | Physical iOS 27 device, 1.0.15 (134), `NSURLErrorDomain -1008` while fetching TV episodes. No HTTP response evidence establishes an API schema regression. GET requests now retry this transient error with the existing bounded backoff; POST retry behavior is unchanged. TV/anime episode methods propagate final failures, and detail screens show a retry action while preserving any already-loaded episodes. Fault tests verify retry boundaries and malformed JSON propagation; the simulator retry button successfully reloaded fixture episodes. Final failures remain observable. |
| [IOS-3](https://kyter.sentry.io/issues/7431031238/) | 58 | Image proxy performance detector, mostly 1.0.15 (134), with three events on 1.0.16 (136). The latest flagged transaction contains **10 different poster URLs**, all overlapping in time. Sentry groups them by `https://wsrv.nl/?url=*`; this sample does not demonstrate repeated fetches of one resource or serial N+1 backend work. Treat as poster-loading performance, not an established API bug. Explore now uses lazy vertical/horizontal shelves, with a Dynamic Type-aware row height, to limit eager offscreen poster construction. Normal and largest-text layouts and horizontal scrolling were checked on the simulator. This is a rendering mitigation; production detector recurrence/cache misses still need release monitoring. |

SQLite code meanings are from the [official SQLite result-code reference](https://www.sqlite.org/rescode.html). The correlation of the two storage issues and the testing events is an inference from the retrieved evidence, not a server-side diagnosis.

The latest real-device hang is not dismissed as testing. Production MetricKit payloads include partial/missing system information; local simulator events also include missing local dSYMs. The inspected production stacks have named application entry points, so these observations alone do not establish a broken Xcode Cloud symbol-upload pipeline. Confirm matching dSYMs on the next Cloud build through the existing post-build log.

## Additional data-integrity fixes

All library bucket reads now validate HTTP responses and typed list shapes before applying changes. Rejected, malformed, or invalid-ID responses leave persisted rows and last-sync cursors intact. This prevents a failed full-list read from being interpreted as an empty library and deleting local titles. The documented empty object and observed HTTP-200 `null` remain supported; tests cover those and empty arrays separately from failures for all three media categories.

Sync contexts disable autosave and commit data with its cursor in one save. A failed save rolls back both. A per-attempt task-local monitor propagates storage failures through child tasks, records the original failure once, aborts remaining work, and does not poison a later retry. Cancellation also discards queued attempts. Ordinary network/schema failures retain the affected cursor while allowing unrelated library sections to proceed. Trending refresh failures preserve the cached shelves instead of replacing them with empty arrays.

The loading indicator counts overlapping operations, so an early-finishing request cannot hide an ongoing sync or prematurely enable the local reset action.

## Validation and release considerations

- iOS 27 full suite: 111 definitions / 238 executions passed, zero failures, skips, or runtime warnings.
- iOS 18.5 full suite: 111 definitions / 238 executions passed, zero failures, skips, or runtime warnings. Coverage includes storage classification, rollback, startup retry, cancellation, sync coalescing, background counts, read retries, valid/empty reconciliation, rejected-response preservation, and hosted telemetry isolation.
- A fresh Sentry query after the earlier telemetry-isolation run returned unchanged issue counts, consistent with the SDK-disabled assertion.
- Strict formatting passed for the new source and tests.
- Final Release simulator build passed for arm64 and x86_64. `npm run release:check` and `git diff --check` passed; version 1.0.17 (139) remains unchanged.
- iOS 27 simulator: opening failure → Try Again → populated Lists; sync-storage alert → Try Again → Lists; episode error → Try Again → episode row. These used temporary offline fault fixtures, removed before final builds. No real disk was filled and no user database was removed.
- The final Release app opened its on-disk store successfully and reached the signed-out Up Next screen.
- Explore horizontal scrolling, largest accessibility text, Lists counts, and search focus were exercised. This is simulator interaction evidence, not a physical-device performance measurement.

The telemetry changes apply only after installing a build containing them. Old simulator installations can continue sending events labeled production. When reviewing the next release, combine release, environment, and simulator/build context rather than filtering historical data solely by `environment:production`.

No Sentry issues were resolved or archived. Photos, telemetry separation, storage recovery, safer read handling, and rendering improvements are implemented locally. Physical-device hang root causes and production recurrence remain unverified; keep those issues open through device profiling and release monitoring. Nothing in this report claims a successful production release.
