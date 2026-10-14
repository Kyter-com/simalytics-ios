import Foundation
import SwiftData

struct LibraryCounts: Sendable {
  var moviesDroppedCount: Int = 0
  var moviesPlanToWatchCount: Int = 0
  var moviesCompletedCount: Int = 0
  var showsPlanToWatchCount: Int = 0
  var showsCompletedCount: Int = 0
  var showsHoldCount: Int = 0
  var showsDroppedCount: Int = 0
  var showsWatchingCount: Int = 0
  var animePlanToWatchCount: Int = 0
  var animeDroppedCount: Int = 0
  var animeCompletedCount: Int = 0
  var animeHoldCount: Int = 0
  var animeWatchingCount: Int = 0

  @concurrent
  static func fetch(from container: ModelContainer) async throws -> Self {
    let context = ModelContext(container)
    func movies(_ status: String) throws -> Int {
      try context.fetchCount(
        FetchDescriptor<V1.SDMovies>(predicate: #Predicate { $0.status == status }))
    }
    func shows(_ status: String) throws -> Int {
      try context.fetchCount(
        FetchDescriptor<V1.SDShows>(predicate: #Predicate { $0.status == status }))
    }
    func anime(_ status: String) throws -> Int {
      try context.fetchCount(
        FetchDescriptor<V1.SDAnimes>(predicate: #Predicate { $0.status == status }))
    }
    return try Self(
      moviesDroppedCount: movies("dropped"),
      moviesPlanToWatchCount: movies("plantowatch"),
      moviesCompletedCount: movies("completed"),
      showsPlanToWatchCount: shows("plantowatch"),
      showsCompletedCount: shows("completed"),
      showsHoldCount: shows("hold"),
      showsDroppedCount: shows("dropped"),
      showsWatchingCount: shows("watching"),
      animePlanToWatchCount: anime("plantowatch"),
      animeDroppedCount: anime("dropped"),
      animeCompletedCount: anime("completed"),
      animeHoldCount: anime("hold"),
      animeWatchingCount: anime("watching")
    )
  }
}
