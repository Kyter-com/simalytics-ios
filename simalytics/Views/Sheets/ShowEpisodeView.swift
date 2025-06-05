//
//  ShowEpisodeView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 6/5/25.
//

import SwiftUI

struct ShowEpisodeView: View {
  @Environment(\.dismiss) var dismiss
  @Binding var episode: ShowEpisodeModel?

  var body: some View {
    VStack {
      HStack {
        CustomKFImage(
          imageUrlString: episode?.img != nil ? "\(SIMKL_CDN_URL)/episodes/\(episode?.img! ?? "")_w.jpg" : NO_IMAGE_URL,
          memoryCacheOnly: true,
          height: 70.42,
          width: 125
        )

        Text(episode?.title ?? "Title Unavailable")
          .font(.headline)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      // Full width button
      Button(action: {
        print("Button tapped")
      }) {
        Text("Watch Now")
          .frame(maxWidth: .infinity)
          .padding()
          .background(Color.blue)
          .foregroundColor(.white)
          .cornerRadius(8)
      }

      if let description = episode?.description {
        Text(description)
          .font(.footnote)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding([.top], 6)
      }
    }
    .padding([.leading, .trailing, .top])
    Spacer()
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
