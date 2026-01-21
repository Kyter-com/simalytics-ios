//
//  SmartPreviewCard.swift
//  simalytics
//
//  Created by Nick Reisenauer on 1/8/26.
//

import SwiftData
import SwiftUI

/// Helper struct to hold looked-up local data
struct LocalMediaData {
  let year: Int?
  let userRating: Int?
  let status: String?
  let animeType: String?
  let watchedEpisodes: Int?
  let totalEpisodes: Int?
}

/// Helper to look up local data for a media item
/// Call this from a view that has access to modelContext
enum LocalDataLookup {
  static func lookup(
    simklId: Int,
    mediaType: String,
    context: ModelContext
  ) -> LocalMediaData? {
    switch mediaType {
    case "movie":
      let descriptor = FetchDescriptor<V1.SDMovies>(
        predicate: #Predicate { $0.simkl == simklId }
      )
      if let movie = try? context.fetch(descriptor).first {
        return LocalMediaData(
          year: movie.year,
          userRating: movie.user_rating,
          status: movie.status,
          animeType: nil,
          watchedEpisodes: nil,
          totalEpisodes: nil
        )
      }
    case "tv":
      let descriptor = FetchDescriptor<V1.SDShows>(
        predicate: #Predicate { $0.simkl == simklId }
      )
      if let show = try? context.fetch(descriptor).first {
        return LocalMediaData(
          year: show.year,
          userRating: show.user_rating,
          status: show.status,
          animeType: nil,
          watchedEpisodes: show.watched_episodes_count,
          totalEpisodes: show.total_episodes_count
        )
      }
    case "anime":
      let descriptor = FetchDescriptor<V1.SDAnimes>(
        predicate: #Predicate { $0.simkl == simklId }
      )
      if let anime = try? context.fetch(descriptor).first {
        return LocalMediaData(
          year: anime.year,
          userRating: anime.user_rating,
          status: anime.status,
          animeType: anime.anime_type,
          watchedEpisodes: anime.watched_episodes_count,
          totalEpisodes: anime.total_episodes_count
        )
      }
    default:
      break
    }
    return nil
  }
}

/// A preview card that uses pre-looked-up local data
/// The parent view should call LocalDataLookup.lookup() and pass the result here
struct SmartPreviewCard: View {
  let simklId: Int
  let title: String
  let year: Int?
  let poster: String?
  let mediaType: String
  let localData: LocalMediaData?

  var body: some View {
    PreviewCard(
      title: title,
      year: localData?.year ?? year,
      poster: poster,
      userRating: localData?.userRating,
      status: localData?.status,
      mediaType: mediaType,
      animeType: localData?.animeType,
      watchedEpisodes: localData?.watchedEpisodes,
      totalEpisodes: localData?.totalEpisodes
    )
  }
}
