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
  }
}
