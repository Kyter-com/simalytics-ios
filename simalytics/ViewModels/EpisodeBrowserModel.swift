import Observation

@Observable @MainActor
final class EpisodeBrowserModel {
  let groups: [EpisodeListGroup]
  var selectedGroup: Int
  private(set) var watchedIDs: Set<Int> = []
  private(set) var updatingID: Int?
  var errorMessage: String?
  private let coordinator = EpisodeMutationCoordinator()

  var currentGroup: EpisodeListGroup? { groups.first { $0.id == selectedGroup } }
  var watchedCount: Int {
    currentGroup?.episodes.filter { watchedIDs.contains($0.id) }.count ?? 0
  }

  /// A navigation aid within the chosen group, not a predicted Up Next entry.
  var nextUnwatched: EpisodeListItem? {
    guard let episodes = currentGroup?.episodes else { return nil }
    let lastWatched = episodes.lastIndex { watchedIDs.contains($0.id) }
    return episodes.enumerated().first {
      $0.offset > (lastWatched ?? -1) && !watchedIDs.contains($0.element.id)
    }?.element
  }

  init(episodes: [EpisodeListItem], seasons: [WatchlistSeason]?, isAnime: Bool) {
    var seen = Set<Int>()
    let unique = episodes.filter { $0.id > 0 && $0.group >= 0 && seen.insert($0.id).inserted }
    groups = Dictionary(grouping: unique, by: \.group).map {
      EpisodeListGroup(id: $0.key, episodes: $0.value, isAnime: isAnime)
    }.sorted {
      if $0.id == 0 { return false }
      if $1.id == 0 { return true }
      return $0.id < $1.id
    }
    selectedGroup = groups.first?.id ?? 0
    updateWatched(seasons: seasons)
    selectedGroup =
      preferredEpisodeSeason(
        in: unique, season: { $0.group }, isWatched: { watchedIDs.contains($0.id) }
      ) ?? groups.first?.id ?? 0
  }

  func updateWatched(seasons: [WatchlistSeason]?) {
    let watched = Dictionary(grouping: seasons ?? [], by: { $0.number ?? -1 }).mapValues {
      Set($0.flatMap { $0.episodes ?? [] }.filter { $0.watched == true }.compactMap(\.number))
    }
    watchedIDs = Set(
      groups.flatMap(\.episodes).filter {
        guard let season = $0.watchSeason, let number = $0.number else { return false }
        return watched[season]?.contains(number) == true
      }.map(\.id))
  }

  func toggle(
    _ episode: EpisodeListItem,
    mutation: (EpisodeListItem, Bool) async -> SimklMutationResult,
    commit: (EpisodeListItem, Bool) -> Void,
    reconcile: () async -> [WatchlistSeason]?
  ) async {
    guard updatingID == nil, episode.canMarkWatched else { return }
    updatingID = episode.id
    defer { updatingID = nil }
    let original = watchedIDs
    let willWatch = !original.contains(episode.id)
    let result = await coordinator.run(
      optimisticUpdate: {
        if willWatch { watchedIDs.insert(episode.id) } else { watchedIDs.remove(episode.id) }
      },
      rollback: { watchedIDs = original },
      mutation: { await mutation(episode, willWatch) },
      commit: { commit(episode, willWatch) },
      reconcile: {
        if let seasons = await reconcile(), !Task.isCancelled { updateWatched(seasons: seasons) }
      })
    if case .failed(let message) = result { errorMessage = message }
  }
}
