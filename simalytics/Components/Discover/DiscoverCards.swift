//
//  DiscoverCards.swift
//  simalytics
//

import SwiftUI

/// Opens a discover title's detail screen. A long press previews it and offers
/// Plan to Watch, the trailer, and Share.
struct DiscoverItemLink<Content: View>: View {
  let item: DiscoverItem
  var source = "discover"
  @ViewBuilder let content: () -> Content

  @Environment(\.discoverLibrary) private var library
  @Environment(Auth.self) private var auth
  @Environment(\.openURL) private var openURL
  @State private var notice: Notice?
  @State private var changes = 0

  private let lists = DiscoverLibrary.shared

  private struct Notice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
  }

  var body: some View {
    MediaDetailLink(sourceID: "\(source)-\(item.id)") {
      switch item.type {
      case .shows: ShowDetailView(simkl_id: item.simklID)
      case .movies: MovieDetailView(simkl_id: item.simklID)
      case .anime: AnimeDetailView(simkl_id: item.simklID)
      }
    } label: {
      content()
    }
    .buttonStyle(.plain)
    .contextMenu {
      listButton
      if let trailer = item.trailerURL {
        Button("Watch Trailer", systemImage: "play.rectangle") { openURL(trailer) }
      }
      ShareLink(
        item: item.webURL,
        subject: Text(item.title),
        message: Text("Check out \(item.title)!")
      ) {
        Label("Share", systemImage: "square.and.arrow.up")
      }
    } preview: {
      SmartPreviewCard(
        simklId: item.simklID,
        title: item.title,
        year: item.year,
        poster: item.posterPath,
        mediaType: item.type.mediaType,
        localData: previewData
      )
    }
    .sensoryFeedback(.success, trigger: changes)
    .sensoryFeedback(trigger: notice?.id) { _, id in id == nil ? nil : .warning }
    .alert(notice?.title ?? "", isPresented: showsNotice, presenting: notice) { _ in
      Button("OK", role: .cancel) {}
    } message: { notice in
      Text(notice.message)
    }
  }

  private var showsNotice: Binding<Bool> {
    Binding {
      notice != nil
    } set: { shown in
      if !shown { notice = nil }
    }
  }

  /// Plan to Watch only: other lists hold progress, so they're left to the
  /// detail screen.
  @ViewBuilder private var listButton: some View {
    if !auth.simklAccessToken.isEmpty {
      if lists.updating.contains(item.id) {
        Button("Updating Your List…", systemImage: "clock") {}
          .disabled(true)
      } else {
        switch lists.status(of: item) {
        case nil:
          Button("Add to Plan to Watch", systemImage: "bookmark") { change(adding: true) }
        case "plantowatch":
          Button("Remove from Plan to Watch", systemImage: "bookmark.slash", role: .destructive) {
            change(adding: false)
          }
        case let status?:
          let list = DiscoverLibrary.listName(status)
          Button("In Your List: \(list)", systemImage: "checkmark.circle") {}
            .disabled(true)
        }
      }
    }
  }

  /// Shows a quick change before the sync that confirms it.
  private var previewData: LocalMediaData? {
    let synced = library.data(simklID: item.simklID, mediaType: item.type.mediaType)
    let status = lists.status(of: item)
    guard status != synced?.status else { return synced }
    return LocalMediaData(
      year: synced?.year ?? item.year, userRating: synced?.userRating, status: status,
      animeType: synced?.animeType, watchedEpisodes: synced?.watchedEpisodes,
      totalEpisodes: synced?.totalEpisodes)
  }

  private func change(adding: Bool) {
    let accessToken = auth.simklAccessToken
    Task {
      let outcome =
        adding
        ? await lists.addToPlanToWatch(item, accessToken: accessToken)
        : await lists.removeFromPlanToWatch(item, accessToken: accessToken)
      switch outcome {
      case .added, .removed:
        changes += 1
      case .alreadyListed(let list):
        let name = DiscoverLibrary.listName(list)
        notice =
          adding
          ? Notice(title: "Already on Your List", message: "\(item.title) is in \(name) on Simkl.")
          : Notice(
            title: "Left on Your List",
            message: "\(item.title) is in \(name) on Simkl, so it wasn’t removed.")
      case .failed(let message):
        notice = Notice(title: "Couldn’t Update List", message: message)
      }
    }
  }
}

/// A poster with its list's highlight (score, runtime, …) and library status.
struct DiscoverPosterCard: View {
  let item: DiscoverItem
  var badge: DiscoverBadge? = .rating
  var showsType = false
  /// Shelves keep posters on disk for a fast relaunch; long grids don't.
  var diskCache = true

  private var subtitle: String {
    let year = item.year.map(String.init)
    guard showsType else { return year ?? item.type.singularTitle }
    return [item.type.singularTitle, year].compactMap { $0 }.joined(separator: " · ")
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      DiscoverPoster(item: item, badge: badge, diskCache: diskCache)

      // The hidden copy reserves two title lines so cards stay one height,
      // while the subtitle sits right under a one-line title.
      ZStack(alignment: .topLeading) {
        labels(title: "A\nA", subtitle: "A").hidden()
        labels(title: item.title, subtitle: subtitle)
      }
    }
    .frame(width: 110, alignment: .leading)
    .accessibilityElement(children: .combine)
  }

  private func labels(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.primary)
        .lineLimit(2)
        .multilineTextAlignment(.leading)
      Text(subtitle)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
  }
}

/// The 110 × 165 artwork shared by every poster card.
struct DiscoverPoster: View {
  let item: DiscoverItem
  var badge: DiscoverBadge? = .rating
  var diskCache = true

  private let library = DiscoverLibrary.shared

  var body: some View {
    CustomKFImage(
      imageUrlString: item.posterURL,
      memoryCacheOnly: !diskCache,
      height: 165,
      width: 110
    )
    .overlay(alignment: .topLeading) {
      if let status = library.status(of: item) {
        LibraryStatusBadge(status: status).padding(5)
      }
    }
    .overlay(alignment: .bottomLeading) {
      chip.padding(5)
    }
    .frame(width: 110, height: 165)
  }

  @ViewBuilder private var chip: some View {
    switch badge {
    case .rating:
      if let rating = item.simklRating {
        RatingChip(rating: rating)
      }
    case .released:
      if let date = item.releaseDate {
        PosterChip(text: DiscoverDateLabel.relative(date), symbol: "calendar")
      }
    case .theater:
      if let date = item.theaterDate {
        PosterChip(text: DiscoverDateLabel.relative(date), symbol: "ticket.fill")
          .accessibilityLabel("In theaters \(DiscoverDateLabel.relative(date))")
      }
    case .home:
      if let date = item.homeReleaseDate {
        PosterChip(text: DiscoverDateLabel.relative(date), symbol: "house.fill")
          .accessibilityLabel("Out at home \(DiscoverDateLabel.relative(date))")
      }
    case .finishRate:
      if let dropRate = item.dropRate {
        let finish = (100 - dropRate).formatted(.number.precision(.fractionLength(0...1)))
        PosterChip(text: "\(finish)%", symbol: "checkmark.seal.fill", symbolColor: .green)
          .accessibilityLabel("\(finish) percent of viewers finish it")
      }
    case .boxOffice:
      if let boxOffice = item.boxOffice {
        // Compact currency notation needs iOS 18, so prefix a compact number.
        PosterChip(
          text: "$"
            + boxOffice.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
        )
        .accessibilityLabel("Box office \(boxOffice.formatted(.currency(code: "USD")))")
      }
    case .language:
      if let code = item.original_language,
        let language = Locale.current.localizedString(forLanguageCode: code)
      {
        PosterChip(text: language, symbol: "globe")
      }
    case .watchlisted:
      if let count = item.plan_to_watch, count > 0 {
        PosterChip(text: count.formatted(.number.notation(.compactName)), symbol: "bookmark.fill")
          .accessibilityLabel("On \(count.formatted()) watchlists")
      }
    case .runtime:
      if let runtime = item.runtime, !runtime.isEmpty {
        PosterChip(text: runtime, symbol: "clock.fill")
      }
    case .episodes:
      if let episodes = item.total_episodes, episodes > 0 {
        PosterChip(text: "\(episodes) eps")
          .accessibilityLabel("\(episodes) episodes")
      }
    default:
      EmptyView()
    }
  }
}

/// Top 10 style: a big rank numeral tucked behind the poster, and how many
/// people watched the title in the chart's 24 hours.
struct RankedPosterCard: View {
  let item: DiscoverItem
  let rank: Int

  private var watchedToday: String? {
    guard let watched = item.watched, watched > 0 else { return nil }
    return "\(watched.formatted(.number.notation(.compactName))) watched today"
  }

  var body: some View {
    HStack(alignment: .top, spacing: -18) {
      Text("\(rank)")
        .font(.system(size: 104, weight: .black, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(
          LinearGradient(
            colors: [Color.primary.opacity(0.75), Color.primary.opacity(0.08)],
            startPoint: .top, endPoint: .bottom)
        )
        .lineLimit(1)
        .fixedSize()
        .frame(height: 165, alignment: .bottom)
        .offset(y: 22)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        DiscoverPoster(item: item)
          .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
          .padding(.bottom, 2)
        // As in DiscoverPosterCard: the hidden copy keeps cards one height
        // while the count sits right under a one-line title.
        ZStack(alignment: .topLeading) {
          labels(title: "A\nA", watched: watchedToday.map { _ in "A" }).hidden()
          labels(title: item.title, watched: watchedToday)
        }
        .frame(width: 110, alignment: .leading)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      ["Number \(rank)", item.title, watchedToday].compactMap { $0 }.joined(separator: ", "))
  }

  private func labels(title: String, watched: String?) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.caption)
        .lineLimit(2)
        .multilineTextAlignment(.leading)
      if let watched {
        Text(watched)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
  }
}

/// A wide backdrop card for the top of Explore. Titles without fanart get a
/// blurred poster wash with the poster itself on top.
struct HeroCard: View {
  let item: DiscoverItem
  let eyebrow: String

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  private let library = DiscoverLibrary.shared

  private var details: String {
    var parts: [String] = []
    if let year = item.year { parts.append(String(year)) }
    if let genres = item.genres, !genres.isEmpty {
      parts.append(genres.prefix(2).joined(separator: ", "))
    }
    if item.type == .movies, let runtime = item.runtime, !runtime.isEmpty {
      parts.append(runtime)
    } else if let episodes = item.total_episodes, episodes > 1 {
      parts.append("\(episodes) episodes")
    }
    return parts.joined(separator: " · ")
  }

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      if let fanart = item.fanartURL {
        BackdropImage(url: fanart)
      } else {
        BackdropImage(url: item.posterURL, blurRadius: 28)
          .overlay(Color.black.opacity(0.2))
          .overlay(alignment: .topTrailing) {
            CustomKFImage(
              imageUrlString: item.posterURL, memoryCacheOnly: false, height: 108, width: 72
            )
            .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
            .padding(16)
          }
      }

      LinearGradient(
        stops: [
          .init(color: .clear, location: 0.3),
          .init(color: .black.opacity(0.88), location: 1),
        ],
        startPoint: .top, endPoint: .bottom)

      // Accessibility sizes stack the score under the title, so the title
      // keeps the card's full width.
      let layout =
        dynamicTypeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
        : AnyLayout(HStackLayout(alignment: .bottom, spacing: 12))
      layout {
        VStack(alignment: .leading, spacing: 3) {
          Text(eyebrow)
            .font(.caption.weight(.heavy))
            .textCase(.uppercase)
            .foregroundStyle(.white.opacity(0.8))
          Text(item.title)
            .font(.title2.weight(.bold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
          if !details.isEmpty {
            Text(details)
              .font(.subheadline)
              .foregroundStyle(.white.opacity(0.8))
              .lineLimit(1)
          }
          // Accessibility sizes leave no room for it on the card.
          if let summary = item.summary, !dynamicTypeSize.isAccessibilitySize {
            Text(summary)
              .font(.footnote)
              .foregroundStyle(.white.opacity(0.75))
              .lineLimit(2)
              .padding(.top, 2)
          }
        }
        if !dynamicTypeSize.isAccessibilitySize {
          Spacer(minLength: 0)
        }
        if let rating = item.simklRating {
          Label {
            Text(rating.formatted(.number.precision(.fractionLength(1))))
          } icon: {
            Image(systemName: "star.fill").foregroundStyle(.yellow)
          }
          .labelStyle(.titleAndIcon)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.white)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(.ultraThinMaterial, in: Capsule())
          .environment(\.colorScheme, .dark)
          .accessibilityLabel(
            "Rated \(rating.formatted(.number.precision(.fractionLength(1)))) out of 10 on Simkl")
        }
      }
      .padding(16)
      // The card is artwork-sized; past the first accessibility size the
      // text would push the title off it.
      .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
    .overlay(alignment: .topLeading) {
      if let status = library.status(of: item) {
        LibraryStatusBadge(status: status).padding(12)
      }
    }
    .clipShape(.rect(cornerRadius: 22, style: .continuous))
    .contentShape(.rect(cornerRadius: 22, style: .continuous))
    .accessibilityElement(children: .combine)
  }
}

/// Gradient art behind a tile's label.
struct TileBackground: View {
  let style: TileStyle
  var symbolSize: CGFloat = 52

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      style.gradient
      LinearGradient(
        colors: [.white.opacity(0.16), .clear], startPoint: .top, endPoint: .center)
      Image(systemName: style.symbol)
        .font(.system(size: symbolSize, weight: .semibold))
        .foregroundStyle(.white.opacity(0.22))
        .rotationEffect(.degrees(-12))
        .offset(x: symbolSize * 0.18, y: symbolSize * 0.16)
    }
    .accessibilityHidden(true)
  }
}

struct GenreTile: View {
  let group: DiscoverGenreGroup
  /// nil fills the grid column.
  var width: CGFloat? = 150
  var height: CGFloat = 88

  var body: some View {
    TileBackground(style: .genre(group.key))
      .overlay(alignment: .bottomLeading) {
        Text(group.name)
          .font(.headline.weight(.bold))
          .foregroundStyle(.white)
          .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
          .lineLimit(2)
          .minimumScaleFactor(0.75)
          .padding(12)
      }
      .frame(width: width, height: height)
      .frame(maxWidth: width == nil ? .infinity : nil)
      .clipShape(.rect(cornerRadius: 16, style: .continuous))
      .accessibilityElement(children: .combine)
  }
}

/// A list's tile: its icon, name, size, and the first few posters fanned out.
struct CollectionTile: View {
  let list: DiscoverList

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @ScaledMetric(relativeTo: .headline) private var height: CGFloat = 124

  var body: some View {
    TileBackground(style: .collection(list.kind), symbolSize: 64)
      .overlay(alignment: .topTrailing) {
        ZStack {
          ForEach(Array(list.items.prefix(3).enumerated().reversed()), id: \.element.id) {
            index, item in
            CustomKFImage(
              imageUrlString: item.posterURL, memoryCacheOnly: true, height: 54, width: 36
            )
            .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
            .rotationEffect(.degrees(Double(index - 1) * 9))
            .offset(x: CGFloat(index - 1) * 18)
          }
        }
        .padding(.top, 14)
        .padding(.trailing, 30)
      }
      .overlay(alignment: .topLeading) {
        Image(systemName: TileStyle.collection(list.kind).symbol)
          .font(.subheadline.weight(.bold))
          .foregroundStyle(.white)
          .frame(width: 30, height: 30)
          .background(.white.opacity(0.22), in: Circle())
          .padding(12)
      }
      .overlay(alignment: .bottomLeading) {
        VStack(alignment: .leading, spacing: 1) {
          Text(list.title)
            .font(.headline.weight(.bold))
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            .minimumScaleFactor(0.8)
          Text("\(list.items.count) titles")
            .font(.caption.weight(.medium))
            .opacity(0.85)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        .padding(12)
      }
      .frame(height: height)
      .frame(maxWidth: .infinity)
      .clipShape(.rect(cornerRadius: 18, style: .continuous))
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("\(list.title), \(list.items.count) titles")
  }
}

struct NetworkTile: View {
  let list: DiscoverList
  var height: CGFloat = 80

  var body: some View {
    TileBackground(style: .collection(list.kind), symbolSize: 44)
      .overlay(alignment: .bottomLeading) {
        VStack(alignment: .leading, spacing: 0) {
          Text(list.title)
            .font(.system(.title3, design: .rounded).weight(.heavy))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
          Text("\(list.items.count) top shows")
            .font(.caption.weight(.medium))
            .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(12)
      }
      .frame(width: 150, height: height)
      .clipShape(.rect(cornerRadius: 16, style: .continuous))
      // A fixed-size tile; its text stops growing before it outgrows it.
      .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Best of \(list.title), \(list.items.count) shows")
  }
}

struct DecadeTile: View {
  let list: DiscoverList
  var height: CGFloat = 80

  var body: some View {
    TileBackground(style: .collection(list.kind), symbolSize: 40)
      .overlay {
        VStack(spacing: 0) {
          Text(list.title)
            .font(.system(size: 30, weight: .black, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
          Text("\(list.items.count) titles")
            .font(.caption2.weight(.semibold))
            .opacity(0.85)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        .padding(.horizontal, 8)
      }
      .frame(width: 124, height: height)
      .clipShape(.rect(cornerRadius: 16, style: .continuous))
      // A fixed-size tile; its text stops growing before it outgrows it.
      .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Best of the \(list.title), \(list.items.count) titles")
  }
}
