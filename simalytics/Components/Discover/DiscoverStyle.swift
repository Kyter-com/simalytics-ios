//
//  DiscoverStyle.swift
//  simalytics
//

import Kingfisher
import SwiftData
import SwiftUI

/// Artwork for Explore's tiles: an SF Symbol over a two-color gradient. Colors
/// are dark enough to carry white text in light and dark mode.
struct TileStyle {
  let symbol: String
  let colors: [Color]

  var gradient: LinearGradient {
    LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
  }

  private init(_ symbol: String, _ start: UInt32, _ end: UInt32) {
    self.symbol = symbol
    colors = [Color(hex: start), Color(hex: end)]
  }

  /// Keyed by `DiscoverGenre.key`, which folds per-type spellings together.
  static func genre(_ key: String) -> TileStyle {
    switch key {
    case "action": TileStyle("flame.fill", 0xE5484D, 0xF76B15)
    case "adventure": TileStyle("map.fill", 0x2B9A66, 0x1A6B47)
    case "animation": TileStyle("paintpalette.fill", 0x8E4EC6, 0xD6409F)
    case "comedy", "parody", "gaghumor": TileStyle("face.smiling.inverse", 0xD69A00, 0xB8620B)
    case "crime": TileStyle("flashlight.on.fill", 0x3E4A5C, 0x1F2933)
    case "documentary": TileStyle("globe.americas.fill", 0x12A594, 0x0B6E63)
    case "drama": TileStyle("theatermasks.fill", 0x6E56CF, 0x3E3A8C)
    case "family", "children", "kids": TileStyle("figure.2.and.child.holdinghands", 0x0090FF, 0x0D5BB5)
    case "fantasy", "magic": TileStyle("wand.and.stars", 0x7C66DC, 0x3E63DD)
    case "history", "historical": TileStyle("building.columns.fill", 0xAD7F58, 0x6F4A2C)
    case "horror", "vampire": TileStyle("moon.haze.fill", 0x8C1D3B, 0x1C1C1E)
    case "music", "musical", "idol": TileStyle("music.note", 0xE93D82, 0x8E4EC6)
    case "mystery", "suspense": TileStyle("eye.fill", 0x5746AF, 0x24204F)
    case "romance", "josei", "shoujo", "koreandrama": TileStyle("heart.fill", 0xE93D82, 0xAB2E5C)
    case "sciencefiction", "space": TileStyle("atom", 0x00A2C7, 0x0D5F8C)
    case "thriller", "psychological": TileStyle("waveform.path.ecg", 0x0E6A79, 0x0B3540)
    case "tvmovie": TileStyle("tv.fill", 0x5B6B7F, 0x2F3A4A)
    case "war", "military": TileStyle("shield.fill", 0x5C6B4E, 0x343E2B)
    case "western": TileStyle("sun.dust.fill", 0xC2703D, 0x7E3F18)
    case "reality", "gameshow", "talkshow": TileStyle("party.popper.fill", 0xF76B15, 0xC2298A)
    case "news": TileStyle("newspaper.fill", 0x5B6B7F, 0x2F3A4A)
    case "food": TileStyle("fork.knife", 0xD6409F, 0xE5484D)
    case "homeandgarden": TileStyle("house.fill", 0x30A46C, 0x1F6F4A)
    case "travel": TileStyle("airplane", 0x0090FF, 0x12A594)
    case "miniseries": TileStyle("rectangle.stack.fill", 0x3E63DD, 0x26307A)
    case "sport", "sports", "racing": TileStyle("sportscourt.fill", 0x30A46C, 0x0D74CE)
    case "martialarts", "samurai": TileStyle("figure.martial.arts", 0xE5484D, 0x8C1D3B)
    case "soap": TileStyle("bubble.left.and.bubble.right.fill", 0xD6409F, 0x8E4EC6)
    case "shounen", "superpower": TileStyle("bolt.fill", 0xF76B15, 0xE5484D)
    case "seinen": TileStyle("person.fill", 0x3E4A5C, 0x5746AF)
    case "isekai", "reincarnation": TileStyle("sparkles", 0x6E56CF, 0x00A2C7)
    case "mecha", "strategygame": TileStyle("gearshape.2.fill", 0x5B6B7F, 0x0D5F8C)
    case "sliceoflife": TileStyle("cup.and.saucer.fill", 0xC2703D, 0xD6409F)
    case "school": TileStyle("graduationcap.fill", 0x0090FF, 0x6E56CF)
    case "supernatural", "mythology": TileStyle("tornado", 0x5746AF, 0x0E6A79)
    case "gore": TileStyle("drop.fill", 0x8C1D3B, 0x3B0A18)
    case "harem": TileStyle("person.3.fill", 0xE93D82, 0xF76B15)
    default: fallback(for: key)
    }
  }

  /// Brand-evocative colors only; no logos.
  static let network: [String: TileStyle] = [
    "Netflix": TileStyle("play.tv.fill", 0xB20710, 0x5C0307),
    "HBO": TileStyle("play.tv.fill", 0x5822B4, 0x1F0A4D),
    "Apple TV": TileStyle("play.tv.fill", 0x48484A, 0x0B0B0C),
    "Prime Video": TileStyle("play.tv.fill", 0x1A98FF, 0x0F4C81),
    "Disney+": TileStyle("play.tv.fill", 0x113CCF, 0x0A1F6B),
    "Hulu": TileStyle("play.tv.fill", 0x0B8F4D, 0x07472A),
    "Paramount+": TileStyle("play.tv.fill", 0x0064FF, 0x0A2A6B),
    "Peacock": TileStyle("play.tv.fill", 0x3A3A3C, 0x6E56CF),
    "STARZ": TileStyle("play.tv.fill", 0x2C2C2E, 0x5B6B7F),
    "MGM+": TileStyle("play.tv.fill", 0xB8860B, 0x5C4305),
    "AMC+": TileStyle("play.tv.fill", 0x1C1C1E, 0x5B6B7F),
    "CBS": TileStyle("tv.fill", 0x1F4FA8, 0x0B2559),
    "NBC": TileStyle("tv.fill", 0x6E56CF, 0xF76B15),
    "ABC": TileStyle("tv.fill", 0x2C2C2E, 0x8E8E93),
    "FOX": TileStyle("tv.fill", 0x0B3D91, 0x061D47),
    "FX": TileStyle("tv.fill", 0x3A3A3C, 0x8C1D3B),
    "AMC": TileStyle("tv.fill", 0x1C1C1E, 0xAB2E5C),
    "BBC": TileStyle("tv.fill", 0x48484A, 0x0B0B0C),
    "The CW": TileStyle("tv.fill", 0x2B9A66, 0x0B4F33),
    "USA Network": TileStyle("tv.fill", 0x0064FF, 0x0B1F5C),
    "Showtime": TileStyle("tv.fill", 0xB20710, 0x3B0A18),
    "Adult Swim": TileStyle("tv.fill", 0x2C2C2E, 0x111111),
    "Cartoon Network": TileStyle("tv.fill", 0x111111, 0x5B6B7F),
    "Nickelodeon": TileStyle("tv.fill", 0xF76B15, 0xB54708),
    "SYFY": TileStyle("tv.fill", 0x6E56CF, 0x1F0A4D),
    "The WB": TileStyle("tv.fill", 0x1F4FA8, 0x0B2559),
  ]

  /// Era-flavored gradients for the decade tiles.
  static func decade(_ decade: Int) -> TileStyle {
    switch decade {
    case 2020...: TileStyle("calendar", 0x6E56CF, 0xE93D82)
    case 2010..<2020: TileStyle("calendar", 0xF76B15, 0x12A594)
    case 2000..<2010: TileStyle("calendar", 0x3E63DD, 0x5B6B7F)
    case 1990..<2000: TileStyle("calendar", 0x12A594, 0x8E4EC6)
    case 1980..<1990: TileStyle("calendar", 0xE93D82, 0x3E3A8C)
    case 1970..<1980: TileStyle("calendar", 0xC2703D, 0x8C4A1E)
    case 1960..<1970: TileStyle("calendar", 0xD69A00, 0x2B9A66)
    default: TileStyle("calendar", 0x5B6B7F, 0x2C2C2E)
    }
  }

  static func collection(_ kind: DiscoverListKind) -> TileStyle {
    switch kind {
    case .topRated: TileStyle("star.fill", 0xD69A00, 0xB8620B)
    case .lovedEverywhere: TileStyle("heart.fill", 0xE93D82, 0x8E4EC6)
    case .hiddenGems: TileStyle("diamond.fill", 0x00A2C7, 0x6E56CF)
    case .justReleased: TileStyle("sparkles", 0xE93D82, 0xF76B15)
    case .inTheaters: TileStyle("ticket.fill", 0xE5484D, 0x7A1E3A)
    case .newAtHome: TileStyle("house.fill", 0x3E63DD, 0x12A594)
    case .airingNow: TileStyle("dot.radiowaves.left.and.right", 0x30A46C, 0x0D74CE)
    case .weekendBinge: TileStyle("popcorn.fill", 0xF76B15, 0xE5484D)
    case .marathonWorthy: TileStyle("sofa.fill", 0x8E4EC6, 0x3E3A8C)
    case .epicMovies: TileStyle("hourglass", 0x5746AF, 0x0E6A79)
    case .quickWatches: TileStyle("timer", 0x30A46C, 0x0B6E63)
    case .boxOffice: TileStyle("dollarsign.circle.fill", 0x2B9A66, 0xB8860B)
    case .worldHits: TileStyle("globe.europe.africa.fill", 0x0090FF, 0x12A594)
    case .hardToQuit: TileStyle("checkmark.seal.fill", 0x12A594, 0x3E63DD)
    case .animeMovies: TileStyle("film.fill", 0xE5484D, 0x8C1D3B)
    case .mostWatchlisted: TileStyle("bookmark.fill", 0x3E63DD, 0x26307A)
    case .forYou: TileStyle("wand.and.stars", 0x8E4EC6, 0x3E63DD)
    case .decade(let decade): Self.decade(decade)
    case .network(let name): network[name] ?? fallback(for: name)
    case .genre(let key, _): genre(key)
    }
  }

  /// Genres without a hand-picked style still get stable artwork: the key's
  /// scalar sum picks a palette (unlike `hashValue`, it's the same every launch).
  private static func fallback(for key: String) -> TileStyle {
    let palettes: [(UInt32, UInt32)] = [
      (0x0090FF, 0x3E63DD), (0x12A594, 0x30A46C), (0x8E4EC6, 0xD6409F),
      (0xF76B15, 0xE5484D), (0x5746AF, 0x0E6A79), (0xAD7F58, 0x6F4A2C),
    ]
    let index = key.unicodeScalars.reduce(0) { $0 + Int($1.value) } % palettes.count
    return TileStyle("film.fill", palettes[index].0, palettes[index].1)
  }
}

/// Simkl's score as a slim capsule, matching the other poster chips.
struct RatingChip: View {
  let rating: Double

  var body: some View {
    PosterChip(
      text: rating.formatted(.number.precision(.fractionLength(1))), symbol: "star.fill",
      symbolColor: .yellow
    )
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      "Rated \(rating.formatted(.number.precision(.fractionLength(1)))) out of 10 on Simkl")
  }
}

/// "Yesterday", "3 days ago", "Last wk." for release-date chips; short units
/// keep "3 wk. ago" inside a poster chip.
@MainActor
enum DiscoverDateLabel {
  private static let formatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.dateTimeStyle = .named
    formatter.unitsStyle = .short
    return formatter
  }()

  static func relative(_ date: Date, to now: Date = Date()) -> String {
    let calendar = Calendar.current
    let days =
      calendar.dateComponents(
        [.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)
      ).day ?? 0
    let components =
      switch abs(days) {
      case ..<7: DateComponents(day: -days)
      case ..<60: DateComponents(weekOfMonth: -days / 7)
      default: DateComponents(month: -days / 30)
      }
    let text = formatter.localizedString(from: components)
    return text.prefix(1).uppercased() + text.dropFirst()
  }
}

/// A small capsule label laid over poster corners.
struct PosterChip: View {
  let text: String
  var symbol: String? = nil
  var symbolColor: Color = .white
  var tint: Color = .black.opacity(0.75)

  var body: some View {
    HStack(spacing: 3) {
      if let symbol {
        Image(systemName: symbol)
          .foregroundStyle(symbolColor)
      }
      Text(text)
        .lineLimit(1)
    }
    .font(.caption2.weight(.bold))
    .foregroundStyle(.white)
    .padding(.horizontal, 6)
    .padding(.vertical, 3)
    .background(tint, in: Capsule())
    // Chips sit on fixed-size posters, so they stop growing before
    // accessibility sizes would cover the art.
    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
  }
}

/// Marks titles already in the user's library so browsing skips what they've seen.
struct LibraryStatusBadge: View {
  let status: String

  private var symbol: (name: String, color: Color, label: String)? {
    switch status {
    case "completed": ("checkmark.circle.fill", .green, "Completed")
    case "watching": ("play.circle.fill", .blue, "Watching")
    case "plantowatch": ("bookmark.circle.fill", .yellow, "Plan to Watch")
    case "hold": ("pause.circle.fill", .gray, "On Hold")
    case "dropped": ("xmark.circle.fill", .red, "Dropped")
    default: nil
    }
  }

  var body: some View {
    if let symbol {
      Image(systemName: symbol.name)
        .font(.system(size: 18, weight: .semibold))
        .symbolRenderingMode(.palette)
        .foregroundStyle(.white, symbol.color)
        .background(Circle().fill(.black.opacity(0.35)).padding(1))
        .accessibilityLabel(symbol.label)
    }
  }
}

/// Wide artwork that fills whatever frame it's given. Mirrors CustomKFImage's
/// cache and cancellation settings, downsampled to the rendered size.
struct BackdropImage: View {
  let url: String?
  var blurRadius: CGFloat = 0

  @Environment(\.displayScale) private var displayScale

  var body: some View {
    GeometryReader { geometry in
      if let url, let imageURL = URL(string: url) {
        KFImage(imageURL)
          .placeholder { Rectangle().fill(.quaternary) }
          .resizable()
          .setProcessor(
            DownsamplingImageProcessor(
              size: CGSize(
                width: max(geometry.size.width * displayScale, 1),
                height: max(geometry.size.height * displayScale, 1))))
          .cacheMemoryOnly(false)
          .memoryCacheExpiration(.days(7))
          .diskCacheExpiration(.days(30))
          .cancelOnDisappear(true)
          .aspectRatio(contentMode: .fill)
          .frame(width: geometry.size.width, height: geometry.size.height)
          .blur(radius: blurRadius)
          .clipped()
      } else {
        Rectangle().fill(.quaternary)
      }
    }
    .accessibilityHidden(true)
  }
}

extension EnvironmentValues {
  /// Library state for the titles on screen, read by poster cards.
  @Entry var discoverLibrary = LocalMediaSnapshots()
}

private struct DiscoverLibraryModifier: ViewModifier {
  let items: [DiscoverItem]

  @Environment(\.modelContext) private var context
  @State private var library = LocalMediaSnapshots()

  private var request: LocalMediaSnapshots.Request {
    LocalMediaSnapshots.Request(
      movieIDs: items.filter { $0.type == .movies }.map(\.simklID),
      showIDs: items.filter { $0.type == .shows }.map(\.simklID),
      animeIDs: items.filter { $0.type == .anime }.map(\.simklID))
  }

  func body(content: Content) -> some View {
    content
      .environment(\.discoverLibrary, library)
      .task(id: request) { library = LocalMediaSnapshots.fetch(request, context: context) }
      .onReceive(NotificationCenter.default.publisher(for: .localMediaSnapshotsDidChange)) { _ in
        library = LocalMediaSnapshots.fetch(request, context: context)
      }
  }
}

extension View {
  /// Looks up which of these titles are in the user's library.
  func discoverLibrary(for items: [DiscoverItem]) -> some View {
    modifier(DiscoverLibraryModifier(items: items))
  }
}
