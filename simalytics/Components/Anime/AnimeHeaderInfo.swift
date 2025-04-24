//
//  AnimeHeaderInfo.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/31/25.
//

import SwiftUI

struct AnimeHeaderInfo: View {
  @Binding var animeDetails: AnimeDetailsModel?

  var body: some View {
    if let year = animeDetails?.year_start_end {
      LabeledContent {
        Text(String(year).replacingOccurrences(of: " - ", with: "-"))
          .fontDesign(.monospaced)
          .foregroundColor(.secondary)
      } label: {
        Label("Year", systemImage: "calendar")
          .foregroundColor(.secondary)
      }
    }
    if let runtime = animeDetails?.runtime {
      LabeledContent {
        Text("\(String(runtime)) Min")
          .fontDesign(.monospaced)
          .foregroundColor(.secondary)
      } label: {
        Label("Ep. Runtime", systemImage: "clock")
          .foregroundColor(.secondary)
      }
    }
    if let total_episodes = animeDetails?.total_episodes {
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
    if let progress = animeDetails?.total_episodes {
      LabeledContent {
        Text("0%")
          .fontDesign(.monospaced)
          .foregroundColor(.secondary)
      } label: {
        Label("Watched", systemImage: "percent")
          .foregroundColor(.secondary)
      }
    }
    if let simklRating = animeDetails?.ratings?.simkl?.rating {
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
