//
//  ShowHeaderInfo.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/27/25.
//

import SwiftUI

struct ShowHeaderInfo: View {
  @Binding var showDetails: ShowDetailsModel?
  @Binding var showWatchlist: ShowWatchlistModel?

  var body: some View {
    if let year = showDetails?.year_start_end {
      LabeledContent {
        Text(String(year).replacingOccurrences(of: " - ", with: "-"))
          .fontDesign(.monospaced)
          .foregroundStyle(.secondary)
      } label: {
        Label("Year", systemImage: "calendar")
          .foregroundStyle(.secondary)
      }
    }
    if let runtime = showDetails?.runtime {
      LabeledContent {
        Text("\(String(runtime)) Min")
          .fontDesign(.monospaced)
          .foregroundStyle(.secondary)
      } label: {
        Label("Ep. Runtime", systemImage: "clock")
          .foregroundStyle(.secondary)
      }
    }
    if let total_episodes = showDetails?.total_episodes {
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
    let percentage = watchedPercentage(
      seasons: showWatchlist?.seasons, episodesWatched: showWatchlist?.episodes_watched,
      total: showDetails?.total_episodes)
    LabeledContent {
      Text("\(percentage)%")
        .fontDesign(.monospaced)
        .foregroundStyle(.secondary)
    } label: {
      Label("Watched", systemImage: "percent")
        .foregroundStyle(.secondary)
    }
    if let simklRating = showDetails?.ratings?.simkl?.rating {
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
