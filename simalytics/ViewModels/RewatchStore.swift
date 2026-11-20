//
//  RewatchStore.swift
//  simalytics
//

import Foundation
import Observation

/// Active rewatch sessions for an opted-in Simkl PRO / VIP account, shared by
/// Up Next and the detail pages. Sessions live in a small file under Caches
/// rather than SwiftData: SIMKL returns them as extra rows that share their
/// title's ID, and everything here can be pulled again.
@MainActor @Observable
final class RewatchStore {
  static let shared = RewatchStore()

  /// The Settings switch. SIMKL asks apps to keep rewatch tracking opt-in.
  nonisolated static let preferenceKey = "trackRewatches"

  /// SIMKL keeps up to 50 sessions per title and asks apps to count them
  /// before offering to start another.
  static let maxSessionsPerTitle = 50

  struct Cursor: Codable, Equatable, Sendable {
    /// The type's `/sync/activities` `all`, read before the last successful pull.
    var activity: String?
    /// When the first full pull succeeded. SIMKL asks for `date_from` on every
    /// pull after it; nil starts over with a full pull.
    var baselineAt: Date?
  }

  struct State: Codable, Equatable, Sendable {
    /// `account.type` from `/users/settings`: `free`, `pro`, or `vip`.
    var accountType: String?
    /// `settings.all` when `accountType` was read; a change means refetch it.
    var settingsActivity: String?
    var sessions: [RewatchSession] = []
    var tv = Cursor()
    var anime = Cursor()
    /// Saved sessions of any status per title, for the 50-session cap.
    var tvSessionCounts: [Int: Int] = [:]
    var animeSessionCounts: [Int: Int] = [:]

    var isPlanEligible: Bool { accountType == "pro" || accountType == "vip" }

    func cursor(for kind: RewatchKind) -> Cursor { kind == .tv ? tv : anime }

    func sessionCounts(for kind: RewatchKind) -> [Int: Int] {
      kind == .tv ? tvSessionCounts : animeSessionCounts
    }
  }

  private(set) var state: State
  /// Titles whose rewatch SIMKL just marked complete, so their page can say
  /// so. In memory only: the next launch shows the plain Start button.
  private(set) var completedTitles: Set<Int> = []
  @ObservationIgnored private let fileURL: URL?
  @ObservationIgnored private let defaults: UserDefaults

  init(fileURL: URL? = RewatchStore.defaultFileURL, defaults: UserDefaults = .standard) {
    self.fileURL = fileURL
    self.defaults = defaults
    state =
      fileURL
      .flatMap { try? Data(contentsOf: $0) }
      .flatMap { try? JSONDecoder().decode(State.self, from: $0) } ?? State()
  }

  nonisolated static var defaultFileURL: URL {
    URL.cachesDirectory.appending(path: "Rewatches/state.json")
  }

  /// The Settings switch, for code without `@AppStorage`.
  var isTrackingEnabled: Bool { defaults.bool(forKey: Self.preferenceKey) }

  func disableTracking() {
    defaults.set(false, forKey: Self.preferenceKey)
  }

  var isPlanEligible: Bool { state.isPlanEligible }

  func activeSession(simkl: Int, kind: RewatchKind) -> RewatchSession? {
    state.sessions.first { $0.simkl == simkl && $0.kind == kind }
  }

  func sessionCount(simkl: Int, kind: RewatchKind) -> Int {
    state.sessionCounts(for: kind)[simkl] ?? 0
  }

  /// Until the first pull lands, a title's sessions haven't been counted.
  func hasCountedSessions(_ kind: RewatchKind) -> Bool {
    state.cursor(for: kind).baselineAt != nil
  }

  // MARK: - Sync

  /// A plan without rewatches also drops the local sessions. They stay on the
  /// user's Simkl account and come back with a full pull after an upgrade.
  func updatePlan(_ accountType: String, settingsActivity: String?, accessToken: String) {
    guard SyncAccount.isActive(accessToken) else { return }
    state.accountType = accountType
    state.settingsActivity = settingsActivity
    if !state.isPlanEligible { clearSessions() }
    save()
  }

  /// Replaces the type's sessions and counts with a pull that started from `base`.
  ///
  /// The account is checked here, on the main actor, so a sign-out that lands
  /// while a pull is in flight can't be undone by its result.
  func apply(_ pull: RewatchPull, kind: RewatchKind, base: [RewatchSession], accessToken: String) {
    // Switching tracking off mid-pull also drops what the pull brought back.
    guard SyncAccount.isActive(accessToken), isTrackingEnabled else { return }
    let current = state.sessions.filter { $0.kind == kind }
    let sessions = RewatchSession.reconciled(pulled: pull.sessions, base: base, current: current)
    let counts = RewatchSession.reconciledCounts(
      pulled: pull.sessionCounts, base: base, current: current,
      currentCounts: state.sessionCounts(for: kind))
    state.sessions = (state.sessions.filter { $0.kind != kind } + sessions).sorted { $0.id < $1.id }
    if kind == .tv {
      state.tv = pull.cursor
      state.tvSessionCounts = counts
    } else {
      state.anime = pull.cursor
      state.animeSessionCounts = counts
    }
    save()
  }

  // MARK: - Writes

  /// Shows a confirmed episode write before the follow-up sync lands.
  func record(_ episode: RewatchEpisode, watched: Bool, sessionID: Int) {
    guard let index = state.sessions.firstIndex(where: { $0.id == sessionID }) else { return }
    state.sessions[index].record(episode, watched: watched)
    save()
  }

  /// Resolves the session's next episode from a catalog the caller already
  /// has, such as the detail page's episode list, instead of waiting for sync.
  func resolveNext(sessionID: Int, catalog: [RewatchCatalogEpisode], at date: Date = Date()) {
    guard !catalog.isEmpty,
      let index = state.sessions.firstIndex(where: { $0.id == sessionID })
    else { return }
    state.sessions[index].next = RewatchSession.nextEpisode(
      after: state.sessions[index].episodes, in: catalog)
    state.sessions[index].nextResolvedAt = date
    save()
  }

  /// SIMKL completes a rewatch once it covers every aired episode. The session
  /// leaves the active list, and its page says the rewatch is done.
  func complete(sessionID: Int) {
    guard let session = state.sessions.first(where: { $0.id == sessionID }) else { return }
    completedTitles.insert(session.simkl)
    removeSession(id: sessionID)
  }

  func isRecentlyCompleted(simkl: Int) -> Bool { completedTitles.contains(simkl) }

  /// Reads the type in full on the next sync, such as after Start returned a
  /// session that already existed, whose episodes no delta will repeat.
  func requestFullPull(_ kind: RewatchKind) {
    if kind == .tv { state.tv.baselineAt = nil } else { state.anime.baselineAt = nil }
    save()
  }

  /// A session the user just started, counted toward the title's cap.
  func insert(_ session: RewatchSession) {
    completedTitles.remove(session.simkl)
    state.sessions.removeAll { $0.simkl == session.simkl && $0.kind == session.kind }
    state.sessions.append(session)
    state.sessions.sort { $0.id < $1.id }
    if session.kind == .tv {
      state.tvSessionCounts[session.simkl, default: 0] += 1
    } else {
      state.animeSessionCounts[session.simkl, default: 0] += 1
    }
    save()
  }

  /// Counts are left alone: a closed session still counts toward the cap, and
  /// the follow-up sync recounts the title.
  func removeSession(id: Int) {
    state.sessions.removeAll { $0.id == id }
    save()
  }

  // MARK: - Reset

  /// Turning the switch off keeps the plan, so turning it back on is instant.
  func clearSessions() {
    completedTitles = []
    state.sessions = []
    state.tv = Cursor()
    state.anime = Cursor()
    state.tvSessionCounts = [:]
    state.animeSessionCounts = [:]
    save()
  }

  /// Signing out forgets the account's plan and sessions, and turns the switch
  /// off: SIMKL asks for rewatch tracking to be each user's own choice, so the
  /// next account on this device opts in for itself.
  func reset() {
    state = State()
    completedTitles = []
    disableTracking()
    if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
  }

  /// Failures are ignored: a missing file only costs another full pull.
  private func save() {
    guard let fileURL else { return }
    try? FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let data = try? JSONEncoder().encode(state) else { return }
    try? data.write(to: fileURL, options: .atomic)
  }
}
