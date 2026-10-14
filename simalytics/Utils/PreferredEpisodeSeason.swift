/// Resume at the highest watched season, advancing when that season is complete.
/// Older unwatched seasons remain available without pulling returning viewers back.
/// With no watched episodes, start at the first season; when caught up, keep the last.
nonisolated func preferredEpisodeSeason<Episode>(
  in episodes: [Episode],
  season: (Episode) -> Int?,
  isWatched: (Episode) -> Bool
) -> Int? {
  var lastSeason: Int?
  var highestWatchedSeason = 0
  var unwatchedSeasons = Set<Int>()

  for episode in episodes {
    guard let number = season(episode), number > 0 else { continue }
    lastSeason = max(lastSeason ?? number, number)
    if isWatched(episode) {
      highestWatchedSeason = max(highestWatchedSeason, number)
    } else {
      unwatchedSeasons.insert(number)
    }
  }

  return unwatchedSeasons.filter { $0 >= highestWatchedSeason }.min() ?? lastSeason
}
