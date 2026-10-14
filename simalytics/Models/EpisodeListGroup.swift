struct EpisodeListGroup: Identifiable, Sendable {
  let id: Int
  let title: String
  let episodes: [EpisodeListItem]

  init(id: Int, episodes: [EpisodeListItem], isAnime: Bool) {
    self.id = id
    self.episodes = episodes.sorted {
      if $0.number == $1.number { return $0.id < $1.id }
      return ($0.number ?? .max) < ($1.number ?? .max)
    }
    if id == 0 {
      title = "Specials"
    } else if isAnime, let first = self.episodes.first?.number,
      let last = self.episodes.last?.number
    {
      title = first == last ? "Episode \(first)" : "Episodes \(first)–\(last)"
    } else {
      title = "Season \(id)"
    }
  }
}
