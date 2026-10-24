//
//  DiscoverLibrary.swift
//  simalytics
//

import Foundation
import Observation
import SwiftData

/// The user's library as Explore sees it: every title's list status and
/// rating, keyed like `DiscoverItem.id`. It loads off the main actor and
/// reloads whenever a sync or rating changes SwiftData, so poster badges, the
/// hide-library switch, and For You agree. A quick change from a long press
/// shows at once, then gives way to the synced copy.
@MainActor @Observable
final class DiscoverLibrary {
  static let shared = DiscoverLibrary()

  struct Entry: Hashable, Sendable {
    let status: String?
    let rating: Int?
  }

  /// The library as plain values, for building Explore's lists.
  struct Contents: Sendable {
    var entries: [String: Entry] = [:]
    /// Bumps whenever `entries` changes, so lists can be cached per library.
    var revision = 0
  }

  /// A quick add or removal the next sync hasn't confirmed yet.
  enum Pending: Hashable, Sendable {
    case added
    case removed
  }

  /// What a quick change did.
  enum Outcome: Equatable, Sendable {
    case added
    case removed
    /// Simkl has the title on this list, so it was left alone.
    case alreadyListed(String)
    case failed(String)
  }

  private(set) var contents = Contents()
  private(set) var pending: [String: Pending] = [:]
  /// Titles with a quick change on its way to Simkl.
  private(set) var updating: Set<String> = []

  @ObservationIgnored private var container: ModelContainer?
  @ObservationIgnored private var reloadTask: Task<Void, Never>?
  @ObservationIgnored private var observer: (any NSObjectProtocol)?

  /// Starts loading from `container` and following changes to the library.
  /// Safe to call on every appearance.
  func start(container: ModelContainer) {
    guard self.container == nil else { return }
    self.container = container
    observer = NotificationCenter.default.addObserver(
      forName: .localMediaSnapshotsDidChange, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.reload() }
    }
    reload()
  }

  /// Quick changes belong to the account that made them.
  func accountChanged() {
    pending = [:]
    reload()
  }

  /// The list a title is on, counting quick changes Simkl hasn't synced back.
  func status(of item: DiscoverItem) -> String? {
    switch pending[item.id] {
    case .added: "plantowatch"
    case .removed: nil
    case nil: contents.entries[item.id]?.status
    }
  }

  /// Whether the synced library has the title on any list. Hiding goes by
  /// this, so a quick add doesn't make a poster vanish under your finger.
  func isInLibrary(_ item: DiscoverItem) -> Bool {
    contents.entries[item.id]?.status != nil
  }

  /// Reads the library again, off the main actor.
  func reload() {
    guard let container else { return }
    reloadTask?.cancel()
    reloadTask = Task {
      let entries = await Task.detached(priority: .userInitiated) {
        Self.fetchEntries(in: container)
      }.value
      guard !Task.isCancelled, let entries else { return }
      apply(entries)
    }
  }

  func apply(_ entries: [String: Entry]) {
    if entries != contents.entries {
      contents = Contents(entries: entries, revision: contents.revision + 1)
    }
    // The synced copy speaks for any quick change it now reflects.
    let unconfirmed = pending.filter { id, change in
      switch change {
      case .added: entries[id]?.status == nil
      case .removed: entries[id]?.status != nil
      }
    }
    if unconfirmed != pending { pending = unconfirmed }
  }

  /// Every title's status and rating, read through a context of its own.
  nonisolated static func fetchEntries(in container: ModelContainer) -> [String: Entry]? {
    let context = ModelContext(container)
    do {
      var entries: [String: Entry] = [:]
      var movies = FetchDescriptor<V1.SDMovies>()
      movies.propertiesToFetch = [\.simkl, \.status, \.user_rating]
      for movie in try context.fetch(movies) {
        entries[DiscoverItem.id(.movies, movie.simkl)] = Entry(
          status: movie.status, rating: movie.user_rating)
      }
      var shows = FetchDescriptor<V1.SDShows>()
      shows.propertiesToFetch = [\.simkl, \.status, \.user_rating]
      for show in try context.fetch(shows) {
        entries[DiscoverItem.id(.shows, show.simkl)] = Entry(
          status: show.status, rating: show.user_rating)
      }
      var animes = FetchDescriptor<V1.SDAnimes>()
      animes.propertiesToFetch = [\.simkl, \.status, \.user_rating]
      for anime in try context.fetch(animes) {
        entries[DiscoverItem.id(.anime, anime.simkl)] = Entry(
          status: anime.status, rating: anime.user_rating)
      }
      return entries
    } catch {
      reportError(error)
      return nil
    }
  }

  // MARK: Quick changes

  /// Adds a title to Plan to Watch. Simkl is asked first, so a title already
  /// on a list (say, Completed) is never moved.
  func addToPlanToWatch(
    _ item: DiscoverItem, accessToken: String, session: URLSession = .shared
  ) async -> Outcome {
    await change(item, adding: true, accessToken: accessToken, session: session)
  }

  /// Takes a title off Plan to Watch. Simkl is asked first because removal
  /// also clears history, which a title you've started must keep.
  func removeFromPlanToWatch(
    _ item: DiscoverItem, accessToken: String, session: URLSession = .shared
  ) async -> Outcome {
    await change(item, adding: false, accessToken: accessToken, session: session)
  }

  private func change(
    _ item: DiscoverItem, adding: Bool, accessToken: String, session: URLSession
  ) async -> Outcome {
    guard !updating.contains(item.id) else { return adding ? .added : .removed }
    let previous = pending[item.id]
    pending[item.id] = adding ? .added : .removed
    #if DEBUG
      // Screenshot mode is offline; the badge alone shows the change.
      if ScreenshotMode.isActive { return adding ? .added : .removed }
    #endif
    updating.insert(item.id)
    defer { updating.remove(item.id) }

    guard let current = await Self.list(of: item, accessToken: accessToken, session: session)
    else {
      pending[item.id] = previous
      return .failed("Couldn’t reach Simkl. Check your connection and try again.")
    }
    switch (adding, current) {
    case (true, nil), (false, .some("plantowatch")):
      break
    case (true, .some("plantowatch")):
      // Already there; the sync will bring the local copy up to date.
      syncSoon(accessToken)
      return .alreadyListed("plantowatch")
    case (false, nil):
      syncSoon(accessToken)
      return .removed
    case (_, let list?):
      pending[item.id] = previous
      syncSoon(accessToken)
      return .alreadyListed(list)
    }

    if let message = await Self.updateList(
      item, to: adding ? "plantowatch" : "nil", accessToken: accessToken, session: session)
    {
      pending[item.id] = previous
      return .failed(message)
    }
    syncSoon(accessToken)
    return adding ? .added : .removed
  }

  /// Pulls the change into SwiftData; its notification then reloads entries.
  private func syncSoon(_ accessToken: String) {
    guard let container else { return }
    Task { await syncLatestActivities(accessToken, modelContainer: container) }
  }

  /// The list Simkl has a title on: nil inside means none, and nil overall
  /// means Simkl couldn't be asked.
  private static func list(
    of item: DiscoverItem, accessToken: String, session: URLSession
  ) async -> String?? {
    let type =
      switch item.type {
      case .movies: "movie"
      case .shows: "show"
      case .anime: "anime"
      }
    let batch: SimklWatchedBatch<WatchedList> = await simklWatchedBatch(
      simklIDs: [item.simklID], type: type, accessToken: accessToken, session: session)
    guard !batch.hadFailures else { return nil }
    return .some(batch.items.first?.list)
  }

  private static func updateList(
    _ item: DiscoverItem, to list: String, accessToken: String, session: URLSession
  ) async -> String? {
    switch item.type {
    case .movies:
      await MovieWatchlistButton.updateMovieList(item.simklID, accessToken, list, session: session)
    case .shows:
      await ShowWatchlistButton.updateShowList(item.simklID, accessToken, list, session: session)
    case .anime:
      await AnimeWatchlistButton.updateAnimeList(item.simklID, accessToken, list, session: session)
    }
  }

  nonisolated static func listName(_ status: String) -> String {
    switch status {
    case "plantowatch": "Plan to Watch"
    case "watching": "Watching"
    case "completed": "Completed"
    case "hold": "On Hold"
    case "dropped": "Dropped"
    default: status.capitalized
    }
  }
}

/// The one field a quick change needs from `/sync/watched`.
private struct WatchedList: Decodable, Sendable {
  let list: String?
}
