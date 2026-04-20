//
//  AnimeHeaderInfo.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/31/25.
//

import SwiftUI

struct AnimeHeaderInfo: View {
  @Binding var animeDetails: AnimeDetailsModel?
  @Binding var animeWatchlist: AnimeWatchlistModel?

  var body: some View {
    if animeDetails?.anime_type == "movie" {
      if let year = animeDetails?.year {
        LabeledContent {
          Text(String(year))
            .fontDesign(.monospaced)
            .foregroundStyle(.secondary)
        } label: {
          Label("Released", systemImage: "calendar")
            .foregroundStyle(.secondary)
        }
      }
    } else {
      if let year = animeDetails?.year_start_end {
        LabeledContent {
          Text(String(year).replacingOccurrences(of: " - ", with: "-"))
            .fontDesign(.monospaced)
            .foregroundStyle(.secondary)
        } label: {
          Label("Year", systemImage: "calendar")
            .foregroundStyle(.secondary)
        }
      }
    }

    if animeDetails?.anime_type == "movie" {
      if let runtime = animeDetails?.runtime {
        LabeledContent {
          Text("\(String(runtime)) Min")
            .fontDesign(.monospaced)
            .foregroundStyle(.secondary)
        } label: {
          Label("Runtime", systemImage: "clock")
            .foregroundStyle(.secondary)
        }
      }
    } else {
      if let runtime = animeDetails?.runtime {
        LabeledContent {
          Text("\(String(runtime)) Min")
            .fontDesign(.monospaced)
            .foregroundStyle(.secondary)
        } label: {
          Label("Ep. Runtime", systemImage: "clock")
            .foregroundStyle(.secondary)
        }
      }
    }

    if animeDetails?.anime_type == "movie" {
      if let certification = animeDetails?.certification {
        LabeledContent {
          Text(certification)
            .fontDesign(.monospaced)
            .foregroundStyle(.secondary)
        } label: {
          Label("MPAA", systemImage: "figure.and.child.holdinghands")
            .foregroundStyle(.secondary)
        }
      }
    } else {
      if let total_episodes = animeDetails?.total_episodes {
        LabeledContent {
          Text(String(total_episodes))
            .fontDesign(.monospaced)
            .foregroundStyle(.secondary)
        } label: {
          Label(
            "Total Episodes", systemImage: "checkmark.arrow.trianglehead.counterclockwise"
          )
          .foregroundStyle(.secondary)
        }
      }
    }

    if animeDetails?.anime_type == "movie" {
      if let country = animeDetails?.country {
        LabeledContent {
          Text(country)
            .fontDesign(.monospaced)
            .foregroundStyle(.secondary)
        } label: {
          Label("Country", systemImage: "flag")
            .foregroundStyle(.secondary)
        }
      }
    } else {
      let watched = animeWatchlist?.episodes_watched ?? 0
      let total = animeDetails?.total_episodes ?? 0
      let percentage = total > 0 ? Int((Double(watched) / Double(total)) * 100) : 0
      LabeledContent {
        Text("\(percentage)%")
          .fontDesign(.monospaced)
          .foregroundStyle(.secondary)
      } label: {
        Label("Watched", systemImage: "percent")
          .foregroundStyle(.secondary)
      }
    }

    if let simklRating = animeDetails?.ratings?.simkl?.rating {
      LabeledContent {
        Text(String(simklRating))
          .fontDesign(.monospaced)
          .foregroundStyle(.secondary)
      } label: {
        Label("SIMKL Rating", systemImage: "trophy")
          .foregroundStyle(.secondary)
      }
    }
  }
}
