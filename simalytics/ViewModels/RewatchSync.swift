//
//  RewatchSync.swift
//  simalytics
//

import Foundation

/// One type's sessions after a pull, ready for `RewatchStore.apply`.
struct RewatchPull: Sendable {
  var sessions: [RewatchSession]
  var sessionCounts: [Int: Int]
  var cursor: RewatchStore.Cursor
}

/// Pulls active rewatch sessions for an account that turned on Track Rewatches.
/// Runs inside `syncLatestActivities`, after the regular library buckets.
///
/// SIMKL only reports rewatches with `?allow_rewatch=yes`, and only for PRO /
/// VIP plans. The plan comes from `/users/settings` once and is re-read only
/// when `settings.all` moves. Sessions come from `/sync/all-items` with
/// `extended=full` (without it, rewatch rows carry no episodes): one full pull,
/// then `date_from` deltas whenever the type's `all` activity moves, as SIMKL
/// asks. A delta returns each changed title with every session it still has,
/// so a session deleted on simkl.com drops out without another full pull.
/// See https://api.simkl.org/guides/rewatches
func syncRewatchSessions(
  _ accessToken: String,
  activities: LastActivitiesModel,
  refreshUpNext: Bool,
  store: RewatchStore? = nil,
  session: URLSession = .shared,
  now: Date = Date()
) async {
  let shared = await RewatchStore.shared
  let store = store ?? shared
  guard await store.isTrackingEnabled else { return }

  do {
    var state = await store.state
    let settingsActivity = activities.settings?.all
    if state.accountType == nil
      || (settingsActivity != nil && settingsActivity != state.settingsActivity)
    {
      let accountType = try await fetchSimklAccountType(accessToken, session: session)
      try await SyncFailureScope.check()
      await store.updatePlan(
        accountType, settingsActivity: settingsActivity, accessToken: accessToken)
      state = await store.state
    }
    guard state.isPlanEligible else {
      // A downgrade turns the switch off, as SIMKL recommends; Settings
      // explains why if they try to turn it back on.
      await store.disableTracking()
      return
    }

    for kind in RewatchKind.allCases {
      try await SyncFailureScope.check()
      let activity = kind == .tv ? activities.tv_shows?.all : activities.anime?.all
      let base = state.sessions.filter { $0.kind == kind }
      let pull = try await pullRewatchSessions(
        kind, accessToken: accessToken, activity: activity, cached: base,
        cachedCounts: state.sessionCounts(for: kind), cursor: state.cursor(for: kind),
        refreshUpNext: refreshUpNext, session: session, now: now)
      guard let pull else { continue }
      try await SyncFailureScope.check()
      await store.apply(pull, kind: kind, base: base, accessToken: accessToken)
    }
  } catch {
    await SyncFailureScope.report(error)
  }
}

/// Nil when nothing changed: no pull was due and every next episode is known.
func pullRewatchSessions(
  _ kind: RewatchKind,
  accessToken: String,
  activity: String?,
  cached: [RewatchSession],
  cachedCounts: [Int: Int],
  cursor: RewatchStore.Cursor,
  refreshUpNext: Bool,
  session: URLSession,
  now: Date
) async throws -> RewatchPull? {
  let needsBaseline = cursor.baselineAt == nil
  let shouldPull =
    needsBaseline || refreshUpNext || (activity != nil && activity != cursor.activity)
  guard shouldPull || cached.contains(where: { $0.nextResolvedAt == nil }) else { return nil }

  var pull = RewatchPull(sessions: cached, sessionCounts: cachedCounts, cursor: cursor)
  if shouldPull {
    // Deltas start 5 minutes early, like the other library pulls.
    let formatter = ISO8601DateFormatter()
    let anchor = cursor.activity.flatMap(formatter.date(from:)) ?? cursor.baselineAt
    let dateFrom =
      needsBaseline ? nil : anchor.map { formatter.string(from: $0.addingTimeInterval(-5 * 60)) }
    let rows = try await fetchRewatchRows(
      kind, dateFrom: dateFrom, accessToken: accessToken, session: session)
    let response = try RewatchSession.response(from: rows, kind: kind)
    pull.sessions = RewatchSession.merged(
      cached: cached, with: response, isFullPull: dateFrom == nil)
    pull.sessionCounts = RewatchSession.mergedCounts(
      cached: cachedCounts, with: response, isFullPull: dateFrom == nil)
    pull.cursor.activity = activity ?? cursor.activity
    if needsBaseline { pull.cursor.baselineAt = now }
  }
  var sessions = pull.sessions

  // Rewatch rows carry no next-episode marker, so resolve it from the title's
  // catalog. A transient failure leaves it for the next sync to retry; any
  // other leaves the title without a next episode until its session changes.
  for index in sessions.indices where sessions[index].nextResolvedAt == nil {
    try await SyncFailureScope.check()
    do {
      let catalog = try await rewatchCatalog(for: sessions[index], session: session)
      sessions[index].next = RewatchSession.nextEpisode(
        after: sessions[index].episodes, in: catalog)
      sessions[index].nextResolvedAt = now
    } catch {
      if isSimklCancellationError(error) { throw error }
      await SyncFailureScope.report(error)
      if !((error as? SimklMutationError)?.isRetryable ?? (error is URLError)) {
        sessions[index].next = nil
        sessions[index].nextResolvedAt = now
      }
    }
  }
  pull.sessions = sessions
  return pull
}

func fetchRewatchRows(
  _ kind: RewatchKind, dateFrom: String?, accessToken: String, session: URLSession = .shared
) async throws -> [RewatchRowModel] {
  var queryItems = [
    URLQueryItem(name: "allow_rewatch", value: "yes"),
    URLQueryItem(name: "extended", value: "full"),
  ]
  if let dateFrom { queryItems.append(URLQueryItem(name: "date_from", value: dateFrom)) }
  var request = URLRequest(
    url: simklAPIURL(path: "sync/all-items/\(kind.libraryKey)", queryItems: queryItems))
  request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
  let (data, _) = try await performSimklRequest(request, session: session)
  return try decodeSimklLibraryResponse(RewatchRowModel.self, from: data, key: kind.libraryKey)
}

/// `free`, `pro`, or `vip`. A missing plan reads as `free`, which turns rewatches off.
func fetchSimklAccountType(_ accessToken: String, session: URLSession = .shared) async throws
  -> String
{
  var request = URLRequest(url: simklAPIURL(path: "users/settings"))
  request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
  let (data, _) = try await performSimklRequest(request, session: session)
  do {
    let settings = try JSONDecoder().decode(SimklUserSettingsModel.self, from: data)
    return settings.account?.type?.lowercased() ?? "free"
  } catch {
    throw SimklMutationError.invalidResponse
  }
}

private func rewatchCatalog(for rewatch: RewatchSession, session: URLSession) async throws
  -> [RewatchCatalogEpisode]
{
  switch rewatch.kind {
  case .tv:
    return try await ShowDetailView.getShowEpisodes(rewatch.simkl, session: session)
      .compactMap(RewatchCatalogEpisode.init(show:))
  case .anime:
    return try await AnimeDetailView.getAnimeEpisodes(rewatch.simkl, session: session)
      .compactMap(RewatchCatalogEpisode.init(anime:))
  }
}
