//
//  ContentView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//

import SwiftData
import SwiftUI

struct ContentView: View {
  @Environment(Auth.self) private var auth
  @Environment(GlobalLoadingIndicator.self) private var loading
  @Environment(\.modelContext) private var context
  @State private var storageFailure: StorageFailure?
  @State private var showStorageFailure = false
  @State private var selectedTab: AppTab = ContentView.initialTab
  @State private var searchFocusTrigger = 0
  @State private var searchText = ""
  @State private var searchCategory: SearchCategory = .all
  @AppStorage("hideAnime") private var hideAnime = false

  /// Read the saved launch preference once so changing it in Settings does not
  /// interrupt navigation. Screenshot overrides never alter the saved preference.
  private static var initialTab: AppTab {
    #if DEBUG
      return AppTab.launchTab(
        override: ProcessInfo.processInfo.environment["SIMALYTICS_SCREENSHOT_TAB"])
    #else
      return AppTab.launchTab()
    #endif
  }

  /// The Lists tab's content. Release builds always show the Lists hub; DEBUG
  /// screenshot mode can route to a sub-screen (e.g. the Movies poster-wall grid)
  /// so the harness can capture it with the tab bar intact.
  @ViewBuilder private var listsTab: some View {
    #if DEBUG
      switch ScreenshotMode.screen {
      case "movies-grid": NavigationStack { MovieListView(status: "completed") }
      case "tv-grid": NavigationStack { TVListView(status: "watching") }
      case "show-detail":
        NavigationStack { ShowDetailView(simkl_id: ScreenshotEpisodeFixtures.showID) }
      case "anime-detail":
        NavigationStack { AnimeDetailView(simkl_id: ScreenshotEpisodeFixtures.animeID) }
      case "show-navigation":
        ScreenshotDetailNavigation(title: "TV Shows") {
          ShowDetailView(simkl_id: ScreenshotEpisodeFixtures.showID)
        }
      case "anime-navigation":
        ScreenshotDetailNavigation(title: "Anime") {
          AnimeDetailView(simkl_id: ScreenshotEpisodeFixtures.animeID)
        }
      case "movie-detail":
        NavigationStack { MovieDetailView(simkl_id: ScreenshotDetailFixtures.featuredMovieID) }
      default: ListView()
      }
    #else
      ListView()
    #endif
  }

  private var tabSelection: Binding<AppTab> {
    Binding {
      selectedTab
    } set: { newTab in
      if selectedTab == .search && newTab == .search {
        searchFocusTrigger += 1
      }
      selectedTab = newTab
    }
  }

  var body: some View {
    Group {
      if #available(iOS 26, *) {
        modernTabs.tabBarMinimizeBehavior(.onScrollDown)
      } else {
        tabContent
      }
    }
    .sensoryFeedback(.impact(weight: .light), trigger: selectedTab)
    .onChange(of: hideAnime) {
      if hideAnime && searchCategory == .anime { searchCategory = .all }
    }
    .onChange(of: auth.simklAccessToken) {
      DiscoverLibrary.shared.accountChanged()
    }
    .onReceive(NotificationCenter.default.publisher(for: .syncStorageFailed)) { notification in
      guard let failure = notification.object as? StorageFailure else { return }
      storageFailure = failure
      showStorageFailure = true
    }
    .alert("Couldn't Save Library", isPresented: $showStorageFailure, presenting: storageFailure) {
      _ in
      Button("Try Again") {
        Task {
          guard !auth.simklAccessToken.isEmpty else { return }
          loading.startSync()
          await syncLatestActivities(auth.simklAccessToken, modelContainer: context.container)
          loading.stopSync()
        }
      }
      Button("Not Now", role: .cancel) {}
    } message: { failure in
      Text(failure.message)
    }
  }

  @available(iOS 26, *)
  private var modernTabs: some View {
    TabView(selection: $selectedTab) {
      Tab(AppTab.lists.title, systemImage: AppTab.lists.symbol, value: AppTab.lists) {
        listsTab
      }
      Tab(AppTab.upNext.title, systemImage: AppTab.upNext.symbol, value: AppTab.upNext) {
        UpNextView()
      }
      Tab(AppTab.explore.title, systemImage: AppTab.explore.symbol, value: AppTab.explore) {
        ExploreView()
      }
      Tab(AppTab.settings.title, systemImage: AppTab.settings.symbol, value: AppTab.settings) {
        SettingsView()
      }
      // Only Search raises the keyboard; Explore is for browsing.
      Tab(
        AppTab.search.title, systemImage: AppTab.search.symbol, value: AppTab.search, role: .search
      ) {
        SearchView(searchText: $searchText, searchCategory: $searchCategory)
      }
    }
    .tabViewSearchActivation(.searchTabSelection)
  }

  private var tabContent: some View {
    TabView(selection: tabSelection) {
      listsTab
        .tabItem {
          Label(AppTab.lists.title, systemImage: AppTab.lists.symbol)
        }
        .tag(AppTab.lists)
      UpNextView()
        .tabItem {
          Label(AppTab.upNext.title, systemImage: AppTab.upNext.symbol)
        }
        .tag(AppTab.upNext)
      ExploreView()
        .tabItem {
          Label(AppTab.explore.title, systemImage: AppTab.explore.symbol)
        }
        .tag(AppTab.explore)
      SearchView(
        searchFocusTrigger: searchFocusTrigger,
        searchText: $searchText, searchCategory: $searchCategory
      )
      .tabItem {
        Label(AppTab.search.title, systemImage: AppTab.search.symbol)
      }
      .tag(AppTab.search)
      SettingsView()
        .tabItem {
          Label(AppTab.settings.title, systemImage: AppTab.settings.symbol)
        }
        .tag(AppTab.settings)
    }
  }
}
