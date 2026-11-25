import Foundation
import SwiftData

@testable import Simalytics

// Requests no longer take a token: `SimklSession` attaches the signed-in
// credential as each one is sent. These adapters keep the contract tests'
// scenario-as-token calls readable by binding a session for each call.

extension RewatchMutation {
  static func markEpisodeWatched(
    _ token: String, _ rewatch: RewatchSession, _ episode: RewatchEpisode, session: URLSession
  ) async -> RewatchLogResult {
    await withSimklToken(token) { await markEpisodeWatched(rewatch, episode, session: session) }
  }

  static func markEpisodeUnwatched(
    _ token: String, _ rewatch: RewatchSession, _ episode: RewatchEpisode, session: URLSession
  ) async -> RewatchRemovalResult {
    await withSimklToken(token) { await markEpisodeUnwatched(rewatch, episode, session: session) }
  }

  static func logMovie(_ token: String, simkl: Int, title: String?, session: URLSession) async
    -> MovieRewatchLogResult
  {
    await withSimklToken(token) { await logMovie(simkl: simkl, title: title, session: session) }
  }

  static func removeMovieRewatch(
    _ token: String, simkl: Int, rewatchID: Int, session: URLSession
  ) async -> MovieRewatchRemovalResult {
    await withSimklToken(token) {
      await removeMovieRewatch(simkl: simkl, rewatchID: rewatchID, session: session)
    }
  }

  static func start(
    _ token: String, simkl: Int, kind: RewatchKind, title: String?, session: URLSession
  ) async -> RewatchStartResult {
    await withSimklToken(token) {
      await start(simkl: simkl, kind: kind, title: title, session: session)
    }
  }

  static func stop(_ token: String, _ rewatch: RewatchSession, session: URLSession) async
    -> SimklMutationResult
  {
    await withSimklToken(token) { await stop(rewatch, session: session) }
  }
}

extension ShowDetailView {
  static func markEpisodeWatched(
    _ token: String, _ title: String, _ simklId: Int, _ season: Int, _ episode: Int,
    session: URLSession
  ) async -> SimklMutationResult {
    await withSimklToken(token) {
      await markEpisodeWatched(title, simklId, season, episode, session: session)
    }
  }

  static func markEpisodeUnwatched(
    _ token: String, _ title: String, _ simklId: Int, _ season: Int, _ episode: Int,
    session: URLSession
  ) async -> SimklMutationResult {
    await withSimklToken(token) {
      await markEpisodeUnwatched(title, simklId, season, episode, session: session)
    }
  }
}

extension AnimeDetailView {
  static func markEpisodeWatched(
    _ token: String, _ title: String, _ simklId: Int, _ season: Int, _ episode: Int,
    session: URLSession
  ) async -> SimklMutationResult {
    await withSimklToken(token) {
      await markEpisodeWatched(title, simklId, season, episode, session: session)
    }
  }

  static func markEpisodeUnwatched(
    _ token: String, _ title: String, _ simklId: Int, _ season: Int, _ episode: Int,
    session: URLSession
  ) async -> SimklMutationResult {
    await withSimklToken(token) {
      await markEpisodeUnwatched(title, simklId, season, episode, session: session)
    }
  }
}

extension MovieWatchlistButton {
  static func updateMovieList(_ simklID: Int, _ token: String, _ list: String, session: URLSession)
    async -> String?
  {
    await withSimklToken(token) { await updateMovieList(simklID, list, session: session) }
  }
}

extension ShowWatchlistButton {
  static func updateShowList(_ simklID: Int, _ token: String, _ list: String, session: URLSession)
    async -> String?
  {
    await withSimklToken(token) { await updateShowList(simklID, list, session: session) }
  }
}

extension AnimeWatchlistButton {
  static func updateAnimeList(_ simklID: Int, _ token: String, _ list: String, session: URLSession)
    async -> String?
  {
    await withSimklToken(token) { await updateAnimeList(simklID, list, session: session) }
  }
}

extension DiscoverLibrary {
  func addToPlanToWatch(_ item: DiscoverItem, accessToken: String, session: URLSession) async
    -> Outcome
  {
    await withSimklToken(accessToken) { await addToPlanToWatch(item, session: session) }
  }

  func removeFromPlanToWatch(_ item: DiscoverItem, accessToken: String, session: URLSession)
    async -> Outcome
  {
    await withSimklToken(accessToken) { await removeFromPlanToWatch(item, session: session) }
  }
}

func setSimklRating(
  simklID: Int, type: RatingMediaType, rating: Int, accessToken: String, session: URLSession
) async -> SimklMutationResult {
  await withSimklToken(accessToken) {
    await setSimklRating(simklID: simklID, type: type, rating: rating, session: session)
  }
}

func fetchSimklAccountType(_ token: String, session: URLSession) async throws -> String {
  try await withSimklToken(token) { try await fetchSimklAccountType(session: session) }
}

func fetchMovieRewatchIDs(accessToken: String, session: URLSession) async throws -> [Int: [Int]]?
{
  try await withSimklToken(accessToken) { try await fetchMovieRewatchIDs(session: session) }
}

func pullRewatchSessions(
  _ kind: RewatchKind, accessToken: String, activity: String?, cached: [RewatchSession],
  cachedCounts: [Int: Int], cursor: RewatchStore.Cursor, refreshUpNext: Bool,
  session: URLSession, now: Date
) async throws -> RewatchPull? {
  try await withSimklToken(accessToken) {
    try await pullRewatchSessions(
      kind, activity: activity, cached: cached, cachedCounts: cachedCounts, cursor: cursor,
      refreshUpNext: refreshUpNext, session: session, now: now)
  }
}

func fetchAndStoreTVWatching(
  _ token: String, _ lastActivity: String?, _ context: ModelContext, forceRefresh: Bool = false,
  session: URLSession
) async -> Bool {
  await withSimklToken(token) {
    await fetchAndStoreTVWatching(
      lastActivity, context, forceRefresh: forceRefresh, session: session)
  }
}

func fetchAndStoreAnimeWatching(
  _ token: String, _ lastActivity: String?, _ context: ModelContext, forceRefresh: Bool = false,
  session: URLSession
) async -> Bool {
  await withSimklToken(token) {
    await fetchAndStoreAnimeWatching(
      lastActivity, context, forceRefresh: forceRefresh, session: session)
  }
}

func fetchAndStoreMoviesRemovedFromList(
  _ token: String, _ lastActivity: String?, _ context: ModelContext, session: URLSession
) async {
  await withSimklToken(token) {
    await fetchAndStoreMoviesRemovedFromList(lastActivity, context, session: session)
  }
}

func fetchAndStoreTVRemovedFromList(
  _ token: String, _ lastActivity: String?, _ context: ModelContext, session: URLSession
) async {
  await withSimklToken(token) {
    await fetchAndStoreTVRemovedFromList(lastActivity, context, session: session)
  }
}

func fetchAndStoreAnimeRemovedFromList(
  _ token: String, _ lastActivity: String?, _ context: ModelContext, session: URLSession
) async {
  await withSimklToken(token) {
    await fetchAndStoreAnimeRemovedFromList(lastActivity, context, session: session)
  }
}

func fetchAndStoreMoviesPlanToWatch(
  _ token: String, _ lastActivity: String?, _ context: ModelContext, session: URLSession
) async {
  await withSimklToken(token) {
    await fetchAndStoreMoviesPlanToWatch(lastActivity, context, session: session)
  }
}

/// The account a test sync writes for doesn't matter to these contracts, only
/// the scenario its requests carry.
func syncRewatchSessions(
  _ token: String, activities: LastActivitiesModel, refreshUpNext: Bool, store: RewatchStore,
  session: URLSession
) async {
  await withSimklToken(token) {
    await syncRewatchSessions(
      UUID(), activities: activities, refreshUpNext: refreshUpNext, store: store,
      session: session)
  }
}
