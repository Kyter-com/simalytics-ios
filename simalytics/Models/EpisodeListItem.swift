import Foundation

/// A display row keeps its catalog ID separate from SIMKL's watch coordinates.
struct EpisodeListItem: Identifiable, Equatable, Sendable {
  let id: Int
  let group: Int
  let watchSeason: Int?
  let number: Int?
  let title: String
  let overview: String
  let preview: String
  let image: String?
  let airDate: Date?
  let supportsWatchAction: Bool

  var numberLabel: String { number.map { "Episode \($0)" } ?? "Episode" }
  var canMarkWatched: Bool {
    supportsWatchAction && validatedSimklEpisode(season: watchSeason, episode: number) != nil
  }

  init(show: ShowEpisodeModel) {
    self.init(
      id: show.ids.simkl_id, group: show.type == "special" ? 0 : (show.season ?? -1),
      watchSeason: show.type == "special" ? 0 : show.season, number: show.episode,
      title: show.title, overview: show.description, image: show.img, date: show.date)
  }

  init(anime: AnimeEpisodeModel) {
    self.init(
      id: anime.ids.simkl_id, group: anime.type == "special" ? 0 : (anime.season ?? 1),
      watchSeason: AnimeDetailView.watchlistSeason(for: anime), number: anime.episode,
      title: anime.title, overview: anime.description, image: anime.img, date: anime.date,
      supportsWatchAction: anime.type != "special")
  }

  init(
    id: Int, group: Int, watchSeason: Int?, number: Int?, title: String,
    overview: String?, image: String?, date: String?, supportsWatchAction: Bool = true
  ) {
    self.id = id
    self.group = group
    self.watchSeason = watchSeason
    self.number = number
    self.supportsWatchAction = supportsWatchAction
    self.title = title
    // Long anime catalogs build a thousand-plus rows at once; skip the regex
    // passes for the common plain-text description.
    var plainText = overview ?? ""
    if plainText.contains("<") {
      plainText =
        plainText
        .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
    plainText = plainText.trimmingCharacters(in: .whitespacesAndNewlines)
    self.overview = plainText
    self.preview = plainText.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    self.image = image
    self.airDate = date.flatMap { SimklDateParser.date(from: $0) }
  }
}
