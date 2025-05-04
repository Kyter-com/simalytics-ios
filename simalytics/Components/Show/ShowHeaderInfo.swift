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
          .foregroundColor(.secondary)
      } label: {
        Label("Year", systemImage: "calendar")
          .foregroundColor(.secondary)
      }
    }
    if let runtime = showDetails?.runtime {
      LabeledContent {
        Text("\(String(runtime)) Min")
          .fontDesign(.monospaced)
          .foregroundColor(.secondary)
      } label: {
        Label("Ep. Runtime", systemImage: "clock")
          .foregroundColor(.secondary)
      }
    }
    if let total_episodes = showDetails?.total_episodes {
      LabeledContent {
        Text(String(total_episodes))
          .fontDesign(.monospaced)
          .foregroundColor(.secondary)
      } label: {
        Label(
          "Total Episodes", systemImage: "checkmark.arrow.trianglehead.counterclockwise"
        )
        .foregroundColor(.secondary)
      }
    }
    let watched = showWatchlist?.episodes_watched ?? 0
    let total = showDetails?.total_episodes ?? 0
    let percentage = total > 0 ? Int((Double(watched) / Double(total)) * 100) : 0
    LabeledContent {
      Text("\(percentage)%")
        .fontDesign(.monospaced)
        .foregroundColor(.secondary)
    } label: {
      Label("Watched", systemImage: "percent")
        .foregroundColor(.secondary)
    }
    if let simklRating = showDetails?.ratings?.simkl?.rating {
      LabeledContent {
        Text(String(simklRating))
          .fontDesign(.monospaced)
          .foregroundColor(.secondary)
      } label: {
        Label("SIMKL Rating", systemImage: "trophy")
          .foregroundColor(.secondary)
      }
    }
  }
}
