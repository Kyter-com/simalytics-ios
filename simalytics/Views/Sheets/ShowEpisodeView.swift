//
//  ShowEpisodeView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 6/5/25.
//

import SwiftUI

struct ShowEpisodeView: View {
  @Environment(\.dismiss) var dismiss
  var episode: ShowEpisodeModel?
  var body: some View {
    Text(episode?.title ?? "")
  }
}

//   Button {
//     Task {
//       await ShowDetailView.markEpisodeWatched(
//         auth.simklAccessToken,
//         showDetails?.title ?? "",
//         simkl_id,
//         episode.season ?? 0,
//         episode.episode ?? 0,
//         episode.ids.simkl_id
//       )
//       showWatchlist = await ShowDetailView.getShowWatchlist(simkl_id, auth.simklAccessToken)
//     }
//   } label: {
//     Label("Watched", systemImage: "checkmark.circle")
//   }
