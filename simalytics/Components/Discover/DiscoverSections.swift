//
//  DiscoverSections.swift
//  simalytics
//

import SwiftUI

/// Credits Simkl beside its data, as its trending attribution rules require,
/// without spelling out "on Simkl" in every title.
struct SimklTag: View {
  var body: some View {
    Text("Simkl")
      .font(.caption.weight(.semibold))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(.quaternary, in: Capsule())
      // A credit beside titles; capped so large titles keep the width.
      .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
      .accessibilityLabel("on Simkl")
  }
}

struct DiscoverSectionHeader: View {
  let title: String
  var subtitle: String? = nil
  var showsChevron = false
  /// Sections that show Simkl's titles carry its tag.
  var attributed = false

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(title)
          .font(.title2.bold())
          // Accessibility sizes wrap as far as the title needs.
          .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
        if attributed {
          SimklTag()
        }
        if showsChevron {
          Image(systemName: "chevron.right")
            .font(.headline)
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
      }
      if let subtitle {
        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal)
    .contentShape(.rect)
    .accessibilityElement(children: .combine)
    .accessibilityAddTraits(.isHeader)
  }
}

/// A section header that opens the full list.
struct DiscoverSectionLink<Destination: View>: View {
  let title: String
  var subtitle: String? = nil
  var attributed = true
  @ViewBuilder let destination: () -> Destination

  var body: some View {
    NavigationLink {
      destination()
    } label: {
      DiscoverSectionHeader(
        title: title, subtitle: subtitle, showsChevron: true, attributed: attributed)
    }
    .buttonStyle(.plain)
    .accessibilityHint("Shows the full list")
  }
}

/// Swipeable backdrop cards for today's top titles.
struct HeroCarousel: View {
  let items: [DiscoverItem]
  let ranks: [String: Int]

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var currentID: String?

  private func eyebrow(for item: DiscoverItem) -> String {
    guard let rank = ranks[item.id] else { return "Trending on Simkl" }
    return "#\(rank) in \(item.type.title) Today"
  }

  var body: some View {
    VStack(spacing: 10) {
      ScrollView(.horizontal) {
        LazyHStack(spacing: 12) {
          ForEach(items) { item in
            DiscoverItemLink(item: item, source: "hero") {
              HeroCard(item: item, eyebrow: eyebrow(for: item))
            }
            // Size from the width: the aspect ratio must sit inside the frame.
            // Accessibility sizes stack the card's text, so it gets taller.
            .aspectRatio(dynamicTypeSize.isAccessibilitySize ? 4 / 3 : 16 / 10, contentMode: .fit)
            .containerRelativeFrame(
              .horizontal, count: horizontalSizeClass == .regular ? 2 : 1, spacing: 12
            )
            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
              content
                .scaleEffect(phase.isIdentity ? 1 : 0.95)
                .opacity(phase.isIdentity ? 1 : 0.85)
            }
          }
        }
        .scrollTargetLayout()
      }
      .scrollTargetBehavior(.viewAligned)
      .scrollIndicators(.hidden)
      .scrollPosition(id: $currentID)
      .contentMargins(.horizontal, 16, for: .scrollContent)
      // A new filter or hourly refresh can drop the card on screen; start over
      // so the page dots don't point at a card that's gone.
      .onChange(of: items.map(\.id)) { _, ids in
        if let currentID, !ids.contains(currentID) { self.currentID = ids.first }
      }

      if items.count > 1 {
        HStack(spacing: 6) {
          ForEach(items) { item in
            Circle()
              .fill(item.id == (currentID ?? items.first?.id) ? Color.primary : Color.secondary.opacity(0.35))
              .frame(width: 6, height: 6)
          }
        }
        .animation(.snappy, value: currentID)
        .accessibilityHidden(true)
      }
    }
  }
}

/// A horizontal row of poster cards for one list.
struct DiscoverShelf: View {
  let list: DiscoverList
  var limit = 20

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      DiscoverSectionLink(title: list.shelfTitle, subtitle: list.subtitle) {
        DiscoverGridView(list: list)
      }
      ScrollView(.horizontal) {
        LazyHStack(alignment: .top, spacing: 12) {
          ForEach(list.items.prefix(limit)) { item in
            DiscoverItemLink(item: item, source: list.id) {
              DiscoverPosterCard(item: item, badge: list.badge, showsType: list.types.count > 1)
            }
          }
        }
        .padding(.horizontal)
      }
      .scrollIndicators(.hidden)
    }
  }
}

/// Today's top ten for one type, Top 10 style.
struct RankedShelf: View {
  let type: DiscoverMediaType
  let items: [DiscoverItem]
  /// Places in today's full chart; hidden library titles leave gaps.
  let ranks: [String: Int]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      DiscoverSectionLink(
        title: "Top 10 \(type.title) Today",
        subtitle: "Most watched in the last 24 hours"
      ) {
        DiscoverGridView(
          title: "Trending \(type.title) Today", subtitle: "Most watched in the last 24 hours",
          items: items, ranks: ranks)
      }
      ScrollView(.horizontal) {
        LazyHStack(alignment: .top, spacing: 14) {
          ForEach(items.prefix { (ranks[$0.id] ?? .max) <= 10 }) { item in
            DiscoverItemLink(item: item, source: "top10") {
              RankedPosterCard(item: item, rank: ranks[item.id] ?? 0)
            }
          }
        }
        .padding(.horizontal)
      }
      .scrollIndicators(.hidden)
    }
  }
}

/// Two rows of genre tiles that scroll sideways together.
struct GenreTileGrid: View {
  let groups: [DiscoverGenreGroup]
  let preferredType: DiscoverMediaType?

  @ScaledMetric(relativeTo: .headline) private var tileHeight: CGFloat = 88
  @ScaledMetric(relativeTo: .headline) private var tileWidth: CGFloat = 150

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      DiscoverSectionLink(
        title: "Browse by Genre", subtitle: "\(groups.count) genres", attributed: false
      ) {
        AllGenresView(groups: groups, preferredType: preferredType)
      }
      ScrollView(.horizontal) {
        LazyHGrid(
          rows: [GridItem(.fixed(tileHeight), spacing: 10), GridItem(.fixed(tileHeight))],
          spacing: 10
        ) {
          ForEach(groups) { group in
            NavigationLink {
              GenreDetailView(group: group, preferredType: preferredType)
            } label: {
              GenreTile(group: group, width: tileWidth, height: tileHeight)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal)
      }
      .scrollIndicators(.hidden)
    }
  }
}

/// Tiles for every curated list, as a grid.
struct CollectionTileGrid: View {
  let lists: [DiscoverList]
  /// Fixed columns, so a short grid fills whole rows; nil fits as many as the width allows.
  var columns: Int? = nil

  private var gridItems: [GridItem] {
    guard let columns else { return [GridItem(.adaptive(minimum: 160), spacing: 12)] }
    return Array(repeating: GridItem(.flexible(), spacing: 12), count: columns)
  }

  var body: some View {
    LazyVGrid(columns: gridItems, spacing: 12) {
      ForEach(lists) { list in
        NavigationLink {
          DiscoverGridView(list: list)
        } label: {
          CollectionTile(list: list)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal)
    // Two tiles share a row, so they stop growing at the first
    // accessibility size; past it, names no longer fit.
    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
  }
}

/// The first few collections, with the rest a tap away.
struct CollectionGrid: View {
  let lists: [DiscoverList]
  var featured = ExploreSnapshot.featuredCollections

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      DiscoverSectionLink(
        title: "Collections", subtitle: "\(lists.count) lists curated from what Simkl members watch",
        attributed: false
      ) {
        ScrollView {
          CollectionTileGrid(lists: lists)
            .padding(.vertical, 8)
        }
        .navigationTitle("Collections")
        .navigationBarTitleDisplayMode(.inline)
      }
      // Three across on iPad, so the featured six fill two rows.
      CollectionTileGrid(
        lists: Array(lists.prefix(featured)), columns: horizontalSizeClass == .regular ? 3 : nil)
    }
  }
}

/// A sideways row of network or decade tiles.
struct DiscoverTileRow<Tile: View>: View {
  let title: String
  var subtitle: String? = nil
  let lists: [DiscoverList]
  @ViewBuilder let tile: (DiscoverList) -> Tile

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      DiscoverSectionHeader(title: title, subtitle: subtitle)
      ScrollView(.horizontal) {
        LazyHStack(spacing: 10) {
          ForEach(lists) { list in
            NavigationLink {
              DiscoverGridView(list: list)
            } label: {
              tile(list)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal)
      }
      .scrollIndicators(.hidden)
    }
  }
}

/// Simkl asks for a visible credit wherever its data appears.
struct SimklAttribution: View {
  var body: some View {
    Link(destination: URL(string: "https://simkl.com")!) {
      Label("Movie, TV, and anime data from Simkl", systemImage: "info.circle")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
  }
}
