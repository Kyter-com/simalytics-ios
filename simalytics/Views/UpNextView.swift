//
//  UpNextView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//

import SwiftUI

struct UpNextView: View {
  @EnvironmentObject private var auth: Auth
  @State private var shows: [UpNextShowModel_show] = []
  @State private var searchText: String = ""
  @Environment(GlobalLoadingIndicator.self) private var globalLoadingIndicator
  var filteredShows: [UpNextShowModel_show] {
    if searchText.isEmpty {
      return shows
    } else {
      return shows.filter { show in
        show.show.title.localizedStandardContains(searchText)
          || (show.next_to_watch_info?.title?.localizedStandardContains(searchText) ?? false)
      }
    }
  }

  var body: some View {
    NavigationView {
      List(filteredShows, id: \.show.ids.simkl) { showItem in
        HStack {
          CustomKFImage(
            imageUrlString: "\(SIMKL_CDN_URL)/posters/\(showItem.show.poster)_m.jpg",
            memoryCacheOnly: false,
            height: 118,
            width: 80
          )

          VStack(alignment: .leading) {
            Text(showItem.show.title)
              .font(.headline)
              .padding(.top, 8)
            if let title = showItem.next_to_watch_info?.title {
              Text(title)
                .font(.subheadline)
            }
            Spacer()
            if let season = showItem.next_to_watch_info?.season {
              Text("Season \(season)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            if let episode = showItem.next_to_watch_info?.episode {
              Text("Episode \(episode)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            Spacer()
          }
        }
        .swipeActions(edge: .trailing) {
          Button {
            Task {
              await UpNextView.markAsWatched(show: showItem, accessToken: auth.simklAccessToken)
              shows = await UpNextView.fetchShows(accessToken: auth.simklAccessToken)
            }
          } label: {
            Label("Watched", systemImage: "checkmark.circle")
          }
          .tint(.green)
        }
      }
      .listStyle(.inset)
      .searchable(text: $searchText, placement: .automatic)
      .refreshable {
        shows = await UpNextView.fetchShows(accessToken: auth.simklAccessToken)
      }
      .task { shows = await UpNextView.fetchShows(accessToken: auth.simklAccessToken) }
      .navigationTitle("Up Next")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          if globalLoadingIndicator.isSyncing {
            ProgressView()
          }
        }
      }
    }
  }
}
