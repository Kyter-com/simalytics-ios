//
//  DiscoverStore.swift
//  simalytics
//

import Foundation
import Observation

/// One of Simkl's prebuilt discovery files on data.simkl.in. They're free:
/// no token, and they don't count against the app's rate limit.
enum DiscoverSource: Hashable, Sendable {
  /// Today's most watched movies, shows, and anime in one file.
  case today
  /// The 500 most watched titles of a type over the last 30 days.
  case pool(DiscoverMediaType)
  case genreIndex(DiscoverMediaType)
  /// A genre's 30-day most watched titles, fetched when its page opens.
  case genre(DiscoverMediaType, slug: String)

  var path: String {
    switch self {
    case .today: "trending/today_100.json"
    case .pool(let type): "trending/\(type.rawValue)/month_500.json"
    case .genreIndex(let type): "trending/\(type.rawValue)/genre/index.json"
    case .genre(let type, let slug): "trending/\(type.rawValue)/genre/\(slug)_month_500.json"
    }
  }

  /// Simkl regenerates the today file hourly and the others daily.
  var maxAge: TimeInterval { self == .today ? 60 * 60 : 24 * 60 * 60 }

  var url: URL {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "data.simkl.in"
    components.path = "/discover/\(path)"
    components.queryItems = [
      URLQueryItem(name: "client_id", value: SIMKL_CLIENT_ID),
      URLQueryItem(name: "app-name", value: SIMKL_APP_NAME),
      URLQueryItem(name: "app-version", value: SIMKL_APP_VERSION),
    ]
    return components.url!
  }

  /// Bump `DiscoverDiskCache.version` when `DiscoverItem` gains fields, so an
  /// update never reads a copy saved without them.
  var cacheName: String {
    "v\(DiscoverDiskCache.version)_" + path.replacingOccurrences(of: "/", with: "_")
  }
}

/// Decoded discover files saved under Caches, so Explore paints instantly
/// after a relaunch and only refreshes what has gone stale.
struct DiscoverDiskCache: Sendable {
  struct Entry<Value: Codable & Sendable>: Codable, Sendable {
    let savedAt: Date
    let value: Value
    /// The file's `Last-Modified`, sent back as `If-Modified-Since`.
    var lastModified: String? = nil
  }

  static let version = 2

  let directory: URL

  static var standard: DiscoverDiskCache {
    DiscoverDiskCache(
      directory: URL.cachesDirectory.appending(path: "Discover", directoryHint: .isDirectory))
  }

  func read<Value: Codable & Sendable>(_: Value.Type, for source: DiscoverSource) -> Entry<Value>? {
    guard let data = try? Data(contentsOf: directory.appending(path: source.cacheName)) else {
      return nil
    }
    return try? JSONDecoder().decode(Entry<Value>.self, from: data)
  }

  /// Deletes copies saved by older versions of the cache.
  func removeOldVersions() {
    let prefix = "v\(Self.version)_"
    let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    for name in names where !name.hasPrefix(prefix) {
      try? FileManager.default.removeItem(at: directory.appending(path: name))
    }
  }

  /// Failures are ignored: a missing cache only costs another download.
  func write<Value: Codable & Sendable>(_ entry: Entry<Value>, for source: DiscoverSource) {
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    guard let data = try? JSONEncoder().encode(entry) else { return }
    try? data.write(to: directory.appending(path: source.cacheName), options: .atomic)
  }
}

enum DiscoverError: Error {
  /// A file decoded but held nothing, so keep the copy we have.
  case empty
}

/// A discover file Explore couldn't use, with its path for Sentry.
struct DiscoverFileError: Error, CustomNSError {
  let path: String
  let underlying: Error

  static var errorDomain: String { "Simalytics.DiscoverFileError" }

  var errorUserInfo: [String: Any] {
    [NSLocalizedDescriptionKey: "Discover file \(path) failed: \(underlying)"]
  }
}

/// Explore's data. Simkl asks apps to prefer these CDN files over API calls and
/// to keep them across screens, so one shared store holds them for the whole
/// app: the today file refreshes hourly, the 30-day pools and genre lists
/// daily, and a genre's titles load only when its page opens. Refreshes ask
/// "changed since?", so a file that hasn't changed costs a tiny 304.
@MainActor @Observable
final class DiscoverStore {
  static let shared = DiscoverStore()

  enum Phase: Equatable { case idle, loading, loaded, failed }

  private(set) var trending: [DiscoverMediaType: [DiscoverItem]] = [:]
  private(set) var pools: [DiscoverMediaType: [DiscoverItem]] = [:]
  private(set) var genreIndex: [DiscoverMediaType: [DiscoverGenre]] = [:]
  private(set) var phase = Phase.idle
  /// Bumps whenever the files change, so Explore knows its lists are stale.
  private(set) var revision = 0

  private struct GenreFile {
    let savedAt: Date
    let items: [DiscoverItem]
    let lastModified: String?
  }

  /// What a snapshot is built from: the filter's types, the hide switch, and
  /// the revisions of the files and the library.
  struct SnapshotKey: Hashable, Sendable {
    let types: [DiscoverMediaType]
    let hidesLibrary: Bool
    let revision: Int
    let libraryRevision: Int
  }

  @ObservationIgnored private var savedAt: [DiscoverSource: Date] = [:]
  /// Each file's `Last-Modified`, for conditional requests.
  @ObservationIgnored private var lastModified: [DiscoverSource: String] = [:]
  /// Files that last answered 304, when, and how many times in a row.
  @ObservationIgnored private var unchanged: [DiscoverSource: (at: Date, count: Int)] = [:]
  @ObservationIgnored private var genreFiles: [DiscoverSource: GenreFile] = [:]
  @ObservationIgnored private var snapshots: [SnapshotKey: ExploreSnapshot] = [:]
  /// Files whose failure Sentry has already heard about this session.
  @ObservationIgnored private var reported: Set<DiscoverSource> = []
  @ObservationIgnored private var restored = false
  @ObservationIgnored private var inFlight: Task<Void, Never>?

  private let cache: DiscoverDiskCache
  private let session: URLSession
  private let now: @Sendable () -> Date
  private let reporter: @Sendable (Error) -> Void
  /// Genre pages kept in memory; each file holds up to 500 titles.
  private let genreFileLimit = 8
  /// Simkl regenerates files on a best-effort schedule, so a 304 when one is
  /// due usually means the new copy isn't ready. Its docs suggest rechecking
  /// after 5, 15, then every 30 minutes rather than waiting out a full cycle.
  static let recheckDelays: [TimeInterval] = [5 * 60, 15 * 60, 30 * 60]

  init(
    cache: DiscoverDiskCache = .standard, session: URLSession = .shared,
    now: @escaping @Sendable () -> Date = { Date() },
    reporter: @escaping @Sendable (Error) -> Void = { reportError($0) }
  ) {
    self.cache = cache
    self.session = session
    self.now = now
    self.reporter = reporter
  }

  var hasContent: Bool { !trending.values.allSatisfy(\.isEmpty) || !pools.isEmpty }

  /// The snapshot Explore wants now. Reading it observes `revision`, so a
  /// refresh redraws the page.
  func snapshotKey(
    for filter: ExploreFilter, hideAnime: Bool,
    library: DiscoverLibrary.Contents = DiscoverLibrary.Contents(), hidesLibrary: Bool = false
  ) -> SnapshotKey {
    SnapshotKey(
      types: filter.types(hideAnime: hideAnime), hidesLibrary: hidesLibrary, revision: revision,
      libraryRevision: library.revision)
  }

  /// A snapshot already built for `key`, so a view body can show it at once.
  func cachedSnapshot(for key: SnapshotKey) -> ExploreSnapshot? {
    snapshots[key]
  }

  /// Builds `key`'s snapshot off the main actor: the 30-day pools make it tens
  /// of milliseconds, too long for a view body. Only snapshots of the current
  /// files and library are kept.
  func snapshot(
    for key: SnapshotKey, library: DiscoverLibrary.Contents = DiscoverLibrary.Contents()
  ) async -> ExploreSnapshot {
    if let snapshot = snapshots[key] { return snapshot }
    let (trending, pools, genreIndex, date, built) = (trending, pools, genreIndex, now(), revision)
    let snapshot = await Task.detached(priority: .userInitiated) {
      ExploreSnapshot(
        trending: trending, pools: pools, genreIndex: genreIndex, types: key.types,
        library: library.entries, hidesLibrary: key.hidesLibrary, now: date)
    }.value
    // The files or the library may have moved on while it built.
    if built == key.revision, revision == key.revision, library.revision == key.libraryRevision {
      snapshots = snapshots.filter { $0.key.libraryRevision == key.libraryRevision }
      snapshots[key] = snapshot
    }
    return snapshot
  }

  /// Restores the disk copy, then refreshes whatever is stale. Cheap to call on
  /// every appearance: a call waits out any load in flight, and fresh files
  /// are never downloaded twice. `todayOnly` skips the 30-day files, which
  /// Search's suggestions don't need.
  func load(hideAnime: Bool, force: Bool = false, todayOnly: Bool = false) async {
    if let inFlight { await inFlight.value }
    let task = Task { await refresh(hideAnime: hideAnime, force: force, todayOnly: todayOnly) }
    inFlight = task
    await task.value
    if inFlight == task { inFlight = nil }
  }

  /// A genre's most watched titles this month, adult titles removed.
  func items(in genre: DiscoverGenre, type: DiscoverMediaType, force: Bool = false) async throws
    -> [DiscoverItem]
  {
    #if DEBUG
      if ScreenshotMode.isActive {
        return ScreenshotDiscoverFixtures.items(inGenre: genre.name, type: type)
      }
    #endif
    let source = DiscoverSource.genre(type, slug: genre.slug)
    let file = genreFiles[source]
    if !force, let file, !isStale(source, savedAt: file.savedAt) {
      return file.items
    }
    let response: Response
    do {
      response = try await Self.fetch(
        source, ifModifiedSince: file?.lastModified, session: session)
    } catch {
      report(error, for: source)
      throw error
    }
    switch response {
    case .notModified:
      // Only asked when there's a copy to keep.
      guard let file else { throw DiscoverError.empty }
      noteUnchanged(source)
      return file.items
    case .modified(.items(let items), let validator):
      let visible = items.filter { !$0.isAdult }
      genreFiles[source] = GenreFile(savedAt: now(), items: visible, lastModified: validator)
      unchanged[source] = nil
      if genreFiles.count > genreFileLimit,
        let oldest = genreFiles.min(by: { $0.value.savedAt < $1.value.savedAt })?.key
      {
        genreFiles[oldest] = nil
        unchanged[oldest] = nil
      }
      return visible
    case .modified:
      throw DiscoverError.empty
    }
  }

  private func refresh(hideAnime: Bool, force: Bool, todayOnly: Bool) async {
    #if DEBUG
      if ScreenshotMode.isActive {
        trending = ScreenshotDiscoverFixtures.trending
        pools = ScreenshotDiscoverFixtures.pools
        genreIndex = ScreenshotDiscoverFixtures.genreIndex
        dataChanged()
        phase = .loaded
        return
      }
    #endif
    if !restored {
      restored = true
      await restoreFromDisk()
    }

    let types = hideAnime ? [DiscoverMediaType.shows, .movies] : DiscoverMediaType.allCases
    let sources =
      todayOnly
      ? [DiscoverSource.today]
      : [DiscoverSource.today] + types.map { .pool($0) } + types.map { .genreIndex($0) }
    let stale = sources.filter { force || isStale($0, savedAt: savedAt[$0]) }
    if stale.isEmpty {
      phase = hasContent ? .loaded : phase
      return
    }
    if !hasContent { phase = .loading }

    // A refresh of files already on screen applies them together, so the
    // page rebuilds once; a first load paints each file as it lands.
    let holdsFiles = stale.allSatisfy { savedAt[$0] != nil }
    let session = session
    await withTaskGroup(of: (DiscoverSource, Result<Response, Error>).self) { group in
      for source in stale {
        // Only ask "changed since?" about a file there's a copy of to keep.
        let validator = savedAt[source] == nil ? nil : lastModified[source]
        group.addTask {
          do {
            let response = try await Self.fetch(
              source, ifModifiedSince: validator, session: session)
            return (source, .success(response))
          } catch {
            return (source, .failure(error))
          }
        }
      }
      var held: [(DiscoverSource, Payload, String?)] = []
      for await (source, result) in group {
        switch result {
        case .success(.modified(let payload, let validator)):
          if holdsFiles {
            held.append((source, payload, validator))
          } else {
            apply(payload, from: source, savedAt: now(), lastModified: validator)
          }
        case .success(.notModified):
          noteUnchanged(source)
        case .failure(let error):
          report(error, for: source)
        }
      }
      for (source, payload, validator) in held {
        apply(payload, from: source, savedAt: now(), lastModified: validator)
      }
    }
    phase = hasContent ? .loaded : .failed
  }

  private func isStale(_ source: DiscoverSource, savedAt: Date?) -> Bool {
    let date = now()
    if let check = unchanged[source] {
      let delay = Self.recheckDelays[min(check.count, Self.recheckDelays.count) - 1]
      let elapsed = date.timeIntervalSince(check.at)
      return elapsed < 0 || elapsed >= delay
    }
    guard let savedAt else { return true }
    let age = date.timeIntervalSince(savedAt)
    return age < 0 || age >= source.maxAge
  }

  private func noteUnchanged(_ source: DiscoverSource) {
    unchanged[source] = (now(), (unchanged[source]?.count ?? 0) + 1)
  }

  /// New files make every built snapshot stale.
  private func dataChanged() {
    revision += 1
    snapshots.removeAll()
  }

  /// Tells Sentry about a file that failed for more than the network, once a
  /// session per file. Otherwise a format change would only look like stale data.
  private func report(_ error: Error, for source: DiscoverSource) {
    guard !isSimklCancellationError(error), !isExpectedTransientNetworkError(error),
      reported.insert(source).inserted
    else { return }
    reporter(DiscoverFileError(path: source.path, underlying: error))
  }

  private func apply(
    _ payload: Payload, from source: DiscoverSource, savedAt date: Date,
    lastModified validator: String?
  ) {
    savedAt[source] = date
    lastModified[source] = validator
    unchanged[source] = nil
    dataChanged()
    let cache = cache
    switch (payload, source) {
    case (.today(let files), _):
      trending = files
      let value = Dictionary(uniqueKeysWithValues: files.map { ($0.key.rawValue, $0.value) })
      Task.detached(priority: .utility) {
        cache.write(.init(savedAt: date, value: value, lastModified: validator), for: source)
      }
    case (.items(let items), .pool(let type)):
      pools[type] = items
      Task.detached(priority: .utility) {
        cache.write(.init(savedAt: date, value: items, lastModified: validator), for: source)
      }
    case (.genres(let genres), .genreIndex(let type)):
      genreIndex[type] = genres
      Task.detached(priority: .utility) {
        cache.write(.init(savedAt: date, value: genres, lastModified: validator), for: source)
      }
    default:
      break
    }
  }

  private func restoreFromDisk() async {
    let cache = cache
    let restored = await Task.detached(priority: .userInitiated) {
      () -> [(DiscoverSource, Date, String?, Payload)] in
      cache.removeOldVersions()
      var entries: [(DiscoverSource, Date, String?, Payload)] = []
      if let today = cache.read([String: [DiscoverItem]].self, for: .today) {
        var files: [DiscoverMediaType: [DiscoverItem]] = [:]
        for type in DiscoverMediaType.allCases {
          files[type] = today.value[type.rawValue]?.map { $0.with(type: type) }
        }
        entries.append((.today, today.savedAt, today.lastModified, .today(files)))
      }
      for type in DiscoverMediaType.allCases {
        if let pool = cache.read([DiscoverItem].self, for: .pool(type)) {
          let items = pool.value.map { $0.with(type: type) }
          entries.append((.pool(type), pool.savedAt, pool.lastModified, .items(items)))
        }
        if let index = cache.read([DiscoverGenre].self, for: .genreIndex(type)) {
          let genres = Payload.genres(index.value)
          entries.append((.genreIndex(type), index.savedAt, index.lastModified, genres))
        }
      }
      return entries
    }.value

    if !restored.isEmpty { dataChanged() }
    for (source, date, validator, payload) in restored {
      savedAt[source] = date
      lastModified[source] = validator
      switch (payload, source) {
      case (.today(let files), _): trending = files
      case (.items(let items), .pool(let type)): pools[type] = items
      case (.genres(let genres), .genreIndex(let type)): genreIndex[type] = genres
      default: break
      }
    }
    if hasContent { phase = .loaded }
  }

  enum Payload: Sendable {
    case today([DiscoverMediaType: [DiscoverItem]])
    case items([DiscoverItem])
    case genres([DiscoverGenre])
  }

  /// A fresh copy of a file, or Simkl's word that the one we have is current.
  enum Response: Sendable {
    case modified(Payload, lastModified: String?)
    case notModified
  }

  nonisolated static func fetch(
    _ source: DiscoverSource, ifModifiedSince validator: String? = nil, session: URLSession
  ) async throws -> Response {
    var request = URLRequest(url: source.url)
    // The store keeps its own copies, so skip URLCache; a manual
    // `If-Modified-Since` then gets the server's 304 straight back.
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue(SIMKL_USER_AGENT, forHTTPHeaderField: "User-Agent")
    if let validator {
      request.setValue(validator, forHTTPHeaderField: "If-Modified-Since")
    }
    let result: (Data, HTTPURLResponse)
    do {
      result = try await performSimklRequest(request, session: session)
    } catch SimklMutationError.httpStatusCode(304, _) {
      return .notModified
    }
    let (data, response) = result
    // The 30-day files run past a megabyte; decode off the main actor.
    let payload = try await Task.detached(priority: .userInitiated) {
      try decode(data, for: source)
    }.value
    return .modified(payload, lastModified: response.value(forHTTPHeaderField: "Last-Modified"))
  }

  nonisolated static func decode(_ data: Data, for source: DiscoverSource) throws -> Payload {
    let decoder = JSONDecoder()
    switch source {
    case .today:
      let files = try decoder.decode([String: LossyArray<DiscoverItem>].self, from: data)
      var trending: [DiscoverMediaType: [DiscoverItem]] = [:]
      for type in DiscoverMediaType.allCases {
        trending[type] = files[type.rawValue]?.elements.map { $0.with(type: type) } ?? []
      }
      guard trending.values.contains(where: { !$0.isEmpty }) else { throw DiscoverError.empty }
      return .today(trending)
    case .pool(let type), .genre(let type, _):
      let items = try decoder.decode(LossyArray<DiscoverItem>.self, from: data).elements
      guard !items.isEmpty else { throw DiscoverError.empty }
      return .items(items.map { $0.with(type: type) })
    case .genreIndex:
      let genres = try decoder.decode(LossyArray<DiscoverGenre>.self, from: data).elements
      guard !genres.isEmpty else { throw DiscoverError.empty }
      return .genres(genres)
    }
  }
}
