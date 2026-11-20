//
//  RewatchSession.swift
//  simalytics
//

import Foundation

enum RewatchKind: String, Codable, CaseIterable, Sendable {
  case tv
  case anime

  /// The `/sync/all-items` type segment and its response key.
  var libraryKey: String { self == .tv ? "shows" : "anime" }
}

/// A watch coordinate inside a session. Anime uses SIMKL's absolute numbering
/// in season 1, the same coordinates the app writes for anime episodes.
struct RewatchEpisode: Codable, Hashable, Comparable, Sendable {
  let season: Int
  let episode: Int

  static func < (lhs: Self, rhs: Self) -> Bool {
    (lhs.season, lhs.episode) < (rhs.season, rhs.episode)
  }
}

struct RewatchNextEpisode: Codable, Equatable, Sendable {
  let season: Int
  let episode: Int
  let title: String?
  let date: String?
}

/// A regular catalog episode, in the coordinates rewatch sessions use.
struct RewatchCatalogEpisode: Equatable, Sendable {
  let season: Int
  let episode: Int
  let title: String?
  let date: String?
  let aired: Bool?

  init(season: Int, episode: Int, title: String?, date: String?, aired: Bool?) {
    self.season = season
    self.episode = episode
    self.title = title
    self.date = date
    self.aired = aired
  }

  /// Specials never count toward progress, matching SIMKL's next-to-watch rule.
  init?(show: ShowEpisodeModel) {
    guard show.type != "special", let season = show.season, season > 0,
      let episode = show.episode, episode > 0
    else { return nil }
    self.init(season: season, episode: episode, title: show.title, date: show.date, aired: show.aired)
  }

  init?(anime: AnimeEpisodeModel) {
    guard anime.type != "special", let episode = anime.episode, episode > 0 else { return nil }
    self.init(
      season: AnimeDetailView.watchlistSeason(for: anime), episode: episode, title: anime.title,
      date: anime.date, aired: anime.aired)
  }
}

/// The user's active rewatch of a title: a separate viewing with its own
/// episode progress, alongside the canonical (first) watch SIMKL keeps.
struct RewatchSession: Codable, Equatable, Identifiable, Sendable {
  /// SIMKL's `rewatch_id`. Every write for this session pins it.
  let id: Int
  let simkl: Int
  let kind: RewatchKind
  var title: String?
  var poster: String?
  var animeType: String?
  /// Sorted and unique.
  var episodes: [RewatchEpisode]
  var totalEpisodes: Int?
  var notAiredEpisodes: Int?
  var lastWatchedAt: String?
  /// Resolved from the title's catalog; nil when caught up or unresolved.
  var next: RewatchNextEpisode?
  /// When `next` was resolved. Nil asks the next sync to resolve it.
  var nextResolvedAt: Date?

  init(
    id: Int, simkl: Int, kind: RewatchKind, title: String? = nil, poster: String? = nil,
    animeType: String? = nil, episodes: [RewatchEpisode] = [], totalEpisodes: Int? = nil,
    notAiredEpisodes: Int? = nil, lastWatchedAt: String? = nil,
    next: RewatchNextEpisode? = nil, nextResolvedAt: Date? = nil
  ) {
    self.id = id
    self.simkl = simkl
    self.kind = kind
    self.title = title
    self.poster = poster
    self.animeType = animeType
    self.episodes = Array(Set(episodes)).sorted()
    self.totalEpisodes = totalEpisodes
    self.notAiredEpisodes = notAiredEpisodes
    self.lastWatchedAt = lastWatchedAt
    self.next = next
    self.nextResolvedAt = nextResolvedAt
  }

  /// Regular episodes logged in this session, like SIMKL's per-session count.
  var watchedCount: Int { episodes.lazy.filter { $0.season > 0 }.count }

  /// The session's progress in the shape the episode list reads.
  var watchlistSeasons: [WatchlistSeason] {
    Dictionary(grouping: episodes, by: \.season).keys.sorted().map { season in
      let numbers = episodes.filter { $0.season == season }.map(\.episode)
      return WatchlistSeason(
        number: season, episodes_total: nil, episodes_aired: nil, episodes_to_be_aired: nil,
        episodes_watched: numbers.count,
        episodes: numbers.map {
          WatchlistEpisode(number: $0, watched: true, aired: true, last_watched_at: nil)
        })
    }
  }

  /// Adds or removes one episode, and asks the next sync to re-resolve `next`.
  mutating func record(_ episode: RewatchEpisode, watched: Bool) {
    var updated = Set(episodes)
    if watched { updated.insert(episode) } else { updated.remove(episode) }
    episodes = updated.sorted()
    nextResolvedAt = nil
  }

  /// True after the next episode was logged but before a sync resolved the one
  /// after it. Up Next hides such a row, since logging it again within 2 days
  /// is a no-op on SIMKL.
  var isNextLogged: Bool {
    guard let next else { return false }
    return episodes.contains(RewatchEpisode(season: next.season, episode: next.episode))
  }
}

extension RewatchNextEpisode {
  /// A `next_to_watch`-style marker, so Up Next can treat it like SIMKL's own.
  func marker(for kind: RewatchKind) -> String {
    kind == .anime ? "E\(episode)" : String(format: "S%02dE%02d", season, episode)
  }
}

// MARK: - Reading sessions back

/// The session rows in one `allow_rewatch=yes&extended=full` response. A full
/// pull lists every session. A `date_from` delta lists only the rows that
/// changed, and never a deleted session; `RewatchMembership` covers those.
struct RewatchResponse: Equatable, Sendable {
  /// Active sessions, one per title; if SIMKL ever reports two, the newest wins.
  var sessions: [RewatchSession]
  /// Sessions the response reports as closed or completed.
  var endedIDs: Set<Int> = []
}

/// Every saved session of a type, from `allow_rewatch=yes&extended=simkl_ids_only`.
/// It carries no episodes, but it is the only read that shows a session was
/// deleted, and it counts each title's sessions for the 50-session cap.
struct RewatchMembership: Equatable, Sendable {
  /// Each saved session's title, by `rewatch_id`.
  var titles: [Int: Int]
  /// The `rewatch_id`s of active sessions.
  var activeIDs: Set<Int>

  /// Saved sessions of any status per title.
  var counts: [Int: Int] {
    titles.values.reduce(into: [:]) { counts, title in counts[title, default: 0] += 1 }
  }
}

extension RewatchSession {
  /// A malformed rewatch row fails the response, like the other library
  /// pulls, so the cursor stays put for a retry.
  static func response(from rows: [RewatchRowModel], kind: RewatchKind) throws -> RewatchResponse {
    var byTitle: [Int: RewatchSession] = [:]
    var ended = Set<Int>()
    for row in rows {
      guard let simkl = row.show?.ids?.simkl, simkl > 0 else {
        throw SimklMutationError.invalidResponse
      }
      // Canonical (first watch) rows carry no session data. A delta can list
      // one without its sessions, so it says nothing about them.
      guard row.is_rewatch == true else { continue }
      guard let id = row.rewatch_id, id > 0 else { throw SimklMutationError.invalidResponse }
      guard row.rewatch_status == "active" else {
        ended.insert(id)
        continue
      }
      if let existing = byTitle[simkl], existing.id > id { continue }
      let episodes = (row.seasons ?? []).flatMap { season -> [RewatchEpisode] in
        guard let number = season.number, number >= 0 else { return [] }
        return (season.episodes ?? []).compactMap { episode in
          guard let value = episode.number, value > 0 else { return nil }
          return RewatchEpisode(season: number, episode: value)
        }
      }
      byTitle[simkl] = RewatchSession(
        id: id, simkl: simkl, kind: kind, title: row.show?.title, poster: row.show?.poster,
        animeType: row.anime_type, episodes: episodes, totalEpisodes: row.total_episodes_count,
        notAiredEpisodes: row.not_aired_episodes_count, lastWatchedAt: row.last_watched_at)
    }
    return RewatchResponse(sessions: byTitle.values.sorted { $0.id < $1.id }, endedIDs: ended)
  }

  /// Every saved session in a `simkl_ids_only` response. Nil when SIMKL didn't
  /// apply `allow_rewatch` (no row says whether it is a rewatch), since the
  /// sessions are then unknown rather than gone.
  static func membership(from rows: [RewatchRowModel]) throws -> RewatchMembership? {
    guard rows.isEmpty || rows.contains(where: { $0.is_rewatch != nil }) else { return nil }
    var membership = RewatchMembership(titles: [:], activeIDs: [])
    for row in rows where row.is_rewatch == true {
      guard let simkl = row.show?.ids?.simkl, simkl > 0, let id = row.rewatch_id, id > 0,
        let status = row.rewatch_status, !status.isEmpty
      else { throw SimklMutationError.invalidResponse }
      membership.titles[id] = simkl
      if status == "active" { membership.activeIDs.insert(id) }
    }
    return membership
  }

  /// A full pull replaces every cached session of the type. A `date_from`
  /// delta lists only rows that changed, so it updates session by session:
  /// an active row replaces whatever the title had (there is one active
  /// session per title), and a closed or completed row drops that session.
  /// Sessions the delta didn't mention are kept.
  static func merged(
    cached: [RewatchSession], with response: RewatchResponse, isFullPull: Bool
  ) -> [RewatchSession] {
    let previous = Dictionary(cached.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    let incoming = response.sessions.map { $0.keepingResolution(from: previous[$0.id]) }
    let incomingTitles = Set(incoming.map(\.simkl))
    let kept =
      isFullPull
      ? []
      : cached.filter {
        !response.endedIDs.contains($0.id) && !incomingTitles.contains($0.simkl)
      }
    return (kept + incoming).sorted { $0.id < $1.id }
  }

  /// Drops cached sessions that SIMKL no longer lists as active, such as one
  /// deleted on simkl.com, which no delta reports. Also returns the active
  /// sessions the cache is missing.
  static func pruned(
    _ sessions: [RewatchSession], by membership: RewatchMembership
  ) -> (sessions: [RewatchSession], missingIDs: Set<Int>) {
    let kept = sessions.filter {
      membership.activeIDs.contains($0.id) && membership.titles[$0.id] == $0.simkl
    }
    return (kept, membership.activeIDs.subtracting(kept.map(\.id)))
  }

  /// Lands a pull that started from `base` on top of `current`. Episodes logged,
  /// or sessions started or stopped, while the pull was in flight keep their
  /// local copy; each of those writes queues another sync that confirms it.
  static func reconciled(
    pulled: [RewatchSession], base: [RewatchSession], current: [RewatchSession]
  ) -> [RewatchSession] {
    let baseByID = Dictionary(base.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    let localEdits = current.filter { baseByID[$0.id] != $0 }
    let localRemovals = Set(base.map(\.id)).subtracting(current.map(\.id))
    let editedTitles = Set(localEdits.map(\.simkl))
    let kept = pulled.filter { !localRemovals.contains($0.id) && !editedTitles.contains($0.simkl) }
    return (kept + localEdits).sorted { $0.id < $1.id }
  }

  /// Counts from a pull that started from `base`. A session started while the
  /// pull was in flight still counts toward the cap until the next sync.
  static func reconciledCounts(
    pulled: [Int: Int], base: [RewatchSession], current: [RewatchSession],
    currentCounts: [Int: Int]
  ) -> [Int: Int] {
    let baseIDs = Set(base.map(\.id))
    var counts = pulled
    for title in Set(current.filter { !baseIDs.contains($0.id) }.map(\.simkl)) {
      counts[title] = max(counts[title] ?? 0, currentCounts[title] ?? 0)
    }
    return counts
  }

  /// Reuses the cached next episode while the session's episodes are unchanged,
  /// so a sync only fetches a catalog when there is something new to resolve.
  private func keepingResolution(from cached: RewatchSession?) -> RewatchSession {
    guard let cached, cached.episodes == episodes, cached.nextResolvedAt != nil else {
      return self
    }
    var session = self
    session.next = cached.next
    session.nextResolvedAt = cached.nextResolvedAt
    return session
  }

  /// SIMKL's next-to-watch rule applied to one session: the first regular
  /// episode after the furthest one logged, in catalog order. Nil when the
  /// session has caught up, or the next episode hasn't aired and has no date.
  static func nextEpisode(
    after episodes: [RewatchEpisode], in catalog: [RewatchCatalogEpisode]
  ) -> RewatchNextEpisode? {
    var seen = Set<RewatchEpisode>()
    let regular =
      catalog
      .filter { $0.season > 0 && $0.episode > 0 }
      .sorted { ($0.season, $0.episode) < ($1.season, $1.episode) }
      .filter { seen.insert(RewatchEpisode(season: $0.season, episode: $0.episode)).inserted }
    let watched = Set(episodes)
    let start =
      regular.lastIndex { watched.contains(RewatchEpisode(season: $0.season, episode: $0.episode)) }
      .map { $0 + 1 } ?? 0
    guard start < regular.count else { return nil }
    let candidate = regular[start]
    if candidate.aired == false, candidate.date == nil { return nil }
    return RewatchNextEpisode(
      season: candidate.season, episode: candidate.episode, title: candidate.title,
      date: candidate.date)
  }
}
