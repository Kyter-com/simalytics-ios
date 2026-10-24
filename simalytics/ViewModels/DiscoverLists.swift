//
//  DiscoverLists.swift
//  simalytics
//

import Foundation

/// The segmented filter at the top of Explore.
enum ExploreFilter: String, CaseIterable, Identifiable, Sendable {
  case all, shows, movies, anime

  var id: String { rawValue }

  var title: String {
    switch self {
    case .all: "All"
    case .shows: "Shows"
    case .movies: "Movies"
    case .anime: "Anime"
    }
  }

  func types(hideAnime: Bool) -> [DiscoverMediaType] {
    switch self {
    case .all: hideAnime ? [.shows, .movies] : [.shows, .movies, .anime]
    case .shows: [.shows]
    case .movies: [.movies]
    case .anime: hideAnime ? [] : [.anime]
    }
  }
}

/// A curated list built on-device from Simkl's 30-day most-watched files.
/// Each one is a filter or sort over data Explore already has, so none costs a
/// request. Thresholds follow the recipes in Simkl's trending docs.
enum DiscoverListKind: Hashable, Sendable {
  case topRated
  case lovedEverywhere
  case hiddenGems
  case justReleased
  case inTheaters
  case newAtHome
  case airingNow
  case weekendBinge
  case marathonWorthy
  case epicMovies
  case quickWatches
  case boxOffice
  case worldHits
  case hardToQuit
  case animeMovies
  case mostWatchlisted
  case decade(Int)
  case network(String)
  case genre(key: String, name: String)
  /// Picks from the genres the user rates highest, named in the subtitle.
  case forYou(favorites: [String], fromRatings: Bool)

  /// Collections order; the Explore grid features the first few.
  static let collections: [DiscoverListKind] = [
    .topRated, .lovedEverywhere, .hiddenGems, .weekendBinge, .boxOffice, .worldHits, .airingNow,
    .inTheaters, .newAtHome, .justReleased, .marathonWorthy, .epicMovies, .quickWatches,
    .hardToQuit, .animeMovies, .mostWatchlisted,
  ]
}

/// What a poster card highlights for a list.
enum DiscoverBadge: Hashable, Sendable {
  case rating
  case released
  case theater
  case home
  case watchlisted
  case runtime
  case episodes
  case finishRate
  case boxOffice
  case language
}

struct DiscoverList: Identifiable, Hashable, Sendable {
  let kind: DiscoverListKind
  let types: [DiscoverMediaType]
  let items: [DiscoverItem]

  var id: String { "\(kind)-\(types.map(\.rawValue).joined(separator: "+"))" }

  /// "Movies" for a single type; mixed lists read naturally without a noun.
  private var noun: String? { types.count == 1 ? types[0].title : nil }

  /// Short label for tiles.
  var title: String {
    switch kind {
    case .topRated: "Top Rated"
    case .lovedEverywhere: "Loved Everywhere"
    case .hiddenGems: "Hidden Gems"
    case .justReleased: "Just Released"
    case .inTheaters: "In Theaters"
    case .newAtHome: "New at Home"
    case .airingNow: "Airing Now"
    case .weekendBinge: "Weekend Binges"
    case .marathonWorthy: "Marathon-Worthy"
    case .epicMovies: "Epic Movies"
    case .quickWatches: "Quick Watches"
    case .boxOffice: "Box Office Giants"
    case .worldHits: "World Hits"
    case .hardToQuit: "Hard to Quit"
    case .animeMovies: "Anime Movies"
    case .mostWatchlisted: "Most Watchlisted"
    case .decade(let decade): Self.decadeName(decade)
    case .network(let network): network
    case .genre(_, let name): "Popular \(name)"
    case .forYou: "For You"
    }
  }

  /// Headers pair this with a Simkl tag, which Simkl's trending attribution
  /// rules require next to its data.
  var shelfTitle: String {
    let noun = noun.map { " \($0)" } ?? ""
    switch kind {
    case .topRated: return "Top Rated\(noun)"
    case .lovedEverywhere:
      return noun.isEmpty ? "Loved Everywhere" : "\(noun.dropFirst()) Loved Everywhere"
    case .hiddenGems: return noun.isEmpty ? "Hidden Gems" : "Hidden Gem\(noun)"
    case .justReleased: return "Just Released\(noun)"
    case .inTheaters: return "Now in Theaters"
    case .newAtHome: return "New at Home"
    case .airingNow: return "\(noun.isEmpty ? "Shows" : String(noun.dropFirst())) Airing Now"
    case .weekendBinge: return "Weekend Binges"
    case .marathonWorthy: return "Marathon-Worthy\(noun)"
    case .epicMovies: return "Epic Movies"
    case .quickWatches: return "Quick Watches"
    case .boxOffice: return "Box Office Giants"
    case .worldHits: return "World Hits"
    case .hardToQuit: return "Hard to Quit"
    case .animeMovies: return "Anime Movies"
    case .mostWatchlisted: return "Most Watchlisted\(noun)"
    case .decade(let decade): return "Best\(noun) of the \(Self.decadeName(decade))"
    case .network(let network): return "Best of \(network)"
    case .genre(_, let name): return "Popular \(name)\(noun)"
    case .forYou: return noun.isEmpty ? "For You" : "\(noun.dropFirst()) for You"
    }
  }

  var subtitle: String {
    switch kind {
    case .topRated: return "The community's highest scores"
    case .lovedEverywhere:
      let outside =
        types == [.anime] ? "MyAnimeList" : types.contains(.anime) ? "IMDb or MAL" : "IMDb"
      return "Rated 8+ on Simkl and \(outside)"
    case .hiddenGems: return "Loved, but under the radar"
    case .justReleased: return "Brand-new and already popular"
    case .inTheaters: return "Still on the big screen"
    case .newAtHome: return "Just out on digital and disc"
    case .airingNow: return "New episodes as they air"
    case .weekendBinge: return "Finished series, 10 episodes or fewer"
    case .marathonWorthy: return "Finished series rated 8+"
    case .epicMovies: return "Two and a half hours or more"
    case .quickWatches: return "Movies 90 minutes or less"
    case .boxOffice: return "The biggest worldwide hauls"
    case .worldHits: return "Popular beyond English"
    case .hardToQuit: return "Almost nobody drops these"
    case .animeMovies: return "Feature-length anime"
    case .mostWatchlisted: return "What everyone plans to watch"
    case .decade: return "Highest rated of the decade"
    case .network: return "Highest rated shows"
    case .genre: return "Today's genre spotlight, rated 7.5+"
    case .forYou(let favorites, let fromRatings):
      let genres = ListFormatter.localizedString(byJoining: favorites)
      return fromRatings
        ? "Because you rate \(genres) highly" : "Because you watch a lot of \(genres)"
    }
  }

  var symbol: String {
    switch kind {
    case .topRated: "star.fill"
    case .lovedEverywhere: "heart.fill"
    case .hiddenGems: "diamond.fill"
    case .justReleased: "sparkles"
    case .inTheaters: "ticket.fill"
    case .newAtHome: "house.fill"
    case .airingNow: "dot.radiowaves.left.and.right"
    case .weekendBinge: "popcorn.fill"
    case .marathonWorthy: "sofa.fill"
    case .epicMovies: "hourglass"
    case .quickWatches: "timer"
    case .boxOffice: "dollarsign.circle.fill"
    case .worldHits: "globe.europe.africa.fill"
    case .hardToQuit: "checkmark.seal.fill"
    case .animeMovies: "film.fill"
    case .mostWatchlisted: "bookmark.fill"
    case .decade: "calendar"
    case .network: "play.tv.fill"
    case .genre: "sparkles"
    case .forYou: "wand.and.stars"
    }
  }

  var badge: DiscoverBadge {
    switch kind {
    case .justReleased: .released
    case .inTheaters: .theater
    case .newAtHome: .home
    case .mostWatchlisted: .watchlisted
    case .quickWatches, .epicMovies: .runtime
    case .weekendBinge, .marathonWorthy: .episodes
    case .boxOffice: .boxOffice
    case .worldHits: .language
    case .hardToQuit: .finishRate
    case .topRated, .lovedEverywhere, .hiddenGems, .airingNow, .animeMovies, .decade, .network,
      .genre, .forYou:
      .rating
    }
  }

  /// How the sort menu names the list's own order. Lists already ranked by
  /// score return nil, so the menu doesn't offer Top Rated twice.
  var featuredSort: String? {
    switch kind {
    case .topRated, .hiddenGems, .decade, .network: nil
    case .boxOffice: "Box Office"
    case .hardToQuit: "Finish Rate"
    case .mostWatchlisted: "Most Watchlisted"
    case .forYou: "Best Match"
    case .lovedEverywhere, .justReleased, .inTheaters, .newAtHome, .airingNow, .weekendBinge,
      .marathonWorthy, .epicMovies, .quickWatches, .worldHits, .animeMovies, .genre:
      "Most Watched"
    }
  }

  static func decadeName(_ decade: Int) -> String {
    decade < 2000 ? "’\(String(decade).suffix(2))s" : "\(decade)s"
  }
}

enum DiscoverRecipes {
  /// Lists shorter than this aren't worth a shelf or tile.
  static let minimumCount = 6

  static func topRated(_ items: [DiscoverItem], minVotes: Int = 500) -> [DiscoverItem] {
    byRating(items.filter { $0.simklVotes >= minVotes && $0.simklRating != nil })
  }

  /// 8+ on Simkl and on IMDb (or MyAnimeList for anime), most watched first so
  /// it doesn't repeat Top Rated.
  static func lovedEverywhere(_ items: [DiscoverItem], minRating: Double = 8, minVotes: Int = 500)
    -> [DiscoverItem]
  {
    byWatched(
      items.filter {
        ($0.simklRating ?? 0) >= minRating && ($0.outsideRating ?? 0) >= minRating
          && $0.simklVotes >= minVotes
      })
  }

  /// Well-rated titles outside Simkl's all-time top 2,000. `watched` only
  /// counts this month's viewers, so rank is the gate that keeps mainstream
  /// hits out.
  static func hiddenGems(
    _ items: [DiscoverItem], minRating: Double = 7.5, minVotes: Int = 500, minRank: Int = 2000
  ) -> [DiscoverItem] {
    byRating(
      items.filter {
        ($0.rank ?? 0) > minRank && ($0.simklRating ?? 0) >= minRating
          && $0.simklVotes >= minVotes
      })
  }

  /// Simkl marks titles in their release window as `premiere`.
  static func justReleased(_ items: [DiscoverItem]) -> [DiscoverItem] {
    byWatched(items.filter { $0.status == "premiere" })
  }

  /// Opened in theaters recently and not yet out at home.
  static func inTheaters(_ items: [DiscoverItem], now: Date, withinDays days: Int = 60)
    -> [DiscoverItem]
  {
    byWatched(
      items.filter { item in
        guard item.type == .movies, let opened = item.theaterDate,
          isRecent(opened, now: now, withinDays: days)
        else { return false }
        return item.homeReleaseDate.map { $0 > now } ?? true
      })
  }

  /// Out on digital or disc recently.
  static func newAtHome(_ items: [DiscoverItem], now: Date, withinDays days: Int = 45)
    -> [DiscoverItem]
  {
    byWatched(
      items.filter { item in
        item.type == .movies
          && item.homeReleaseDate.map { isRecent($0, now: now, withinDays: days) } ?? false
      })
  }

  static func airingNow(_ items: [DiscoverItem]) -> [DiscoverItem] {
    byWatched(items.filter { $0.type != .movies && $0.status == "ongoing" })
  }

  static func weekendBinge(
    _ items: [DiscoverItem], maxEpisodes: Int = 10, minRating: Double = 7.5
  ) -> [DiscoverItem] {
    byWatched(
      items.filter {
        $0.type != .movies && $0.status == "ended"
          && (1...maxEpisodes).contains($0.total_episodes ?? 0) && ($0.simklRating ?? 0) >= minRating
      })
  }

  static func marathonWorthy(
    _ items: [DiscoverItem], episodes: ClosedRange<Int> = 20...100, minRating: Double = 8
  ) -> [DiscoverItem] {
    byWatched(
      items.filter {
        $0.type != .movies && $0.status == "ended"
          && episodes.contains($0.total_episodes ?? 0) && ($0.simklRating ?? 0) >= minRating
      })
  }

  static func epicMovies(_ items: [DiscoverItem], minMinutes: Int = 150, minRating: Double = 7)
    -> [DiscoverItem]
  {
    byWatched(
      items.filter {
        $0.type == .movies && ($0.runtimeMinutes ?? 0) >= minMinutes
          && ($0.simklRating ?? 0) >= minRating
      })
  }

  static func quickWatches(_ items: [DiscoverItem], maxMinutes: Int = 90) -> [DiscoverItem] {
    items.filter { $0.type == .movies && ($0.runtimeMinutes ?? .max) <= maxMinutes }
  }

  /// Grosses under `minGross` are limited releases or bad entries (Simkl lists
  /// one at "$7"), not giants.
  static func boxOffice(_ items: [DiscoverItem], minGross: Double = 1_000_000) -> [DiscoverItem] {
    stableSorted(items.filter { $0.type == .movies && ($0.boxOffice ?? 0) >= minGross }) {
      $0.boxOffice ?? 0
    }
  }

  /// Non-English movies and shows; nearly all anime is Japanese, so it's left out.
  static func worldHits(_ items: [DiscoverItem]) -> [DiscoverItem] {
    byWatched(
      items.filter {
        $0.type != .anime && $0.original_language.map { !$0.isEmpty && $0 != "en" } ?? false
      })
  }

  /// Lowest drop rates among titles with a real audience. Movies drop far less
  /// than series, so each type is ranked on its own and then interleaved.
  static func hardToQuit(_ items: [DiscoverItem], minVotes: Int = 500, limit: Int = 40)
    -> [DiscoverItem]
  {
    let ranked = DiscoverMediaType.allCases.map { type in
      stableSorted(
        items.filter { $0.type == type && $0.dropRate != nil && $0.simklVotes >= minVotes },
        ascending: true
      ) { $0.dropRate ?? 100 }
    }
    return Array(interleaved(ranked).prefix(limit))
  }

  static func animeMovies(_ items: [DiscoverItem]) -> [DiscoverItem] {
    items.filter { $0.type == .anime && $0.anime_type == "movie" }
  }

  static func mostWatchlisted(_ items: [DiscoverItem]) -> [DiscoverItem] {
    stableSorted(items) { Double($0.plan_to_watch ?? 0) }
  }

  static func decade(_ items: [DiscoverItem], _ decade: Int, minVotes: Int = 100) -> [DiscoverItem]
  {
    byRating(
      items.filter {
        guard let year = $0.year else { return false }
        return (decade..<decade + 10).contains(year) && $0.simklVotes >= minVotes
          && $0.simklRating != nil
      })
  }

  /// Networks Simkl spells more than one way in its files.
  static let networkAliases: [String: Set<String>] = [
    "HBO": ["HBO", "HBO Max", "Max"],
    "Apple TV": ["Apple TV", "Apple TV+"],
    "Paramount+": ["Paramount+", "Paramount+ with Showtime"],
    "ABC": ["ABC", "ABC (US)"],
    "BBC": ["BBC One", "BBC Two", "BBC Three", "BBC iPlayer"],
    "FX": ["FX", "FXX", "FX on Hulu"],
    "Showtime": ["Showtime", "SHOWTIME"],
  ]

  static func network(_ items: [DiscoverItem], _ network: String, minRating: Double = 7)
    -> [DiscoverItem]
  {
    let names = networkAliases[network] ?? [network]
    return byRating(
      items.filter {
        $0.type == .shows && names.contains($0.network ?? "") && ($0.simklRating ?? 0) >= minRating
      })
  }

  /// Well-rated titles tagged with a genre, matched across type spellings and
  /// ordered by what's being watched now.
  static func genre(
    _ items: [DiscoverItem], key: String, minRating: Double = 7.5, minVotes: Int = 300
  ) -> [DiscoverItem] {
    byWatched(
      items.filter { item in
        (item.genres ?? []).contains { DiscoverGenre.key(for: $0) == key }
          && (item.simklRating ?? 0) >= minRating && item.simklVotes >= minVotes
      })
  }

  /// Titles outside the library that fit the user's taste. A title's genres
  /// add up (unknown ones count as neutral) and are scaled so piling on genres
  /// doesn't win; Simkl's score breaks near-ties.
  static func forYou(
    _ items: [DiscoverItem], taste: DiscoverTaste, library: [String: DiscoverLibrary.Entry],
    minRating: Double = 6.5, minVotes: Int = 100, limit: Int = 40
  ) -> [DiscoverItem] {
    var scores: [String: Double] = [:]
    for item in items where library[item.id] == nil && item.simklVotes >= minVotes {
      guard let rating = item.simklRating, rating >= minRating else { continue }
      let keys = Set((item.genres ?? []).map(DiscoverGenre.key(for:)))
      guard !keys.isEmpty else { continue }
      let fit = keys.reduce(0) { $0 + (taste.affinity[$1] ?? 0) } / Double(keys.count).squareRoot()
      if fit > 0 { scores[item.id] = fit + (rating - 7) / 10 }
    }
    let picks = items.filter { scores[$0.id] != nil }
    return Array(stableSorted(picks) { scores[$0.id] ?? 0 }.prefix(limit))
  }

  /// Merges per-type lists one from each in turn, so a mixed row isn't all
  /// movies before the first show.
  static func interleaved(_ lists: [[DiscoverItem]]) -> [DiscoverItem] {
    var result: [DiscoverItem] = []
    var index = 0
    while lists.contains(where: { index < $0.count }) {
      for list in lists where index < list.count {
        result.append(list[index])
      }
      index += 1
    }
    return result
  }

  /// Drops repeats by type and id; the same title can appear in two files.
  static func unique(_ items: [DiscoverItem]) -> [DiscoverItem] {
    var seen = Set<String>()
    return items.filter { seen.insert($0.id).inserted }
  }

  private static func isRecent(_ date: Date, now: Date, withinDays days: Int) -> Bool {
    date <= now && now.timeIntervalSince(date) <= TimeInterval(days) * 24 * 60 * 60
  }

  private static func byRating(_ items: [DiscoverItem]) -> [DiscoverItem] {
    stableSorted(items) { $0.simklRating ?? 0 }
  }

  private static func byWatched(_ items: [DiscoverItem]) -> [DiscoverItem] {
    stableSorted(items) { Double($0.watched ?? 0) }
  }

  /// Highest key first unless `ascending`. Keys are read once per title, since
  /// some (box office, drop rate) parse strings, and the sort moves indices
  /// rather than whole titles. Ties keep the file's popularity order instead of
  /// shuffling between runs.
  private static func stableSorted(
    _ items: [DiscoverItem], ascending: Bool = false, by key: (DiscoverItem) -> Double
  ) -> [DiscoverItem] {
    let keys = items.map(key)
    return items.indices.sorted { lhs, rhs in
      if keys[lhs] < keys[rhs] { return ascending }
      if keys[rhs] < keys[lhs] { return !ascending }
      return lhs < rhs
    }.map { items[$0] }
  }
}

/// What the user's ratings say about genres. Genres are only known on device
/// for titles in Simkl's files, so this learns from library titles that also
/// appear there, and For You stays hidden until there's enough to go on.
struct DiscoverTaste: Sendable {
  /// Per genre key: above zero means the user rates the genre above their own
  /// average (or, short of ratings, watches a lot of it).
  let affinity: [String: Double]
  /// Up to two genres that drive the picks, named for the row's subtitle.
  let favorites: [String]
  /// False when watch history stood in for too few ratings.
  let fromRatings: Bool

  /// Matched titles needed before For You appears.
  static let minimumTitles = 5
  /// Titles a genre needs before it's named as a favorite.
  static let minimumPerGenre = 3
  /// Unrated titles still say something through their list.
  static let statusWeights: [String: Double] = [
    "completed": 1, "watching": 1, "plantowatch": 0.5, "hold": 0, "dropped": -1.5,
  ]

  init?(library: [String: DiscoverLibrary.Entry], catalog: [DiscoverItem]) {
    var genres: [String: Set<String>] = [:]
    var names: [String: [DiscoverMediaType: String]] = [:]
    for item in catalog {
      genres[item.id] = Set((item.genres ?? []).map(DiscoverGenre.key(for:)))
      for name in item.genres ?? [] {
        names[DiscoverGenre.key(for: name), default: [:]][item.type] = name
      }
    }

    // Read scores against the user's own average, since some rate everything 8+.
    let ratings = library.values.compactMap(\.rating).filter { (1...10).contains($0) }
    let average = ratings.count >= 3 ? Double(ratings.reduce(0, +)) / Double(ratings.count) : 7
    var rated: [(keys: Set<String>, weight: Double)] = []
    var watched: [(keys: Set<String>, weight: Double)] = []
    for (id, entry) in library {
      guard let keys = genres[id], !keys.isEmpty else { continue }
      if let rating = entry.rating, (1...10).contains(rating) {
        rated.append((keys, Double(rating) - average))
      } else if let weight = Self.statusWeights[entry.status ?? ""] {
        watched.append((keys, weight))
      }
    }
    fromRatings = rated.count >= Self.minimumTitles
    let signals = fromRatings ? rated : rated + watched
    guard signals.count >= Self.minimumTitles else { return nil }

    var sums: [String: Double] = [:]
    var counts: [String: Int] = [:]
    for signal in signals {
      for key in signal.keys {
        sums[key, default: 0] += signal.weight
        counts[key, default: 0] += 1
      }
    }
    // Shrink small samples toward neutral, so one 10 doesn't crown a genre.
    var affinity: [String: Double] = [:]
    for (key, sum) in sums {
      affinity[key] = sum / Double((counts[key] ?? 0) + 2)
    }
    let leaders = affinity.filter { $0.value > 0 && (counts[$0.key] ?? 0) >= Self.minimumPerGenre }
      .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
    guard !leaders.isEmpty else { return nil }
    self.affinity = affinity
    favorites = leaders.prefix(2).map { key, _ in
      let spellings = names[key] ?? [:]
      return spellings[.movies] ?? spellings[.shows] ?? spellings[.anime] ?? key.capitalized
    }
  }
}

/// Genres that share a name across types, so "All" can show one Horror tile
/// that opens movies, shows, or anime.
struct DiscoverGenreGroup: Identifiable, Hashable, Sendable {
  let key: String
  let genres: [DiscoverMediaType: DiscoverGenre]

  var id: String { key }

  var types: [DiscoverMediaType] { DiscoverMediaType.allCases.filter { genres[$0] != nil } }

  /// Prefers the movie spelling ("Science Fiction") over TV and anime variants.
  var name: String {
    (genres[.movies] ?? genres[.shows] ?? genres[.anime])?.name ?? key.capitalized
  }

  /// Popular genres lead; the rest follow alphabetically.
  static let featuredKeys = [
    "action", "comedy", "drama", "sciencefiction", "horror", "thriller", "romance", "crime",
    "animation", "fantasy", "mystery", "adventure", "documentary", "family", "shounen", "isekai",
    "sliceoflife", "sports", "reality", "koreandrama",
  ]

  static func groups(
    from index: [DiscoverMediaType: [DiscoverGenre]], types: [DiscoverMediaType]
  ) -> [DiscoverGenreGroup] {
    var byKey: [String: [DiscoverMediaType: DiscoverGenre]] = [:]
    for type in types {
      for genre in index[type] ?? [] where genre.isBrowsable {
        byKey[genre.key, default: [:]][type] = genre
      }
    }
    return byKey.map { DiscoverGenreGroup(key: $0.key, genres: $0.value) }.sorted { lhs, rhs in
      let left = featuredKeys.firstIndex(of: lhs.key) ?? .max
      let right = featuredKeys.firstIndex(of: rhs.key) ?? .max
      return left != right ? left < right : lhs.name < rhs.name
    }
  }
}

/// One block on the Explore page, in display order.
enum ExploreSection: Identifiable, Sendable {
  case hero
  case genres
  case trending(ExploreSnapshot.TrendingRow)
  case collections
  case shelf(DiscoverList)
  case streaming
  case networks
  case decades

  var id: String {
    switch self {
    case .hero: "hero"
    case .genres: "genres"
    case .trending(let row): "trending-\(row.type.rawValue)"
    case .collections: "collections"
    case .shelf(let list): list.id
    case .streaming: "streaming"
    case .networks: "networks"
    case .decades: "decades"
    }
  }
}

/// Everything one Explore filter shows, computed once per data change.
struct ExploreSnapshot: Sendable {
  struct TrendingRow: Identifiable, Sendable {
    let type: DiscoverMediaType
    let items: [DiscoverItem]
    var id: DiscoverMediaType { type }
  }

  var hero: [DiscoverItem] = []
  /// Each trending title's place in today's full chart for its type, so
  /// hidden library titles leave gaps instead of renumbering the rest.
  var ranks: [String: Int] = [:]
  var genres: [DiscoverGenreGroup] = []
  /// Today's top titles per type, in Simkl's order.
  var trending: [TrendingRow] = []
  /// Picks from the user's favorite genres, when the library says enough.
  var forYou: DiscoverList?
  /// Every curated list, in Collections order.
  var collections: [DiscoverList] = []
  var streaming: [DiscoverList] = []
  var networks: [DiscoverList] = []
  var decades: [DiscoverList] = []
  /// Today's genre shelves; the picks rotate daily.
  var spotlights: [DiscoverList] = []
  var sections: [ExploreSection] = []

  var isEmpty: Bool { sections.isEmpty }

  /// The titles the page renders up front, for library lookups.
  var visibleItems: [DiscoverItem] {
    hero + trending.flatMap { row in row.items.prefix { (ranks[$0.id] ?? .max) <= 10 } }
      + sections.flatMap { section -> ArraySlice<DiscoverItem> in
        if case .shelf(let list) = section { return list.items.prefix(20) }
        return []
      }
  }

  static let streamingNames = [
    "Netflix", "HBO", "Apple TV", "Prime Video", "Disney+", "Hulu", "Paramount+", "Peacock",
    "STARZ", "MGM+", "AMC+",
  ]
  static let networkNames = [
    "CBS", "NBC", "ABC", "FOX", "FX", "AMC", "BBC", "The CW", "USA Network", "Showtime",
    "Adult Swim", "Cartoon Network", "Nickelodeon", "SYFY", "The WB",
  ]
  static let decadeStarts = [2020, 2010, 2000, 1990, 1980, 1970, 1960, 1950]
  static let featuredCollections = 6

  init() {}

  init(
    trending: [DiscoverMediaType: [DiscoverItem]],
    pools: [DiscoverMediaType: [DiscoverItem]],
    genreIndex: [DiscoverMediaType: [DiscoverGenre]],
    types: [DiscoverMediaType],
    library: [String: DiscoverLibrary.Entry] = [:],
    hidesLibrary: Bool = false,
    now: Date = Date()
  ) {
    let hidden: Set<String> =
      hidesLibrary ? Set(library.compactMap { $0.value.status == nil ? nil : $0.key }) : []
    let visible = { (items: [DiscoverItem]) in
      items.filter { !$0.isAdult && !hidden.contains($0.id) }
    }
    let charts = types.map { type in
      TrendingRow(type: type, items: (trending[type] ?? []).filter { !$0.isAdult })
    }
    ranks = Dictionary(
      charts.flatMap { row in row.items.enumerated().map { ($0.element.id, $0.offset + 1) } },
      uniquingKeysWith: { first, _ in first })
    let today = charts.map { TrendingRow(type: $0.type, items: visible($0.items)) }.filter {
      !$0.items.isEmpty
    }
    self.trending = today

    // Movies lead the hero; their backdrops are the most consistent. Titles
    // without fanart fall back to a poster wash, so prefer ones that have it.
    let heroPerType = types.count == 1 ? 8 : 3
    hero = DiscoverRecipes.interleaved(
      today.sorted { $0.type == .movies && $1.type != .movies }.map { row in
        let withArt = row.items.filter { $0.fanartPath != nil }
        return Array((withArt.count >= heroPerType ? withArt : row.items).prefix(heroPerType))
      })

    genres = DiscoverGenreGroup.groups(from: genreIndex, types: types)

    let pool = DiscoverRecipes.unique(types.flatMap { visible(pools[$0] ?? []) })
    func list(_ kind: DiscoverListKind, _ items: [DiscoverItem]) -> DiscoverList? {
      let listTypes = types.filter { type in items.contains { $0.type == type } }
      guard items.count >= DiscoverRecipes.minimumCount else { return nil }
      return DiscoverList(kind: kind, types: listTypes, items: items)
    }

    var lists: [DiscoverListKind: DiscoverList] = [:]
    for kind in DiscoverListKind.collections {
      let items: [DiscoverItem] =
        switch kind {
        case .topRated: DiscoverRecipes.topRated(pool)
        case .lovedEverywhere: DiscoverRecipes.lovedEverywhere(pool)
        case .hiddenGems: DiscoverRecipes.hiddenGems(pool)
        case .justReleased: DiscoverRecipes.justReleased(pool)
        case .inTheaters: DiscoverRecipes.inTheaters(pool, now: now)
        case .newAtHome: DiscoverRecipes.newAtHome(pool, now: now)
        case .airingNow: DiscoverRecipes.airingNow(pool)
        case .weekendBinge: DiscoverRecipes.weekendBinge(pool)
        case .marathonWorthy: DiscoverRecipes.marathonWorthy(pool)
        case .epicMovies: DiscoverRecipes.epicMovies(pool)
        case .quickWatches: DiscoverRecipes.quickWatches(pool)
        case .boxOffice: DiscoverRecipes.boxOffice(pool)
        case .worldHits: DiscoverRecipes.worldHits(pool)
        case .hardToQuit: DiscoverRecipes.hardToQuit(pool)
        case .animeMovies: DiscoverRecipes.animeMovies(pool)
        case .mostWatchlisted: DiscoverRecipes.mostWatchlisted(pool)
        case .decade, .network, .genre, .forYou: []
        }
      lists[kind] = list(kind, items)
    }
    collections = DiscoverListKind.collections.compactMap { lists[$0] }
    streaming = Self.streamingNames.compactMap {
      list(.network($0), DiscoverRecipes.network(pool, $0))
    }
    networks = Self.networkNames.compactMap {
      list(.network($0), DiscoverRecipes.network(pool, $0))
    }
    // Bucket by decade once rather than parsing every title's year per decade.
    let byDecade = Dictionary(grouping: pool) { ($0.year ?? 0) / 10 * 10 }
    decades = Self.decadeStarts.compactMap {
      list(.decade($0), DiscoverRecipes.decade(byDecade[$0] ?? [], $0))
    }

    // Three featured genres a day, spread across the list so consecutive
    // days don't repeat. Titles are grouped by genre once, not per genre.
    var byGenre: [String: [DiscoverItem]] = [:]
    for item in pool {
      for key in Set((item.genres ?? []).map(DiscoverGenre.key(for:))) {
        byGenre[key, default: []].append(item)
      }
    }
    let candidates = genres.filter { DiscoverGenreGroup.featuredKeys.contains($0.key) }
      .compactMap { group in
        list(
          .genre(key: group.key, name: group.name),
          DiscoverRecipes.genre(byGenre[group.key] ?? [], key: group.key))
      }
    if !candidates.isEmpty {
      let day = Calendar.current.ordinality(of: .day, in: .era, for: now) ?? 0
      let step = max(1, candidates.count / 3)
      let picks = (0..<3).map { (day + $0 * step) % candidates.count }
      spotlights = picks.reduce(into: []) { picked, index in
        if !picked.contains(where: { $0.id == candidates[index].id }) {
          picked.append(candidates[index])
        }
      }
    }

    // Taste is learned from every title with known genres, in any type, and
    // picks come from this filter's pool. Library titles never qualify.
    let catalog = DiscoverRecipes.unique(
      DiscoverMediaType.allCases.flatMap { (trending[$0] ?? []) + (pools[$0] ?? []) })
    if let taste = DiscoverTaste(library: library, catalog: catalog) {
      forYou = list(
        .forYou(favorites: taste.favorites, fromRatings: taste.fromRatings),
        DiscoverRecipes.forYou(pool, taste: taste, library: library))
    }

    var sections: [ExploreSection] = []
    func shelf(_ list: DiscoverList?) {
      if let list { sections.append(.shelf(list)) }
    }
    if !hero.isEmpty { sections.append(.hero) }
    shelf(forYou)
    if !genres.isEmpty { sections.append(.genres) }
    if !streaming.isEmpty { sections.append(.streaming) }
    // A chart whose whole top ten is hidden drops out.
    sections += today.filter { row in row.items.contains { (ranks[$0.id] ?? .max) <= 10 } }
      .map { .trending($0) }
    if !collections.isEmpty { sections.append(.collections) }
    shelf(lists[.topRated])
    // Movies get theater and home-release rows instead.
    shelf(types == [.movies] ? nil : lists[.justReleased])
    shelf(lists[.inTheaters])
    shelf(spotlights.first)
    shelf(lists[.lovedEverywhere])
    if !networks.isEmpty { sections.append(.networks) }
    shelf(lists[.airingNow])
    shelf(lists[.newAtHome])
    shelf(spotlights.dropFirst().first)
    shelf(lists[.hiddenGems])
    if !decades.isEmpty { sections.append(.decades) }
    shelf(lists[.weekendBinge])
    shelf(lists[.epicMovies])
    shelf(lists[.boxOffice])
    shelf(lists[.marathonWorthy])
    shelf(spotlights.dropFirst(2).first)
    shelf(lists[.worldHits])
    shelf(lists[.animeMovies])
    shelf(lists[.hardToQuit])
    shelf(lists[.quickWatches])
    shelf(lists[.mostWatchlisted])
    self.sections = sections
  }
}
