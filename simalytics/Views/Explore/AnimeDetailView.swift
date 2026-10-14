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
  @Environment(Auth.self) private var auth
  @Environment(\.modelContext) private var modelContext
  @State private var animeWatchlist: AnimeWatchlistModel?
  @State private var animeDetails: AnimeDetailsModel?
  @State private var cast: [TMDBCastMember] = []
  @State private var isLoading = true
  @State private var isLoadingEpisodes = false
  @State private var episodeLoadError: String?
  @State private var episodeBrowser: EpisodeBrowserModel?
  @State private var watchlistStatus: String?
  @State private var localRating: Double = 0
  @State private var showingMemoSheet = false
  @State private var memoText: String = ""
  @State private var privacySelection: String = "Public"
  var simkl_id: Int

  // MARK: - Sheets
  @State private var showingJustWatchSheet = false

  private func loadEpisodes() async {
    guard !isLoadingEpisodes else { return }
    isLoadingEpisodes = true
    episodeLoadError = nil
    defer { isLoadingEpisodes = false }
    do {
      let episodes = try await AnimeDetailView.getAnimeEpisodes(simkl_id, countSeasons: true)
      try Task.checkCancellation()
      let browser = EpisodeBrowserModel(
        episodes: episodes.map { EpisodeListItem(anime: $0) },
        seasons: animeWatchlist?.seasons, isAnime: true)
      if let selected = episodeBrowser?.selectedGroup,
        browser.groups.contains(where: { $0.id == selected })
      {
        browser.selectedGroup = selected
      }
      episodeBrowser = browser

    } catch {
      guard !isSimklCancellationError(error) else { return }
      reportError(error)
      episodeLoadError = "Couldn't load episodes. Check your connection and try again."
    }
  }

  var body: some View {
    if isLoading {
      ProgressView("Loading...")
        .task(id: simkl_id) {
          animeDetails = await AnimeDetailView.getAnimeDetails(simkl_id)
          animeWatchlist = await AnimeDetailView.getAnimeWatchlist(
            simkl_id, auth.simklAccessToken)
          watchlistStatus = animeWatchlist?.list
          await loadEpisodes()

          cast = await getCast(
            auth.simklAccessToken,
            animeDetails?.ids?.tmdb,
            mediaType: animeDetails?.anime_type == "tv" ? "tv" : "movie"
          )

          if let fanart = animeDetails?.fanart {
            let imageURL = URL(string: "\(SIMKL_CDN_URL)/fanart/\(fanart)_mobile.jpg")!
            KingfisherManager.shared.retrieveImage(with: imageURL) { _ in }
          }

          do {
            let animes = try modelContext.fetch(
              FetchDescriptor<V1.SDAnimes>(predicate: #Predicate { $0.simkl == simkl_id })
            )
            if let anime = animes.first {
              let simklRating = Double(anime.user_rating ?? 0)
              self.localRating = simklRating
              self.memoText = anime.memo_text ?? ""
              self.privacySelection = anime.memo_is_private ?? true ? "Private" : "Public"
            }
          } catch {}

          isLoading = false
        }
    } else if animeDetails == nil {
      ContentUnavailableView {
        Label("Anime unavailable", systemImage: "sparkles.tv")
      } description: {
        Text("Simkl didn't return details for this anime.")
      }
    } else {
      ScrollViewReader { scrollProxy in
        ScrollView {
          ParallaxBackgroundImage(fanart: animeDetails?.fanart)

          MediaDetailHeader(poster: animeDetails?.poster, title: animeDetails?.title ?? "anime") {
            AnimeHeaderInfo(animeDetails: $animeDetails, animeWatchlist: $animeWatchlist)
            if !auth.simklAccessToken.isEmpty {
              AnimeWatchlistButton(status: $watchlistStatus, simkl_id: simkl_id)
            }
          }

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
              .foregroundStyle(.secondary)
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
            MediaRatingView(simklID: simkl_id, type: .anime, rating: $localRating)
          }

          MediaActionButtons(
            canAddMemo: watchlistStatus != nil,
            addMemo: { showingMemoSheet = true },
            whereToWatch: { showingJustWatchSheet = true })

          EpisodeLoadStatus(
            isLoading: isLoadingEpisodes, errorMessage: episodeLoadError,
            retry: { await loadEpisodes() })

          if let episodeBrowser, !episodeBrowser.groups.isEmpty {
            MediaEpisodeSection(
              model: episodeBrowser, scrollProxy: scrollProxy,
              canEdit: !auth.simklAccessToken.isEmpty,
              mutation: mutateEpisode, commit: commitEpisode, reconcile: reconcileEpisodes
            )
            .padding(.top)
          }

          CastRow(cast: cast)

          Recommendations(recommendations: animeDetails?.users_recommendations ?? [])
        }
      }
      .sheet(isPresented: $showingMemoSheet) {
        MemoView(
          memoText: $memoText, privacySelection: $privacySelection, simkl_id: simkl_id,
          item_status: watchlistStatus ?? "", simkl_type: "anime"
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
      }
      .sheet(isPresented: $showingJustWatchSheet) {
        JustWatchView(
          tmdbId: animeDetails?.ids?.tmdb,
          mediaType: animeDetails?.anime_type == "tv" ? "tv" : "movie"
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
      }

    }
  }
  private func mutateEpisode(_ episode: EpisodeListItem, watched: Bool) async -> SimklMutationResult
  {
    guard !auth.simklAccessToken.isEmpty, let season = episode.watchSeason,
      let number = episode.number
    else { return .failed(userMessage: "Sign in to update this episode.") }
    #if DEBUG
      if ScreenshotMode.isActive { return ScreenshotEpisodeFixtures.mutationResult }
    #endif
    if watched {
      return await AnimeDetailView.markEpisodeWatched(
        auth.simklAccessToken, animeDetails?.title ?? "", simkl_id, season, number)
    }
    return await AnimeDetailView.markEpisodeUnwatched(
      auth.simklAccessToken, animeDetails?.title ?? "", simkl_id, season, number)
  }

  private func commitEpisode(_ episode: EpisodeListItem, watched: Bool) {
    invalidateUpNextCache(modelContainer: modelContext.container)
    if watched, let season = episode.watchSeason, let number = episode.number {
      optimisticallyClearNextToWatch(
        simklId: simkl_id, season: season, episode: number, kind: .anime,
        modelContainer: modelContext.container)
    }
  }

  private func reconcileEpisodes() async -> [WatchlistSeason]? {
    #if DEBUG
      if ScreenshotMode.isActive { return nil }
    #endif
    guard !auth.simklAccessToken.isEmpty else { return nil }
    await syncLatestActivities(
      auth.simklAccessToken, modelContainer: modelContext.container, forceRefresh: true)
    guard !Task.isCancelled,
      let refreshed = await AnimeDetailView.getAnimeWatchlist(simkl_id, auth.simklAccessToken),
      !Task.isCancelled
    else { return nil }
    animeWatchlist = refreshed
    watchlistStatus = refreshed.list
    return refreshed.seasons
  }

}
