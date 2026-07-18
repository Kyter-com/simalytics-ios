//
//  Recommendations.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/30/25.
//

import SwiftData
import SwiftUI

struct Recommendations: View {
  var recommendations: [RecommendationModel]?
  @AppStorage("hideAnime") private var hideAnime = false
  @Environment(\.modelContext) private var context
  @State private var localSnapshots = LocalMediaSnapshots()

  private var visibleRecommendations: [RecommendationModel] {
    (recommendations ?? []).filter { !hideAnime || $0.type != "anime" }
  }

  private var localSnapshotRequest: LocalMediaSnapshots.Request {
    LocalMediaSnapshots.Request(
      movieIDs: visibleRecommendations.filter { $0.type == "movie" }.map { $0.ids.simkl },
      showIDs: visibleRecommendations.filter { $0.type == "tv" }.map { $0.ids.simkl },
      animeIDs: visibleRecommendations.filter { $0.type == "anime" }.map { $0.ids.simkl }
    )
  }

  private func refreshLocalSnapshots() {
    localSnapshots = LocalMediaSnapshots.fetch(localSnapshotRequest, context: context)
  }

  var body: some View {
    Group {
      if !visibleRecommendations.isEmpty {
        VStack(alignment: .leading) {
          Group {
            ExploreGroupTitle(title: "Users Also Watched")

            ScrollView(.horizontal) {
              HStack(spacing: 16) {
                ForEach(
                  visibleRecommendations, id: \.ids.simkl
                ) { item in
                  NavigationLink(
                    destination: {
                      let type = item.type
                      let id = item.ids.simkl
                      if type == "tv" {
                        ShowDetailView(simkl_id: id)
                      } else if type == "movie" {
                        MovieDetailView(simkl_id: id)
                      } else if type == "anime" {
                        AnimeDetailView(simkl_id: id)
                      }
                    }
                  ) {
                    VStack {
                      CustomKFImage(
                        imageUrlString: item.poster != nil
                          ? "\(SIMKL_CDN_URL)/posters/\(item.poster!)_m.jpg"
                          : nil,
                        memoryCacheOnly: true,
                        height: 147,
                        width: 100
                      )
                      ExploreTitle(title: item.title)
                    }
                  }
                  .buttonStyle(.plain)
                  .contextMenu {
                    ShareLink(
                      item: URL(
                        string:
                          "https://simkl.com/\(item.type == "tv" ? "tv" : item.type)/\(item.ids.simkl)"
                      )!,
                      subject: Text(item.title),
                      message: Text("Check out \(item.title)!")
                    ) {
                      Label("Share", systemImage: "square.and.arrow.up")
                    }
                  } preview: {
                    SmartPreviewCard(
                      simklId: item.ids.simkl,
                      title: item.title,
                      year: item.year,
                      poster: item.poster,
                      mediaType: item.type,
                      localData: localSnapshots.data(simklID: item.ids.simkl, mediaType: item.type)
                    )
                  }
                }
              }
              .padding([.leading, .trailing, .bottom])
            }
          }
        }
      }
    }
    .task(id: localSnapshotRequest) {
      refreshLocalSnapshots()
    }
    .onReceive(NotificationCenter.default.publisher(for: .localMediaSnapshotsDidChange)) { _ in
      refreshLocalSnapshots()
    }
  }
}
