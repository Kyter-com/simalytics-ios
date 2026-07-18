import SwiftData
import Testing

@testable import Simalytics

@MainActor
@Suite("Local media snapshots")
struct LocalMediaSnapshotsTests {
  @Test("Bulk snapshot covers all media types and only requested IDs")
  func fetchesAllMediaTypes() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    context.insert(V1.SDMovies(simkl: 1, status: "completed", user_rating: 8, year: 2024))
    context.insert(
      V1.SDShows(
        simkl: 2,
        user_rating: 7,
        status: "watching",
        watched_episodes_count: 3,
        total_episodes_count: 10,
        year: 2025
      ))
    context.insert(
      V1.SDAnimes(
        simkl: 3,
        user_rating: 9,
        status: "watching",
        watched_episodes_count: 12,
        total_episodes_count: 24,
        anime_type: "tv",
        year: 2023
      ))
    context.insert(V1.SDMovies(simkl: 99, status: "plantowatch"))
    try context.save()

    let snapshots = LocalMediaSnapshots.fetch(
      .init(movieIDs: [1, 1], showIDs: [2], animeIDs: [3]),
      context: context
    )

    #expect(
      snapshots.data(simklID: 1, mediaType: "movie")
        == LocalMediaData(
          year: 2024,
          userRating: 8,
          status: "completed",
          animeType: nil,
          watchedEpisodes: nil,
          totalEpisodes: nil
        ))
    #expect(snapshots.data(simklID: 2, mediaType: "tv")?.watchedEpisodes == 3)
    #expect(snapshots.data(simklID: 3, mediaType: "anime")?.animeType == "tv")
    #expect(snapshots.data(simklID: 99, mediaType: "movie") == nil)
  }

  @Test("A new snapshot observes saved rating and watchlist changes")
  func refreshesAfterSavedChange() throws {
    let container = try makeContainer()
    let context = ModelContext(container)
    let show = V1.SDShows(simkl: 12, user_rating: 4, status: "plantowatch")
    context.insert(show)
    try context.save()

    let request = LocalMediaSnapshots.Request(showIDs: [12])
    let original = LocalMediaSnapshots.fetch(request, context: context)
    #expect(original.data(simklID: 12, mediaType: "tv")?.userRating == 4)

    show.user_rating = 10
    show.status = "completed"
    try context.save()

    let refreshed = LocalMediaSnapshots.fetch(request, context: context)
    #expect(refreshed.data(simklID: 12, mediaType: "tv")?.userRating == 10)
    #expect(refreshed.data(simklID: 12, mediaType: "tv")?.status == "completed")
  }

  private func makeContainer() throws -> ModelContainer {
    let schema = Schema(V1.models)
    return try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
  }
}
