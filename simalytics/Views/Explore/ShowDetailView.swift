//
//  ShowDetailView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/6/25.
//

import Kingfisher
import SwiftData
import SwiftUI

struct ShowDetailView: View {
  @EnvironmentObject private var auth: Auth
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.modelContext) private var modelContext
  @State private var showDetails: ShowDetailsModel?
  @State private var showWatchlist: ShowWatchlistModel?
  @State private var showEpisodes: [ShowEpisodeModel] = []
  @State private var isLoading = true
  @State private var watchlistStatus: String?
  @State private var filteredEpisodes: [ShowEpisodeModel] = []
  @State private var selectedSeason: String?
  @State private var localRating: Double = 0
  @State private var originalRating: Double = 0
  @State private var showingMemoSheet = false
  @State private var memoText: String = ""
  @State private var privacySelection: String = "Public"
  @AppStorage("blurEpisodeImages") private var blurImages: Bool = false
  var simkl_id: Int

  var seasons: [Int] {
    showEpisodes.compactMap { $0.season }.unique().sorted()
  }

  var hasSpecials: Bool {
    showEpisodes.contains { $0.type == "special" }
  }

  func hasWatchedEpisode(season targetSeason: Int, episode targetEpisode: Int) -> Bool {
    guard let seasons = showWatchlist?.seasons else { return false }
    for season in seasons {
      guard let episodes = season.episodes else { continue }
      if episodes.contains(where: {
        $0.number == targetEpisode && season.number == targetSeason && $0.watched == true
      }) {
        return true
      }
    }
    return false
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

            Task { @MainActor [modelContext, simkl_id] in
              do {
                let shows = try modelContext.fetch(
                  FetchDescriptor<V1.SDShows>(predicate: #Predicate { $0.simkl == simkl_id })
                )
                if let show = shows.first {
                  self.localRating = Double(show.user_rating ?? 0)
                  self.originalRating = Double(show.user_rating ?? 0)
                  self.memoText = show.memo_text ?? ""
                  self.privacySelection = show.memo_is_private ?? true ? "Private" : "Public"
                }
              } catch {}
            }
          }
        }
    } else {
      ScrollView {
        ParallaxBackgroundImage(fanart: showDetails?.fanart)

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
            ShowHeaderInfo(showDetails: $showDetails, showWatchlist: $showWatchlist)
            Spacer()
            if !auth.simklAccessToken.isEmpty {
              ShowWatchlistButton(status: $watchlistStatus, simkl_id: simkl_id)
            }
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

        RatingView(
          maxRating: 10,
          rating: $localRating,
          starColor: .blue,
          starRounding: .roundToFullStar,
          size: 20
        )
        .padding([.leading, .trailing])
        .padding(.top, 8)

        if watchlistStatus != nil {
          Button(action: {
            showingMemoSheet.toggle()
          }) {
            Label("Add Memo", systemImage: "square.and.pencil")
              .padding([.leading, .trailing])
              .padding(.top, 8)
          }
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
                  Image(systemName: "chevron.up.chevron.down")
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
            }

            List(filteredEpisodes, id: \.ids.simkl_id) { episode in
              HStack {
                ZStack(alignment: .bottomTrailing) {
                  ZStack {
                    CustomKFImage(
                      imageUrlString: episode.img != nil
                        ? "\(SIMKL_CDN_URL)/episodes/\(episode.img!)_w.jpg" : NO_IMAGE_URL,
                      memoryCacheOnly: true,
                      height: 70.42,
                      width: 125
                    )
                    if blurImages {
                      Rectangle()
                        .fill(Color.clear)
                        .frame(width: 125, height: 70.42)
                        .background(BlurView(style: .regular))
                        .cornerRadius(8)
                    }
                  }
                  if hasWatchedEpisode(season: episode.season ?? -1, episode: episode.episode ?? -1) {
                    Image(systemName: "checkmark.circle")
                      .resizable()
                      .scaledToFit()
                      .foregroundColor(colorScheme == .dark ? Color.green.darker() : Color.green)
                      .frame(width: 14, height: 14)
                      .padding(4)
                      .background(colorScheme == .dark ? Color.black : Color.white)
                      .cornerRadius(8)
                      .offset(x: -2, y: -2)
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

        Recommendations(recommendations: showDetails?.users_recommendations)
      }
      .onChange(of: localRating) {
        if localRating == originalRating { return }
        Task {
          await ShowDetailView.addShowRating(simkl_id, auth.simklAccessToken, localRating)
          await syncLatestActivities(auth.simklAccessToken, modelContainer: modelContext.container)
        }
      }
      .sheet(isPresented: $showingMemoSheet) {
        MemoView(
          memoText: $memoText, privacySelection: $privacySelection, simkl_id: simkl_id, item_status: watchlistStatus ?? "", simkl_type: "show"
        )
        .presentationDetents([.medium, .large])
      }
    }
  }
}
