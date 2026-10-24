//
//  DiscoverGridView.swift
//  simalytics
//

import SwiftUI

enum DiscoverSort: String, CaseIterable, Identifiable {
  case featured, rating, newest, title

  var id: String { rawValue }

  var symbol: String {
    switch self {
    case .featured: "flame"
    case .rating: "star"
    case .newest: "calendar"
    case .title: "textformat"
    }
  }

  func label(featured: String?) -> String {
    switch self {
    case .featured: featured ?? "Featured"
    case .rating: "Top Rated"
    case .newest: "Newest"
    case .title: "Title"
    }
  }

  /// A list with no name for its own order is already ranked by score, so
  /// Top Rated stands in for it.
  static func options(featured: String?) -> [DiscoverSort] {
    featured == nil ? allCases.filter { $0 != .featured } : allCases
  }

  /// Scores from a handful of votes sink below established ones.
  func sorted(_ items: [DiscoverItem]) -> [DiscoverItem] {
    switch self {
    case .featured:
      return items
    case .rating:
      return items.enumerated().sorted { lhs, rhs in
        let left = (lhs.element.simklVotes >= 100, lhs.element.simklRating ?? 0)
        let right = (rhs.element.simklVotes >= 100, rhs.element.simklRating ?? 0)
        if left.0 != right.0 { return left.0 }
        if left.1 != right.1 { return left.1 > right.1 }
        return lhs.offset < rhs.offset
      }.map(\.element)
    case .newest:
      return items.enumerated().sorted { lhs, rhs in
        let left = lhs.element.year ?? 0
        let right = rhs.element.year ?? 0
        return left != right ? left > right : lhs.offset < rhs.offset
      }.map(\.element)
    case .title:
      return items.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
  }
}

struct DiscoverSortMenu: View {
  @Binding var sort: DiscoverSort
  /// Names the list's own order; nil when it's already by score.
  var featured: String? = "Most Watched"

  var body: some View {
    Menu {
      Picker("Sort By", selection: $sort) {
        ForEach(DiscoverSort.options(featured: featured)) { option in
          Label(option.label(featured: featured), systemImage: option.symbol).tag(option)
        }
      }
    } label: {
      Label("Sort", systemImage: "arrow.up.arrow.down")
    }
    .accessibilityLabel("Sort by \(sort.label(featured: featured))")
  }
}

/// "See All" for an Explore list.
struct DiscoverGridView: View {
  let title: String
  let subtitle: String
  let items: [DiscoverItem]
  var badge: DiscoverBadge? = .rating
  /// Trending lists number their titles by chart place while in Simkl's order.
  var ranks: [String: Int]?
  /// Names the list's own order; nil when it's already by score.
  var featured: String? = "Most Watched"

  @State private var sort = DiscoverSort.featured

  init(
    title: String, subtitle: String, items: [DiscoverItem], badge: DiscoverBadge? = .rating,
    ranks: [String: Int]? = nil
  ) {
    self.title = title
    self.subtitle = subtitle
    self.items = items
    self.badge = badge
    self.ranks = ranks
  }

  init(list: DiscoverList) {
    title = list.shelfTitle
    subtitle = list.subtitle
    items = list.items
    badge = list.badge
    featured = list.featuredSort
    _sort = State(initialValue: list.featuredSort == nil ? .rating : .featured)
  }

  private var sortedItems: [DiscoverItem] { sort.sorted(items) }
  private var showsType: Bool { Set(items.map(\.type)).count > 1 }

  var body: some View {
    ScrollView {
      HStack(alignment: .firstTextBaseline) {
        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Spacer()
        SimklTag()
      }
      .padding(.horizontal)
      .padding(.top, 4)

      LazyVGrid(columns: posterGridColumns, spacing: 16) {
        ForEach(sortedItems) { item in
          DiscoverItemLink(item: item, source: "grid") {
            DiscoverPosterCard(item: item, badge: badge, showsType: showsType, diskCache: false)
              .overlay(alignment: .topTrailing) {
                if sort == .featured, let rank = ranks?[item.id] {
                  PosterChip(text: "#\(rank)").padding(5)
                }
              }
          }
          .frame(maxWidth: .infinity)
        }
      }
      .padding(.horizontal, posterGridHorizontalPadding)
      .padding(.vertical, 8)
    }
    .navigationTitle(title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        DiscoverSortMenu(sort: $sort, featured: featured)
      }
    }
    .discoverLibrary(for: items)
  }
}
