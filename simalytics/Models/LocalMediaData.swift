//
//  LocalMediaData.swift
//  simalytics
//

import Foundation

/// Value-only media state used by context-menu previews.
struct LocalMediaData: Equatable, Sendable {
  let year: Int?
  let userRating: Int?
  let status: String?
  let animeType: String?
  let watchedEpisodes: Int?
  let totalEpisodes: Int?
}
