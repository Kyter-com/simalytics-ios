//
//  GenreDetailView.swift
//  simalytics
//

import SwiftUI

/// A genre's 30-day most watched titles, loaded from its Simkl file on open.
struct GenreDetailView: View {
  let group: DiscoverGenreGroup

  @AppStorage("hideAnime") private var hideAnime = false
  @AppStorage("exploreHidesLibrary") private var hidesLibrary = false
  @State private var type: DiscoverMediaType
  @State private var items: [DiscoverItem] = []
  @State private var loadedType: DiscoverMediaType?
  @State private var failed = false
  @State private var attempt = 0
  @State private var sort = DiscoverSort.featured
  @ScaledMetric(relativeTo: .largeTitle) private var bannerHeight: CGFloat = 150

  init(group: DiscoverGenreGroup, preferredType: DiscoverMediaType? = nil) {
    self.group = group
    // Movies make the broadest first page when a genre spans types.
    let initial = [preferredType, .movies].compactMap { $0 }.first(where: group.types.contains)
    _type = State(initialValue: initial ?? group.types.first ?? .movies)
  }

  private var types: [DiscoverMediaType] {
    group.types.filter { !hideAnime || $0 != .anime }
  }

  private var shownItems: [DiscoverItem] {
    hidesLibrary ? items.filter { !DiscoverLibrary.shared.isInLibrary($0) } : items
  }

  private struct LoadKey: Equatable {
    let type: DiscoverMediaType
    let attempt: Int
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        banner

        if types.count > 1 {
          Picker("Type", selection: $type) {
            ForEach(types) { type in
              Text(type.title).tag(type)
            }
          }
          .pickerStyle(.segmented)
          .padding(.horizontal)
        }

        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text("Most Watched \(group.name) \(type.title)")
            .font(.headline)
          SimklTag()
        }
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)

        content
      }
      .padding(.bottom)
    }
    .navigationTitle(group.name)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        DiscoverSortMenu(sort: $sort)
      }
    }
    .task(id: LoadKey(type: type, attempt: attempt)) { await load() }
    .discoverLibrary(for: shownItems)
  }

  private var banner: some View {
    TileBackground(style: .genre(group.key), symbolSize: 120)
      .overlay(alignment: .bottomLeading) {
        VStack(alignment: .leading, spacing: 2) {
          Text(group.name)
            .font(.largeTitle.bold())
            .lineLimit(1)
            .minimumScaleFactor(0.6)
          Text(group.types.map(\.title).joined(separator: " · "))
            .font(.subheadline.weight(.semibold))
            .opacity(0.85)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
        .padding(20)
      }
      .frame(height: bannerHeight)
      .clipShape(.rect(cornerRadius: 24, style: .continuous))
      .padding(.horizontal)
      .accessibilityElement(children: .combine)
  }

  @ViewBuilder private var content: some View {
    if failed && items.isEmpty {
      ContentUnavailableView {
        Label("Couldn’t Load \(group.name)", systemImage: "wifi.exclamationmark")
      } description: {
        Text("Check your connection and try again.")
      } actions: {
        Button("Try Again") { attempt += 1 }
      }
    } else if loadedType != type {
      ProgressView()
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    } else if items.isEmpty {
      ContentUnavailableView(
        "No \(type.title) Yet", systemImage: "film.stack",
        description: Text("Simkl has no \(group.name.lowercased()) \(type.title.lowercased()) this month."))
    } else if shownItems.isEmpty {
      ContentUnavailableView(
        "All in Your Library", systemImage: "checkmark.circle",
        description: Text("Turn off Hide Titles in My Library in Explore to see them."))
    } else {
      LazyVGrid(columns: posterGridColumns, spacing: 16) {
        ForEach(sort.sorted(shownItems)) { item in
          DiscoverItemLink(item: item, source: "genre") {
            DiscoverPosterCard(item: item, diskCache: false)
          }
          .frame(maxWidth: .infinity)
        }
      }
      .padding(.horizontal, posterGridHorizontalPadding)
    }
  }

  private func load() async {
    if !types.contains(type), let first = types.first {
      type = first
      return
    }
    let requested = type
    guard let genre = group.genres[requested] else { return }
    failed = false
    do {
      let loaded = try await DiscoverStore.shared.items(in: genre, type: requested)
      // A load that finishes after a type switch mustn't land under the new type.
      guard !Task.isCancelled else { return }
      items = loaded
      loadedType = requested
    } catch {
      // Switching types cancels the old load; only a real failure shows an error.
      guard !isSimklCancellationError(error), !Task.isCancelled else { return }
      items = []
      loadedType = nil
      failed = true
    }
  }
}
