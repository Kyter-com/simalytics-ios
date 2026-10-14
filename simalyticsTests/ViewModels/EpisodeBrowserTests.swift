import Foundation
import Testing

@testable import Simalytics

@MainActor
struct EpisodeBrowserTests {
  private func item(_ number: Int, group: Int = 1, watchSeason: Int? = 1) -> EpisodeListItem {
    EpisodeListItem(
      id: group * 1000 + number, group: group, watchSeason: watchSeason, number: number,
      title: "Episode \(number)", overview: nil, image: nil, date: nil)
  }

  private func watched(_ numbers: [Int], season: Int = 1) -> [WatchlistSeason] {
    [
      WatchlistSeason(
        number: season, episodes_total: nil, episodes_aired: nil, episodes_to_be_aired: nil,
        episodes_watched: numbers.count,
        episodes: numbers.map {
          WatchlistEpisode(number: $0, watched: true, aired: true, last_watched_at: nil)
        })
    ]
  }

  @Test("TV browser resumes at season 29 after season 28 while season 1 remains skipped")
  func resumesForward() {
    let browser = EpisodeBrowserModel(
      episodes: [
        item(1), item(1, group: 29, watchSeason: 29), item(1, group: 28, watchSeason: 28),
      ],
      seasons: watched([1], season: 28), isAnime: false)
    #expect(browser.selectedGroup == 29)
    #expect(browser.groups.map(\.title) == ["Season 1", "Season 28", "Season 29"])
  }

  @Test("Anime display groups retain absolute SIMKL watch coordinates")
  func animeMapping() {
    let anime = AnimeEpisodeModel(
      title: "Chapter", description: nil, episode: 1180, type: nil, aired: true,
      img: nil, date: nil, season: 12, ids: AnimeEpisodeModelIds(simkl_id: 1180))
    let episode = EpisodeListItem(anime: anime)
    #expect(episode.group == 12)
    #expect(episode.watchSeason == 1)
    #expect(episode.number == 1180)
    let browser = EpisodeBrowserModel(
      episodes: [item(1), episode, item(1181, group: 12)],
      seasons: watched([1180]), isAnime: true)
    #expect(browser.selectedGroup == 12)
    #expect(browser.currentGroup?.title == "Episodes 1180–1181")
    #expect(browser.watchedCount == 1)
    #expect(browser.nextUnwatched?.number == 1181)
  }

  @Test("Jump moves forward past older gaps and stops when caught up")
  func jumpRespectsProgress() {
    let browser = EpisodeBrowserModel(
      episodes: [item(3), item(1), item(2)], seasons: watched([2]), isAnime: false)
    #expect(browser.nextUnwatched?.number == 3)
    browser.updateWatched(seasons: watched([2, 3]))
    #expect(browser.nextUnwatched == nil)
    #expect(browser.watchedCount == 2)
  }

  @Test("Anime specials preserve watched status and their existing read-only actions")
  func animeSpecialsStayReadOnly() {
    let episode = EpisodeListItem(
      anime: AnimeEpisodeModel(
        title: "Special", description: nil, episode: 1, type: "special", aired: true,
        img: nil, date: nil, season: 0, ids: AnimeEpisodeModelIds(simkl_id: 1)))
    let browser = EpisodeBrowserModel(
      episodes: [episode], seasons: watched([1], season: 0), isAnime: true)
    #expect(browser.currentGroup?.title == "Specials")
    #expect(browser.watchedCount == 1)
    #expect(episode.canMarkWatched == false)
  }

  @Test("TV episodes without a season are not mislabeled as specials")
  func missingSeasonIsNotSpecial() {
    let episode = EpisodeListItem(
      show: ShowEpisodeModel(
        title: "Unknown", description: nil, season: nil, episode: 1, type: nil,
        date: nil, img: nil, aired: nil, ids: ShowEpisodeModelIds(simkl_id: 1)))
    let browser = EpisodeBrowserModel(episodes: [episode], seasons: nil, isAnime: false)
    #expect(browser.groups.isEmpty)
  }

  @Test("Specials stay separate, duplicate IDs are removed, and empty catalogs are safe")
  func catalogBoundaries() {
    let browser = EpisodeBrowserModel(
      episodes: [item(1, group: 0, watchSeason: 0), item(1), item(1)],
      seasons: nil, isAnime: false)
    #expect(browser.groups.map(\.title) == ["Season 1", "Specials"])
    #expect(browser.currentGroup?.episodes.count == 1)
    let empty = EpisodeBrowserModel(episodes: [], seasons: nil, isAnime: true)
    #expect(empty.currentGroup == nil)
    #expect(empty.nextUnwatched == nil)
  }

  @Test("Long descriptions keep their full text while row previews remove line breaks")
  func normalizesPreviewOnce() {
    let episode = EpisodeListItem(
      id: 1, group: 1, watchSeason: 1, number: 1, title: "Title",
      overview: "<p>First paragraph.</p><br />\n\nSecond paragraph.   More words.", image: nil,
      date: "2026-10-11T21:00:00.000+09:00")
    #expect(episode.preview == "First paragraph. Second paragraph. More words.")
    #expect(episode.overview.contains("\n"))
    #expect(episode.airDate == ISO8601DateFormatter().date(from: "2026-10-11T12:00:00Z"))
  }

  @Test("Marking an episode works without existing watched-season data")
  func firstWatch() async {
    let episode = item(1)
    let browser = EpisodeBrowserModel(episodes: [episode], seasons: nil, isAnime: false)
    var committed = false
    await browser.toggle(
      episode,
      mutation: { selected, willWatch in
        #expect(selected == episode)
        #expect(willWatch)
        #expect(browser.watchedCount == 1)
        return .succeeded
      }, commit: { _, _ in committed = true }, reconcile: { nil })
    #expect(committed)
    #expect(browser.watchedIDs.contains(episode.id))
    #expect(browser.updatingID == nil)
  }

  @Test("Unwatch updates the same row and progress without changing selection")
  func unwatch() async {
    let episode = item(1, group: 28, watchSeason: 28)
    let browser = EpisodeBrowserModel(
      episodes: [item(1), episode], seasons: watched([1], season: 28), isAnime: false)
    await browser.toggle(
      episode,
      mutation: { _, willWatch in
        #expect(willWatch == false)
        return .succeeded
      }, commit: { _, _ in }, reconcile: { nil })
    #expect(browser.watchedIDs.isEmpty)
    #expect(browser.selectedGroup == 28)
  }

  @Test("Failed writes restore progress and expose the server-safe error")
  func rollbackFailure() async {
    let episode = item(1)
    let browser = EpisodeBrowserModel(episodes: [episode], seasons: nil, isAnime: false)
    await browser.toggle(
      episode, mutation: { _, _ in .failed(userMessage: "Please try again.") },
      commit: { _, _ in Issue.record("Failed writes must not commit") }, reconcile: { nil })
    #expect(browser.watchedIDs.isEmpty)
    #expect(browser.errorMessage == "Please try again.")
    #expect(browser.updatingID == nil)
  }

  @Test("Cancelled writes restore progress without presenting an error")
  func rollbackCancellation() async {
    let episode = item(1)
    let browser = EpisodeBrowserModel(episodes: [episode], seasons: nil, isAnime: false)
    await browser.toggle(
      episode, mutation: { _, _ in .cancelled },
      commit: { _, _ in Issue.record("Cancelled writes must not commit") },
      reconcile: {
        Issue.record("Cancelled writes must not reconcile")
        return nil
      })
    #expect(browser.watchedIDs.isEmpty)
    #expect(browser.errorMessage == nil)
  }

  @Test("A server refresh updates checkmarks while preserving the chosen group")
  func reconciliation() async {
    let browser = EpisodeBrowserModel(
      episodes: [item(1), item(2), item(1, group: 2, watchSeason: 2)],
      seasons: nil, isAnime: false)
    await browser.toggle(
      item(1), mutation: { _, _ in .succeeded }, commit: { _, _ in },
      reconcile: { watched([1, 2]) })
    #expect(browser.watchedCount == 2)
    #expect(browser.selectedGroup == 1)
  }

  @Test("Invalid coordinates never reach the mutation callback")
  func invalidCoordinates() async {
    let episode = item(1, watchSeason: nil)
    let browser = EpisodeBrowserModel(episodes: [episode], seasons: nil, isAnime: false)
    await browser.toggle(
      episode,
      mutation: { _, _ in
        Issue.record("Invalid write")
        return .succeeded
      },
      commit: { _, _ in }, reconcile: { nil })
    #expect(browser.watchedIDs.isEmpty)
  }

  @Test("Repeated actions on different rows are suppressed until reconciliation finishes")
  func duplicateActions() async {
    let browser = EpisodeBrowserModel(episodes: [item(1), item(2)], seasons: nil, isAnime: false)
    let gate = EpisodeBrowserTestGate()
    let first = Task {
      await browser.toggle(
        item(1), mutation: { _, _ in .succeeded }, commit: { _, _ in },
        reconcile: {
          await gate.wait()
          return nil
        })
    }
    while !gate.waiting { await Task.yield() }
    await browser.toggle(
      item(2),
      mutation: { _, _ in
        Issue.record("Overlapping write")
        return .succeeded
      },
      commit: { _, _ in }, reconcile: { nil })
    gate.open()
    await first.value
    #expect(browser.watchedIDs == [item(1).id])
    #expect(browser.updatingID == nil)
  }
}

@MainActor
private final class EpisodeBrowserTestGate {
  var waiting = false
  private var continuation: CheckedContinuation<Void, Never>?
  func wait() async {
    waiting = true
    await withCheckedContinuation { continuation = $0 }
  }
  func open() {
    continuation?.resume()
    continuation = nil
  }
}
