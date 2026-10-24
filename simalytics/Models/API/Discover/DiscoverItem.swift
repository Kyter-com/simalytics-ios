//
//  DiscoverItem.swift
//  simalytics
//

import Foundation

/// The catalogs Simkl publishes discovery files for. Raw values are the
/// path segments (and combined-file keys) on data.simkl.in.
enum DiscoverMediaType: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
  case shows = "tv"
  case movies
  case anime

  var id: String { rawValue }

  var title: String {
    switch self {
    case .shows: "Shows"
    case .movies: "Movies"
    case .anime: "Anime"
    }
  }

  var singularTitle: String {
    switch self {
    case .shows: "Show"
    case .movies: "Movie"
    case .anime: "Anime"
    }
  }

  /// The media type string preview cards and local snapshots use.
  var mediaType: String {
    switch self {
    case .shows: "tv"
    case .movies: "movie"
    case .anime: "anime"
    }
  }
}

/// One title from Simkl's trending or genre files. Only the fields Explore
/// renders are decoded; `alt_titles` and the rest are skipped.
struct DiscoverItem: Codable, Hashable, Identifiable, Sendable {
  struct IDs: Codable, Hashable, Sendable {
    let simkl_id: Int
    let slug: String?
  }

  struct Score: Codable, Hashable, Sendable {
    let rating: Double?
    let votes: Int?
  }

  struct Ratings: Codable, Hashable, Sendable {
    let simkl: Score?
    let imdb: Score?
    let mal: Score?
  }

  let title: String
  let url: String?
  let poster: String?
  let fanart: String?
  let ids: IDs
  let release_date: String?
  let rank: Int?
  let watched: Int?
  let plan_to_watch: Int?
  let ratings: Ratings?
  let runtime: String?
  let status: String?
  let genres: [String]?
  let network: String?
  let total_episodes: Int?
  let anime_type: String?
  var drop_rate: String? = nil
  /// A summary line such as "July 29, 2026 • Budget $225M • Box office $2,516M".
  var metadata: String? = nil
  var original_language: String? = nil
  /// Movies only: theatrical and home (digital or disc) release dates.
  var theater: String? = nil
  var dvd_date: String? = nil
  /// Simkl's synopsis; some anime have an empty one.
  var overview: String? = nil
  /// A YouTube video id.
  var trailer: String? = nil
  /// Files are per type and items carry no type field, so the store sets it.
  var type: DiscoverMediaType = .movies

  private enum CodingKeys: String, CodingKey {
    case title, url, poster, fanart, ids, release_date, rank, watched, plan_to_watch
    case ratings, runtime, status, genres, network, total_episodes, anime_type
    case drop_rate, metadata, original_language, theater, dvd_date, overview, trailer
  }

  var id: String { Self.id(type, ids.simkl_id) }
  var simklID: Int { ids.simkl_id }

  /// The key Explore uses for a title everywhere, including library lookups.
  /// Simkl ids never repeat across catalogs, but the type keeps keys readable.
  static func id(_ type: DiscoverMediaType, _ simklID: Int) -> String {
    "\(type.rawValue)-\(simklID)"
  }

  var summary: String? {
    overview.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .flatMap { $0.isEmpty ? nil : $0 }
  }

  /// Opens in the YouTube app when it's installed.
  var trailerURL: URL? {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
    guard let trailer, !trailer.isEmpty, trailer.unicodeScalars.allSatisfy(allowed.contains)
    else { return nil }
    var components = URLComponents(string: "https://www.youtube.com/watch")!
    components.queryItems = [URLQueryItem(name: "v", value: trailer)]
    return components.url
  }

  var posterPath: String? { poster.flatMap { $0.isEmpty ? nil : $0 } }
  var fanartPath: String? { fanart.flatMap { $0.isEmpty ? nil : $0 } }

  var posterURL: String? { posterPath.map { "\(SIMKL_CDN_URL)/posters/\($0)_m.jpg" } }
  var fanartURL: String? { fanartPath.map { "\(SIMKL_CDN_URL)/fanart/\($0)_mobile.jpg" } }

  /// Simkl's community score, ignoring placeholder zeros on unrated titles.
  var simklRating: Double? {
    guard let rating = ratings?.simkl?.rating, rating > 0 else { return nil }
    return rating
  }

  var simklVotes: Int { ratings?.simkl?.votes ?? 0 }

  /// IMDb for movies and shows, MyAnimeList for anime.
  var outsideRating: Double? {
    guard let rating = ratings?.imdb?.rating ?? ratings?.mal?.rating, rating > 0 else { return nil }
    return rating
  }

  /// Share of viewers who started and gave up, from strings like "0.3%".
  var dropRate: Double? {
    drop_rate.flatMap {
      Double($0.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces))
    }
  }

  /// Worldwide box office in dollars, parsed from `metadata`.
  var boxOffice: Double? {
    guard let metadata, let range = metadata.range(of: "Box office $") else { return nil }
    let amount = metadata[range.upperBound...].prefix { $0.isNumber || $0 == "," || $0 == "." }
    guard let value = Double(amount.replacingOccurrences(of: ",", with: "")) else { return nil }
    switch metadata[range.upperBound...].dropFirst(amount.count).first {
    case "B": return value * 1_000_000_000
    case "M": return value * 1_000_000
    case "K": return value * 1_000
    default: return value
    }
  }

  var releaseDate: Date? { Self.date(fromSimkl: release_date) }
  var theaterDate: Date? { Self.date(fromSimkl: theater) }
  var homeReleaseDate: Date? { Self.date(fromSimkl: dvd_date) }

  /// Reads `MM/DD/YYYY` and ISO `YYYY-MM-DD…` dates as local calendar days.
  static func date(fromSimkl raw: String?) -> Date? {
    guard let raw, !raw.isEmpty else { return nil }
    let parts: [Int]
    if raw.contains("/") {
      let fields = raw.split(separator: "/").compactMap { Int($0) }
      guard fields.count == 3 else { return nil }
      parts = [fields[2], fields[0], fields[1]]
    } else {
      let fields = raw.prefix(10).split(separator: "-").compactMap { Int($0) }
      guard fields.count == 3 else { return nil }
      parts = fields
    }
    return Calendar.current.date(
      from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
  }

  var year: Int? { Self.year(fromReleaseDate: release_date) }

  /// Discover files use `MM/DD/YYYY`; other Simkl lists use ISO dates. Returns
  /// nil rather than guessing when neither end holds a sensible year.
  static func year(fromReleaseDate raw: String?) -> Int? {
    guard let raw, !raw.isEmpty else { return nil }
    let separator: Character = raw.contains("/") ? "/" : "-"
    let parts = raw.split(separator: separator)
    // Try the last component first (MM/DD/YYYY), then the first (YYYY-MM-DD).
    for candidate in [parts.last, parts.first].compactMap({ $0 }) {
      if let year = Int(candidate), year > 1800, year < 2200 {
        return year
      }
    }
    return nil
  }

  /// Runtime strings look like `2h 25m`, `45m`, or `1h`.
  var runtimeMinutes: Int? {
    guard let runtime, !runtime.isEmpty else { return nil }
    var minutes = 0
    var digits = ""
    for character in runtime {
      if character.isNumber {
        digits.append(character)
      } else if character == "h" || character == "m", let value = Int(digits) {
        minutes += character == "h" ? value * 60 : value
        digits = ""
      } else if character != " " {
        return nil
      }
    }
    return digits.isEmpty && minutes > 0 ? minutes : nil
  }

  /// Simkl tags adult titles with these genres; App Store apps should skip them.
  static let adultGenres: Set<String> = ["Erotica", "Hentai"]

  var isAdult: Bool { genres?.contains(where: Self.adultGenres.contains) ?? false }

  /// Links back to the title's own Simkl page, slug included when known.
  var webURL: URL {
    if let url, url.hasPrefix("/"), let link = URL(string: "https://simkl.com\(url)") {
      return link
    }
    let section = type == .movies ? "movies" : type.rawValue
    return URL(string: "https://simkl.com/\(section)/\(simklID)/\(ids.slug ?? "")")!
  }

  func with(type: DiscoverMediaType) -> DiscoverItem {
    var copy = self
    copy.type = type
    return copy
  }
}

/// An entry in a type's `genre/index.json`, which lists the genres that have a file.
struct DiscoverGenre: Codable, Hashable, Identifiable, Sendable {
  let name: String
  let slug: String
  let count: Int?

  var id: String { slug }

  /// Adult genres, plus fan-service ecchi, are kept out of the browse tiles.
  static let hiddenSlugs: Set<String> = ["erotica", "hentai", "ecchi"]
  /// Genres this small make a thin page (e.g. TV "Video Game Play" has 1 title).
  static let minimumCount = 20

  var isBrowsable: Bool {
    !Self.hiddenSlugs.contains(slug) && (count ?? 0) >= Self.minimumCount
  }

  var key: String { Self.key(for: name) }

  /// Folds the per-type spellings together: movies and TV use "Science Fiction"
  /// and "Science-Fiction" while anime uses "Sci-Fi"; TV's "Sport" is anime's
  /// "Sports", and "History" is anime's "Historical".
  static func key(for name: String) -> String {
    let letters = name.lowercased().filter(\.isLetter)
    return keyAliases[letters] ?? letters
  }

  private static let keyAliases = [
    "scifi": "sciencefiction", "sport": "sports", "historical": "history",
  ]
}

/// Decodes an array but drops elements that fail, so one malformed title
/// can't blank a whole shelf.
struct LossyArray<Element: Decodable>: Decodable {
  let elements: [Element]

  init(from decoder: Decoder) throws {
    var container = try decoder.unkeyedContainer()
    var elements: [Element] = []
    while !container.isAtEnd {
      if let element = try? container.decode(Element.self) {
        elements.append(element)
      } else {
        // A failed decode doesn't advance the container; skip the element.
        _ = try container.decode(Skip.self)
      }
    }
    self.elements = elements
  }

  private struct Skip: Decodable {
    init(from decoder: Decoder) throws {}
  }
}
