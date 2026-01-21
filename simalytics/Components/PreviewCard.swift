//
//  PreviewCard.swift
//  simalytics
//
//  Created by Nick Reisenauer on 1/8/26.
//

import SwiftUI

struct PreviewCard: View {
  @AppStorage("useFiveStarRating") private var useFiveStarRating = false

  let title: String
  let year: Int?
  let poster: String?
  let userRating: Int?
  let status: String?
  var mediaType: String? = nil
  var animeType: String? = nil
  var watchedEpisodes: Int? = nil
  var totalEpisodes: Int? = nil

  private var displayRating: String {
    guard let rating = userRating, rating > 0 else { return "" }
    if useFiveStarRating {
      let fiveStarRating = Double(rating) / 2
      let formatted = fiveStarRating.truncatingRemainder(dividingBy: 1) == 0
        ? String(format: "%.0f", fiveStarRating)
        : String(format: "%.1f", fiveStarRating)
      return "\(formatted)/5"
    } else {
      return "\(rating)/10"
    }
  }

  private var posterURL: String? {
    guard let poster = poster else { return nil }
    return "\(SIMKL_CDN_URL)/posters/\(poster)_m.jpg"
  }

  private var statusText: String? {
    guard let status = status else { return nil }
    switch status {
    case "plantowatch": return "Plan to Watch"
    case "watching": return "Watching"
    case "completed": return "Completed"
    case "hold": return "On Hold"
    case "dropped": return "Dropped"
    default: return status.capitalized
    }
  }

  private var mediaTypeIcon: String? {
    guard let mediaType = mediaType else { return nil }
    switch mediaType {
    case "movie": return "film"
    case "tv": return "tv"
    case "anime": return "sparkles.tv"
    default: return nil
    }
  }

  private var mediaTypeText: String? {
    guard let mediaType = mediaType else { return nil }
    switch mediaType {
    case "movie": return "Movie"
    case "tv": return "TV Show"
    case "anime": return animeType ?? "Anime"
    default: return mediaType.capitalized
    }
  }

  private var episodeProgressText: String? {
    guard let watched = watchedEpisodes, let total = totalEpisodes, total > 0 else {
      return nil
    }
    return "\(watched)/\(total) episodes"
  }

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      CustomKFImage(
        imageUrlString: posterURL,
        memoryCacheOnly: true,
        height: 225,
        width: 150
      )

      VStack(alignment: .leading, spacing: 8) {
        Text(title)
          .font(.title2)
          .fontWeight(.bold)
          .lineLimit(3)

        if let year = year {
          Text(String(year))
            .font(.subheadline)
            .foregroundColor(.secondary)
        }

        if let mediaTypeText = mediaTypeText, let mediaTypeIcon = mediaTypeIcon {
          HStack(spacing: 4) {
            Image(systemName: mediaTypeIcon)
            Text(mediaTypeText)
          }
          .font(.subheadline)
          .foregroundColor(.secondary)
        }

        if userRating != nil && userRating! > 0 {
          HStack(spacing: 4) {
            Image(systemName: "star.fill")
              .foregroundColor(.yellow)
            Text(displayRating)
              .fontWeight(.medium)
          }
          .font(.subheadline)
        }

        if let episodeProgress = episodeProgressText {
          HStack(spacing: 4) {
            Image(systemName: "play.circle")
              .foregroundColor(.blue)
            Text(episodeProgress)
          }
          .font(.subheadline)
          .foregroundColor(.secondary)
        }

        if let statusText = statusText {
          Text(statusText)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.2))
            .clipShape(Capsule())
        }

        Spacer()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 8)
    }
    .padding(16)
    .frame(width: 350, height: 260)
    .background(Color(.systemBackground))
  }
}
