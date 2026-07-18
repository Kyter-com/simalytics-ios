//
//  LocalMediaSnapshots.swift
//  simalytics
//

import Foundation
import SwiftData

/// In-memory, value-only index for context-menu preview data.
struct LocalMediaSnapshots: Sendable {
  struct Request: Hashable, Sendable {
    let movieIDs: [Int]
    let showIDs: [Int]
    let animeIDs: [Int]

    init(movieIDs: [Int] = [], showIDs: [Int] = [], animeIDs: [Int] = []) {
      self.movieIDs = Array(Set(movieIDs)).sorted()
      self.showIDs = Array(Set(showIDs)).sorted()
      self.animeIDs = Array(Set(animeIDs)).sorted()
    }
  }

  private var movies: [Int: LocalMediaData] = [:]
  private var shows: [Int: LocalMediaData] = [:]
  private var animes: [Int: LocalMediaData] = [:]

  func data(simklID: Int, mediaType: String) -> LocalMediaData? {
    switch mediaType {
    case "movie", "movies": movies[simklID]
    case "tv", "show": shows[simklID]
    case "anime": animes[simklID]
    default: nil
    }
  }

  /// Fetches each requested model type at most once, then immediately copies
  /// model values into dictionaries. The context and `@Model` instances stay
  /// on the main actor and never enter SwiftUI rendering state.
  @MainActor
  static func fetch(_ request: Request, context: ModelContext) -> LocalMediaSnapshots {
    var snapshots = LocalMediaSnapshots()

    if !request.movieIDs.isEmpty {
      let movieIDs = request.movieIDs
      do {
        let models = try context.fetch(
          FetchDescriptor<V1.SDMovies>(
            predicate: #Predicate { movieIDs.contains($0.simkl) }
          ))
        snapshots.movies = Dictionary(
          models.map {
            (
              $0.simkl,
              LocalMediaData(
                year: $0.year,
                userRating: $0.user_rating,
                status: $0.status,
                animeType: nil,
                watchedEpisodes: nil,
                totalEpisodes: nil
              )
            )
          },
          uniquingKeysWith: { _, latest in latest }
        )
      } catch {
        reportError(error)
      }
    }

    if !request.showIDs.isEmpty {
      let showIDs = request.showIDs
      do {
        let models = try context.fetch(
          FetchDescriptor<V1.SDShows>(
            predicate: #Predicate { showIDs.contains($0.simkl) }
          ))
        snapshots.shows = Dictionary(
          models.map {
            (
              $0.simkl,
              LocalMediaData(
                year: $0.year,
                userRating: $0.user_rating,
                status: $0.status,
                animeType: nil,
                watchedEpisodes: $0.watched_episodes_count,
                totalEpisodes: $0.total_episodes_count
              )
            )
          },
          uniquingKeysWith: { _, latest in latest }
        )
      } catch {
        reportError(error)
      }
    }

    if !request.animeIDs.isEmpty {
      let animeIDs = request.animeIDs
      do {
        let models = try context.fetch(
          FetchDescriptor<V1.SDAnimes>(
            predicate: #Predicate { animeIDs.contains($0.simkl) }
          ))
        snapshots.animes = Dictionary(
          models.map {
            (
              $0.simkl,
              LocalMediaData(
                year: $0.year,
                userRating: $0.user_rating,
                status: $0.status,
                animeType: $0.anime_type,
                watchedEpisodes: $0.watched_episodes_count,
                totalEpisodes: $0.total_episodes_count
              )
            )
          },
          uniquingKeysWith: { _, latest in latest }
        )
      } catch {
        reportError(error)
      }
    }

    return snapshots
  }
}

extension Notification.Name {
  static let localMediaSnapshotsDidChange = Notification.Name("LocalMediaSnapshotsDidChange")
}
