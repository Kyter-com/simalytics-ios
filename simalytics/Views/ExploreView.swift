//
//  ExploreView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 2/24/25.
//

import SwiftData
import SwiftUI

/// Browse-only discovery. Search lives in its own tab, so nothing here
/// raises the keyboard.
struct ExploreView: View {
  @Environment(Auth.self) private var auth
  @Environment(GlobalLoadingIndicator.self) private var globalLoadingIndicator
  @Environment(\.modelContext) private var context
  @AppStorage("hideAnime") private var hideAnime = false
  @AppStorage("exploreFilter") private var filter = ExploreFilter.all
  @AppStorage("exploreHidesLibrary") private var hidesLibrary = false
  /// The last snapshot built, kept on screen while a newer one builds.
  @State private var built: BuiltSnapshot?

  private let store = DiscoverStore.shared
  private let library = DiscoverLibrary.shared

  private struct BuiltSnapshot {
    let key: DiscoverStore.SnapshotKey
    let snapshot: ExploreSnapshot
  }

  private var filters: [ExploreFilter] {
    ExploreFilter.allCases.filter { !hideAnime || $0 != .anime }
  }

  private var activeFilter: ExploreFilter {
    hideAnime && filter == .anime ? .all : filter
  }

  /// Shows a saved Anime choice as All while anime is hidden, instead of
  /// leaving no segment selected.
  private var filterSelection: Binding<ExploreFilter> {
    Binding {
      activeFilter
    } set: {
      filter = $0
    }
  }

  var body: some View {
    NavigationStack {
      Group {
        if auth.simklAccessToken.isEmpty {
          ContentUnavailableView {
            Label("Sign in to Simkl", systemImage: "lock.shield")
          } description: {
            Text("Sign in to Simkl to explore what’s trending.")
          }
        } else {
          content
        }
      }
      .navigationTitle("Explore")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          if globalLoadingIndicator.isSyncing {
            ProgressView()
          }
        }
        if !auth.simklAccessToken.isEmpty {
          ToolbarItem(placement: .topBarTrailing) {
            Menu {
              Toggle("Hide Titles in My Library", systemImage: "eye.slash", isOn: $hidesLibrary)
            } label: {
              Label(
                "Explore Options",
                systemImage: hidesLibrary
                  ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            }
          }
        }
      }
    }
  }

  private var content: some View {
    let key = store.snapshotKey(
      for: activeFilter, hideAnime: hideAnime, library: library.contents,
      hidesLibrary: hidesLibrary)
    let cached = store.cachedSnapshot(for: key)
    // Until this key's snapshot is built, the last one stays on screen.
    let snapshot = cached ?? built?.snapshot ?? ExploreSnapshot()
    let isCurrent = cached != nil || built?.key == key
    return ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 28) {
          Picker("Show", selection: filterSelection) {
            ForEach(filters) { filter in
              Text(filter.title).tag(filter)
            }
          }
          .pickerStyle(.segmented)
          .padding(.horizontal)

          if snapshot.isEmpty {
            // A snapshot still building means loading, not an empty page.
            placeholder(isCurrent ? store.phase : .loading)
          } else {
            sections(snapshot)
          }
        }
        .padding(.bottom)
      }
      #if DEBUG
        // Screenshot slides past the top of the page start scrolled to their section.
        .task(id: snapshot.isEmpty) {
          guard !snapshot.isEmpty, let section = ScreenshotMode.exploreSection else { return }
          try? await Task.sleep(for: .milliseconds(300))
          proxy.scrollTo(section, anchor: .top)
        }
      #endif
    }
    .refreshable { await store.load(hideAnime: hideAnime, force: true) }
    .task { library.start(container: context.container) }
    .task(id: hideAnime) { await store.load(hideAnime: hideAnime) }
    .task(id: key) {
      let snapshot = await store.snapshot(for: key, library: library.contents)
      guard !Task.isCancelled else { return }
      built = BuiltSnapshot(key: key, snapshot: snapshot)
    }
    .sensoryFeedback(.selection, trigger: filter)
    .sensoryFeedback(.selection, trigger: hidesLibrary)
    .discoverLibrary(for: snapshot.visibleItems)
  }

  @ViewBuilder private func sections(_ snapshot: ExploreSnapshot) -> some View {
    ForEach(snapshot.sections) { section in
      switch section {
      case .hero:
        VStack(alignment: .leading, spacing: 10) {
          DiscoverSectionHeader(title: "Trending Today", attributed: true)
          HeroCarousel(items: snapshot.hero, ranks: snapshot.ranks)
        }
      case .genres:
        GenreTileGrid(
          groups: snapshot.genres,
          preferredType: activeFilter == .all ? nil : activeFilter.types(hideAnime: hideAnime).first)
      case .trending(let row):
        RankedShelf(type: row.type, items: row.items, ranks: snapshot.ranks)
      case .collections:
        CollectionGrid(lists: snapshot.collections)
      case .shelf(let list):
        DiscoverShelf(list: list)
      case .streaming:
        DiscoverTileRow(
          title: "Best of Streaming", subtitle: "Top rated shows by service",
          lists: snapshot.streaming
        ) { NetworkTile(list: $0) }
      case .networks:
        DiscoverTileRow(
          title: "Best of TV Networks", subtitle: "Top rated shows by channel",
          lists: snapshot.networks
        ) { NetworkTile(list: $0) }
      case .decades:
        DiscoverTileRow(
          title: "By Decade", subtitle: "The best of each era", lists: snapshot.decades
        ) { DecadeTile(list: $0) }
      }
    }

    SimklAttribution()
  }

  @ViewBuilder private func placeholder(_ phase: DiscoverStore.Phase) -> some View {
    switch phase {
    case .failed:
      ContentUnavailableView {
        Label("Explore Unavailable", systemImage: "wifi.exclamationmark")
      } description: {
        Text("Couldn’t reach Simkl. Check your connection and try again.")
      } actions: {
        Button("Try Again") {
          Task { await store.load(hideAnime: hideAnime, force: true) }
        }
      }
      .padding(.top, 40)
    case .loaded:
      ContentUnavailableView(
        "Nothing Trending", systemImage: "binoculars",
        description: Text("Simkl has nothing to show here right now. Pull to refresh."))
      .padding(.top, 40)
    case .idle, .loading:
      ProgressView("Loading what’s trending…")
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
  }
}
