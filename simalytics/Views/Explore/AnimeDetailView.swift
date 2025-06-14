//
//  AnimeDetailView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/6/25.
//

import Kingfisher
import SwiftData
import SwiftUI

struct AnimeDetailView: View {
  @EnvironmentObject private var auth: Auth
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.modelContext) private var modelContext
  @State private var animeWatchlist: AnimeWatchlistModel?
  @State private var animeDetails: AnimeDetailsModel?
  @State private var animeEpisodes: [AnimeEpisodeModel] = []
  @State private var filteredEpisodes: [AnimeEpisodeModel] = []
  @State private var isLoading = true
  @State private var watchlistStatus: String?
  @State private var selectedSeason: String?
  @State private var localRating: Double = 0
  @State private var originalRating: Double = 0
  @State private var showingMemoSheet = false
  @State private var memoText: String = ""
  @State private var privacySelection: String = "Public"
  @AppStorage("blurEpisodeImages") private var blurImages: Bool = false
  @State private var selectedEpisode: AnimeEpisodeModel?
  @State private var showingShowEpisodeSheet = false
  var simkl_id: Int

  // MARK: - JustWatch Integration
  @State private var showingJustWatchSheet = false

  var seasons: [Int] {
    animeEpisodes.compactMap { $0.season }.unique().filter { $0 > 0 }.sorted()
  }

  var hasSpecials: Bool {
    animeEpisodes.contains { $0.type == "special" }
  }

  func hasWatchedEpisode(season targetSeason: Int, episode targetEpisode: Int) -> Bool {
    guard let seasons = animeWatchlist?.seasons else { return false }
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
            animeDetails = await AnimeDetailView.getAnimeDetails(simkl_id)
            animeWatchlist = await AnimeDetailView.getAnimeWatchlist(
              simkl_id, auth.simklAccessToken)
            watchlistStatus = animeWatchlist?.list
            animeEpisodes = await AnimeDetailView.getAnimeEpisodes(simkl_id)

            if let fanart = animeDetails?.fanart {
              let imageURL = URL(string: "\(SIMKL_CDN_URL)/fanart/\(fanart)_mobile.jpg")!
              KingfisherManager.shared.retrieveImage(with: imageURL) { _ in }
            }

            // Setup initial filteredShows to Season 1 or Specials if nothing is aired yet
            if !animeEpisodes.filter({ $0.season! == 1 }).isEmpty {
              filteredEpisodes = animeEpisodes.filter({ $0.season == 1 })
              selectedSeason = "Season 1"
            } else if !animeEpisodes.filter({ $0.type == "special" }).isEmpty {
              filteredEpisodes = animeEpisodes.filter({ $0.type == "special" })
              selectedSeason = "Specials"
            } else {
              filteredEpisodes = []
            }

            isLoading = false

            Task { @MainActor [modelContext, simkl_id] in
              do {
                let animes = try modelContext.fetch(
                  FetchDescriptor<V1.SDAnimes>(predicate: #Predicate { $0.simkl == simkl_id })
                )
                if let anime = animes.first {
                  self.localRating = Double(anime.user_rating ?? 0)
                  self.originalRating = Double(anime.user_rating ?? 0)
                  self.memoText = anime.memo_text ?? ""
                  self.privacySelection = anime.memo_is_private ?? true ? "Private" : "Public"
                }
              } catch {}
            }
          }
        }
    } else {
      ScrollView {
        ParallaxBackgroundImage(fanart: animeDetails?.fanart)

        HStack {
          if let poster = animeDetails?.poster {
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
            AnimeHeaderInfo(animeDetails: $animeDetails, animeWatchlist: $animeWatchlist)
            Spacer()
            if !auth.simklAccessToken.isEmpty {
              AnimeWatchlistButton(status: $watchlistStatus, simkl_id: simkl_id)
            }
            Spacer()
              .frame(height: 2)
          }
        }
        .padding([.leading, .trailing])
        .offset(y: -10)
        .background(colorScheme == .dark ? Color.black : Color.white)

        if let title = animeDetails?.title {
          Text(title)
            .font(.title)
            .bold()
            .fontDesign(.rounded)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.leading, .trailing])
            .offset(y: -10)
        }

        if let genres = animeDetails?.genres {
          Text(genres.joined(separator: " • "))
            .font(.footnote)
            .foregroundColor(.secondary)
            .padding([.leading, .trailing])
            .fontDesign(.monospaced)
        }

        if let overview = animeDetails?.overview {
          Text(overview.stripHTML)
            .font(.footnote)
            .padding([.leading, .trailing])
            .padding(.top, 8)
        }

        if watchlistStatus != nil {
          RatingView(
            maxRating: 10,
            rating: $localRating,
            starColor: .blue,
            starRounding: .roundToFullStar,
            size: 20
          )
          .padding([.leading, .trailing])
          .padding(.top, 8)
        }

        HStack {
          if watchlistStatus != nil {
            Button(action: {
              showingMemoSheet.toggle()
            }) {
              Label("Add Memo", systemImage: "square.and.pencil")
                .padding([.leading, .trailing])
                .padding(.top, 8)
            }
          }
          Button(action: {
            showingJustWatchSheet.toggle()
          }) {
            Label("Where to Watch", systemImage: "sparkles.tv")
              .padding([.leading, .trailing])
              .padding(.top, 8)
          }
        }

        Spacer()

        if animeDetails?.anime_type == "tv" {
          if !filteredEpisodes.isEmpty {
            VStack(alignment: .leading) {
              HStack {
                Menu {
                  ForEach(seasons, id: \.self) { season in
                    Button(action: {
                      filteredEpisodes = animeEpisodes.filter { $0.season == season }
                      selectedSeason = "Season \(season)"
                    }) {
                      Text("Season \(season)")
                    }
                  }
                  if hasSpecials {
                    Button(action: {
                      filteredEpisodes = animeEpisodes.filter { $0.type == "special" }
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

              ForEach(filteredEpisodes, id: \.ids.simkl_id) { episode in
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
                    if hasWatchedEpisode(
                      season: episode.type == "special" ? 0 : 1, episode: episode.episode ?? -1)
                    {
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
                .padding([.top], 6)
                .onTapGesture {
                  selectedEpisode = episode
                  showingShowEpisodeSheet.toggle()
                }
              }
              .padding([.leading, .trailing])
            }
            .padding(.top)
          }
        }

        Recommendations(recommendations: animeDetails?.users_recommendations ?? [])
      }
      .onChange(of: localRating) {
        if localRating == originalRating { return }
        Task {
          await AnimeDetailView.addAnimeRating(simkl_id, auth.simklAccessToken, localRating)
          await syncLatestActivities(auth.simklAccessToken, modelContainer: modelContext.container)
        }
      }
      .sheet(isPresented: $showingMemoSheet) {
        MemoView(
          memoText: $memoText, privacySelection: $privacySelection, simkl_id: simkl_id,
          item_status: watchlistStatus ?? "", simkl_type: "anime"
        )
        .presentationDetents([.medium, .large])
      }
      .sheet(isPresented: $showingJustWatchSheet) {
        JustWatchView(
          tmdbId: animeDetails?.ids?.tmdb,
          mediaType: animeDetails?.anime_type == "tv" ? "tv" : "movie"
        )
        .presentationDetents([.fraction(0.99)])
      }
      .sheet(isPresented: $showingShowEpisodeSheet) {
        AnimeEpisodeView(
          episode: $selectedEpisode, animeEpisodes: $animeEpisodes, animeWatchlist: $animeWatchlist, animeDetails: $animeDetails, simklId: simkl_id
        )
        .presentationDetents([.medium])
      }
    }
  }
}
