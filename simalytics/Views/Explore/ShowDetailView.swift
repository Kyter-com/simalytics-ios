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
  @Environment(Auth.self) private var auth
  @Environment(\.modelContext) private var modelContext
  @State private var showDetails: ShowDetailsModel?
  @State private var showWatchlist: ShowWatchlistModel?
  @State private var cast: [TMDBCastMember] = []
  @State private var isLoading = true
  @State private var isLoadingEpisodes = false
  @State private var episodeLoadError: String?
  @State private var episodeBrowser: EpisodeBrowserModel?
  @State private var watchlistStatus: String?
  @State private var localRating: Double = 0
  @State private var memoText: String = ""
  @State private var privacySelection: String = "Public"
  var simkl_id: Int

  // MARK: - Sheets
  @State private var showingJustWatchSheet = false
  @State private var showingMemoSheet = false

  private func loadEpisodes() async {
    guard !isLoadingEpisodes else { return }
    isLoadingEpisodes = true
    episodeLoadError = nil
    defer { isLoadingEpisodes = false }
    do {
      let episodes = try await ShowDetailView.getShowEpisodes(simkl_id)
      try Task.checkCancellation()
      let browser = EpisodeBrowserModel(
        episodes: episodes.map { EpisodeListItem(show: $0) },
        seasons: showWatchlist?.seasons, isAnime: false)
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
    // Attached outside the loading switch so it keeps running after the page
    // appears; episodes and cast then fill in below the title.
    content.task(id: simkl_id) { await load() }
  }

  private func load() async {
    showDetails = await ShowDetailView.getShowDetails(simkl_id)
    showWatchlist = await ShowDetailView.getShowWatchlist(simkl_id, auth.simklAccessToken)
    watchlistStatus = showWatchlist?.list

    if let fanart = showDetails?.fanart {
      let imageURL = URL(string: "\(SIMKL_CDN_URL)/fanart/\(fanart)_mobile.jpg")!
      KingfisherManager.shared.retrieveImage(with: imageURL) { _ in }
    }

    do {
      let shows = try modelContext.fetch(
        FetchDescriptor<V1.SDShows>(predicate: #Predicate { $0.simkl == simkl_id })
      )
      if let show = shows.first {
        let simklRating = Double(show.user_rating ?? 0)
        self.localRating = simklRating
        self.memoText = show.memo_text ?? ""
        self.privacySelection = show.memo_is_private ?? true ? "Private" : "Public"
      }
    } catch {}

    // Long catalogs shouldn't hold the whole page behind a spinner.
    isLoading = false
    guard showDetails != nil else { return }
    await loadEpisodes()
    cast = await getCast(auth.simklAccessToken, showDetails?.ids?.tmdb, mediaType: "tv")
  }

  @ViewBuilder private var content: some View {
    if isLoading {
      ProgressView("Loading...")
    } else if showDetails == nil {
      ContentUnavailableView {
        Label("Show unavailable", systemImage: "tv")
      } description: {
        Text("Simkl didn't return details for this show.")
      }
    } else {
      ScrollViewReader { scrollProxy in
        ScrollView {
          ParallaxBackgroundImage(fanart: showDetails?.fanart)

          MediaDetailHeader(poster: showDetails?.poster, title: showDetails?.title ?? "show") {
            ShowHeaderInfo(showDetails: $showDetails, showWatchlist: $showWatchlist)
          } status: {
            if !auth.simklAccessToken.isEmpty {
              ShowWatchlistButton(status: $watchlistStatus, simkl_id: simkl_id)
            }
          }

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
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding([.leading, .trailing])
              .fontDesign(.monospaced)
          }

          if let overview = showDetails?.overview {
            Text(overview)
              .font(.footnote)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding([.leading, .trailing])
              .padding(.top, 8)
          }

          if watchlistStatus != nil {
            MediaRatingView(simklID: simkl_id, type: .show, rating: $localRating)
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

          Recommendations(recommendations: showDetails?.users_recommendations)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .sheet(isPresented: $showingMemoSheet) {
        MemoView(
          memoText: $memoText,
          privacySelection: $privacySelection,
          simkl_id: simkl_id,
          item_status: watchlistStatus ?? "",
          simkl_type: "show"
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
      }
      .sheet(isPresented: $showingJustWatchSheet) {
        JustWatchView(
          tmdbId: showDetails?.ids?.tmdb,
          mediaType: "tv"
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
      return await ShowDetailView.markEpisodeWatched(
        auth.simklAccessToken, showDetails?.title ?? "", simkl_id, season, number)
    }
    return await ShowDetailView.markEpisodeUnwatched(
      auth.simklAccessToken, showDetails?.title ?? "", simkl_id, season, number)
  }

  private func commitEpisode(_ episode: EpisodeListItem, watched: Bool) {
    invalidateUpNextCache(modelContainer: modelContext.container)
    if watched, let season = episode.watchSeason, let number = episode.number {
      optimisticallyClearNextToWatch(
        simklId: simkl_id, season: season, episode: number, kind: .tv,
        modelContainer: modelContext.container)
    }
  }

  private func reconcileEpisodes() async -> [WatchlistSeason]? {
    #if DEBUG
      if ScreenshotMode.isActive { return nil }
    #endif
    guard !auth.simklAccessToken.isEmpty else { return nil }
    let token = auth.simklAccessToken
    let container = modelContext.container
    // Library and Up Next catch up in the background; the episode list only
    // needs this show's watched episodes, so it unlocks after that request.
    Task { await syncLatestActivities(token, modelContainer: container, forceRefresh: true) }
    guard let refreshed = await ShowDetailView.getShowWatchlist(simkl_id, token),
      !Task.isCancelled
    else { return nil }
    showWatchlist = refreshed
    watchlistStatus = refreshed.list
    return refreshed.seasons
  }

}
