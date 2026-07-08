//
//  MarkWatchedHelpers.swift
//  simalytics
//
//  Optimistic SwiftData mutations + cache invalidation used by the
//  mark-watched / mark-unwatched flow so the UI reflects the change
//  before the round-trip + re-sync finishes.
//

import Foundation
import Sentry
import SwiftData

enum MarkWatchedMediaKind {
  case tv
  case anime
}

// Clears next_to_watch_info_* on the SDShows/SDAnimes row for `simklId`
// when the marked episode matches the currently-tracked next-to-watch.
// UpNextView filters on next_to_watch_info_title != "", so clearing it
// hides the just-watched episode until the server-side recompute lands.
@MainActor
func optimisticallyClearNextToWatch(
  simklId: Int,
  season: Int,
  episode: Int,
  kind: MarkWatchedMediaKind,
  modelContainer: ModelContainer
) {
  let context = ModelContext(modelContainer)
  do {
    switch kind {
    case .tv:
      let fd = FetchDescriptor<V1.SDShows>(predicate: #Predicate { $0.simkl == simklId })
      guard let row = try context.fetch(fd).first else { return }
      let matchesNext =
        (row.next_to_watch_info_episode == episode)
        && (row.next_to_watch_info_season == nil || row.next_to_watch_info_season == season)
      if matchesNext {
        row.next_to_watch_info_title = nil
        row.next_to_watch_info_season = nil
        row.next_to_watch_info_episode = nil
        row.next_to_watch_info_date = nil
        try context.save()
      }
    case .anime:
      let fd = FetchDescriptor<V1.SDAnimes>(predicate: #Predicate { $0.simkl == simklId })
      guard let row = try context.fetch(fd).first else { return }
      if row.next_to_watch_info_episode == episode {
        row.next_to_watch_info_title = nil
        row.next_to_watch_info_episode = nil
        row.next_to_watch_info_date = nil
        try context.save()
      }
    }
  } catch {
    reportError(error)
  }
}

// Force the next syncLatestActivities to re-run processUpNextEpisodes
// (which otherwise gates itself on a 6-hour cache). Mark-watched /
// mark-unwatched should always recompute up-next.
@MainActor
func invalidateUpNextCache(modelContainer: ModelContainer) {
  let context = ModelContext(modelContainer)
  do {
    let fd = FetchDescriptor<V1.SDLastSync>(predicate: #Predicate { $0.id == 1 })
    guard let syncRecord = try context.fetch(fd).first else { return }
    syncRecord.changes_api = nil
    try context.save()
  } catch {
    reportError(error)
  }
}
