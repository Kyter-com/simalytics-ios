//
//  ShowDetailView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/6/25.
//

import Kingfisher
import SwiftUI

struct ShowDetailView: View {
  @EnvironmentObject private var auth: Auth
  @Environment(\.colorScheme) var colorScheme
  @State private var showDetails: ShowDetailsModel?
  @State private var showWatchlist: ShowWatchlistModel?
  @State private var showEpisodes: [ShowEpisodeModel] = []
  @State private var isLoading = true
  @State private var watchlistStatus: String?
  @State private var filteredEpisodes: [ShowEpisodeModel] = []
  @State private var selectedSeason: String?
  @State private var hideEpisodeImages = false
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

            // Setup initial filteredShows to Season 1 or Specials if nothing is aired yet
            if !showEpisodes.filter({ $0.season == 1 }).isEmpty {
              filteredEpisodes = showEpisodes.filter({ $0.season == 1 })
              selectedSeason = "Season 1"
            } else if !showEpisodes.filter({ $0.type == "special" }).isEmpty {
              filteredEpisodes = showEpisodes.filter({ $0.type == "special" })
              selectedSeason = "Specials"
            } else {
              filteredEpisodes = []
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
          VStack {
            Spacer()
              .frame(height: 8)
            Spacer()
            HeaderInfo(showDetails: $showDetails)
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

        if !filteredEpisodes.isEmpty {
          VStack(alignment: .leading) {
            HStack {
              Menu {
                ForEach(seasons, id: \.self) { season in
                  Button(action: {
                    filteredEpisodes = showEpisodes.filter { $0.season == season }
                    selectedSeason = "Season \(season)"
                  }) {
                    Text("Season \(season)")
                  }
                }
                if hasSpecials {
                  Button(action: {
                    filteredEpisodes = showEpisodes.filter { $0.type == "special" }
                    selectedSeason = "Specials"
                  }) {
                    Text("Specials")
                  }
                }
              } label: {
                HStack {
                  Text(selectedSeason ?? "")
                  Image(systemName: "chevron.right")
                }
                .foregroundColor(.accentColor)
                .bold()
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding([.leading, .trailing])

              Toggle("Blur Images", isOn: $hideEpisodeImages)
                .padding(.trailing)
            }

            List(filteredEpisodes, id: \.ids.simkl_id) { episode in
              HStack {
                ZStack {
                  CustomKFImage(
                    imageUrlString: episode.img != nil
                      ? "\(SIMKL_CDN_URL)/episodes/\(episode.img!)_w.jpg" : NO_IMAGE_URL,
                    memoryCacheOnly: true,
                    height: 70.42,
                    width: 125
                  )
                  if hideEpisodeImages {
                    Rectangle()
                      .fill(Color.clear)
                      .frame(width: 125, height: 70.42)
                      .background(BlurView(style: .regular))
                      .cornerRadius(8)
                  }
                }

                VStack {
                  Text(episode.title)
                    .font(.headline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                  if let description = episode.description {
                    Text(description)
                      .font(.caption)
                      .lineLimit(3)
                      .frame(maxWidth: .infinity, alignment: .leading)
                  }
                }
              }
            }
            .listStyle(.inset)
            .frame(height: CGFloat(filteredEpisodes.count) * 94)
            .scrollDisabled(true)
          }
          .padding(.top)
        }

        if let recommendations = showDetails?.users_recommendations?.filter({ $0.poster != nil }) {
          VStack(alignment: .leading) {
            Group {
              ExploreGroupTitle(title: "Users Also Watched")

              ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 16) {
                  ForEach(
                    recommendations, id: \.ids.simkl
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
                          AnimeDetailView()
                        }
                      }
                    ) {
                      VStack {
                        CustomKFImage(
                          imageUrlString:
                            "\(SIMKL_CDN_URL)/posters/\(item.poster ?? "")_m.jpg",
                          memoryCacheOnly: true,
                          height: 147,
                          width: 100
                        )
                        ExploreTitle(title: item.title)
                      }
                    }
                    .buttonStyle(.plain)
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
