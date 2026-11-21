//
//  RewatchModel.swift
//  simalytics
//

import Foundation

/// One `/sync/all-items/{shows|anime}?allow_rewatch=yes&extended=full` entry.
/// Canonical rows carry `is_rewatch: false`; every saved rewatch session adds
/// a `true` row for the same title. See https://api.simkl.org/guides/rewatches
struct RewatchRowModel: Decodable, Sendable {
  let is_rewatch: Bool?
  let rewatch_id: Int?
  let rewatch_status: String?
  let last_watched_at: String?
  let watched_episodes_count: Int?
  let total_episodes_count: Int?
  let not_aired_episodes_count: Int?
  let anime_type: String?
  let show: Show?
  let seasons: [Season]?

  struct Show: Decodable, Sendable {
    let title: String?
    let poster: String?
    let ids: IDs?
  }

  struct IDs: Decodable, Sendable {
    let simkl: Int?
  }

  struct Season: Decodable, Sendable {
    let number: Int?
    let episodes: [Episode]?
  }

  struct Episode: Decodable, Sendable {
    let number: Int?
  }
}

/// One `/sync/all-items/movies?allow_rewatch=yes&extended=simkl_ids_only` row.
/// SIMKL completes a movie rewatch as it's logged, so only its id matters.
struct MovieRewatchRowModel: Decodable, Sendable {
  let is_rewatch: Bool?
  let rewatch_id: Int?
  let rewatch_status: String?
  let movie: Movie?

  struct Movie: Decodable, Sendable {
    let ids: RewatchRowModel.IDs?
  }
}

/// The plan field of `GET /users/settings`; rewatches need `pro` or `vip`.
struct SimklUserSettingsModel: Decodable, Sendable {
  struct Account: Decodable, Sendable {
    let type: String?
  }

  let account: Account?
}
