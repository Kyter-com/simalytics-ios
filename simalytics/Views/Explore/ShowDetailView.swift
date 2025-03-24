//
//  ShowDetailView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/6/25.
//

import Kingfisher
import SwiftUI

// TODO: MOVE OUT
extension Array where Element: Hashable {
  func unique() -> [Element] {
    Array(Set(self))
  }
}

struct ShowDetailView: View {
  @EnvironmentObject private var auth: Auth
  @Environment(\.colorScheme) var colorScheme
  @State private var showDetails: ShowDetailsModel?
  @State private var showWatchlist: ShowWatchlistModel?
  @State private var showEpisodes: [ShowEpisodeModel] = []
  @State private var isLoading = true
  @State private var watchlistStatus: String?
  var simkl_id: Int

  var seasons: [Int] {
    showEpisodes.compactMap { $0.season }.unique().sorted()
  }

  var hasSpecials: Bool {
    showEpisodes.contains { $0.type == "special" }
  }

  var body: some View {
    if isLoading {
      ProgressView("Loading...")
        .onAppear {
          Task {
            showDetails = await ShowDetailView.getShowDetails(simkl_id)
            showWatchlist = await ShowDetailView.getShowWatchlist(
              simkl_id, auth.simklAccessToken)
            watchlistStatus = showWatchlist?.list
            showEpisodes = await ShowDetailView.getShowEpisodes(simkl_id)

            if let fanart = showDetails?.fanart {
              let imageURL = URL(string: "\(SIMKL_CDN_URL)/fanart/\(fanart)_mobile.jpg")!
              KingfisherManager.shared.retrieveImage(with: imageURL) { _ in }
            }

            isLoading = false
          }
        }
    } else {
      ScrollView {
        if let fanart = showDetails?.fanart {
          GeometryReader { reader in
            if reader.frame(in: .global).minY > -150 {

              KFImage(
                URL(string: "\(SIMKL_CDN_URL)/fanart/\(fanart)_mobile.jpg")
              )
              .serialize(as: .JPEG)
              .cacheMemoryOnly(true)
              .memoryCacheExpiration(.days(7))
              .fade(duration: 0.10)
              .resizable()
              .aspectRatio(contentMode: .fill)
              .offset(y: -reader.frame(in: .global).minY)
              .frame(
                width: UIScreen.main.bounds.width,
                height: reader.frame(in: .global).minY > 0
                  ? reader.frame(in: .global).minY + 150 : 150
              )
            }
          }
          .frame(height: 150)
        }

        HStack {
          if let poster = showDetails?.poster {
            CustomKFImage(
              imageUrlString: "\(SIMKL_CDN_URL)/posters/\(poster)_m.jpg",
              memoryCacheOnly: true,
              height: 220.59,
              width: 150
            )
            .overlay(
              RoundedRectangle(cornerRadius: 8).stroke(
                colorScheme == .dark ? Color.black : Color.white, lineWidth: 4)
            )
          }
          Spacer()
          VStack(alignment: .leading) {
            Spacer()
              .frame(height: 8)
            Spacer()
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
            if let progress = showDetails?.total_episodes {
              LabeledContent {
                Text("0%")
                  .fontDesign(.monospaced)
                  .foregroundColor(.secondary)
              } label: {
                Label("Watched", systemImage: "percent")
                  .foregroundColor(.secondary)
              }
            }
            if let simklRating = showDetails?.ratings?.simkl?.rating {
              LabeledContent {
                Text(String(simklRating))
                  .fontDesign(.monospaced)
                  .foregroundColor(.secondary)
              } label: {
                Label("SIMKL Rating", systemImage: "number")
                  .foregroundColor(.secondary)
              }
            }
            Spacer()
            ShowWatchlistButton(status: $watchlistStatus, simkl_id: simkl_id)
            Spacer()
              .frame(height: 2)
          }
        }
        .padding([.leading, .trailing])
        .offset(y: -10)
        .background(colorScheme == .dark ? Color.black : Color.white)

        if let title = showDetails?.title {
          Text(title)
            .font(.title)
            .bold()
            .fontDesign(.rounded)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.leading, .trailing])
            .offset(y: -10)
        }

        if let genres = showDetails?.genres {
          Text(genres.joined(separator: " • "))
            .font(.footnote)
            .foregroundColor(.secondary)
            .padding([.leading, .trailing])
            .fontDesign(.monospaced)
        }

        if let overview = showDetails?.overview {
          Text(overview)
            .font(.footnote)
            .padding([.leading, .trailing])
            .padding(.top, 8)
        }

        Spacer()

        if !seasons.isEmpty || hasSpecials {
          VStack {
            ForEach(showEpisodes, id: \.ids.simkl_id) { episode in
              Text(episode.title ?? "")
            }
          }
        }

        if let recommendations = showDetails?.users_recommendations?.filter({ $0.poster != nil }) {
          VStack(alignment: .leading) {
            Group {
              ExploreGroupTitle(title: "Users Also Watched")

              ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 16) {
                  ForEach(
                    recommendations, id: \.ids.simkl
                  ) { movieItem in
                    VStack {
                      CustomKFImage(
                        imageUrlString: "\(SIMKL_CDN_URL)/posters/\(movieItem.poster ?? "")_m.jpg",
                        memoryCacheOnly: true,
                        height: 147,
                        width: 100
                      )
                      ExploreTitle(title: movieItem.title)
                    }
                  }
                }
                .padding([.leading, .trailing, .bottom])
              }
            }
          }
        }
      }
    }
  }
}
