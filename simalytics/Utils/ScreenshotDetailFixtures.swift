//
//  ScreenshotDetailFixtures.swift
//  simalytics
//
//  DEBUG-only detail-view fixtures for the App Store screenshot pipeline
//  (marketing/app-store-screenshots). The detail views are network-driven —
//  MovieDetailView renders entirely from `getMovieDetails`, which offline returns
//  nil and lands on a "Movie unavailable" empty state. So, unlike the Lists /
//  Explore / Up Next tabs (which read the seeded SwiftData store), a rich detail
//  screenshot needs a hand-built response model injected in screenshot mode.
//
//  These factories are keyed to the same synthetic `simkl` ids that
//  ScreenshotSeedData uses, so the featured title matches the seeded watchlist row
//  (its poster + user rating flow through unchanged). The view-models short-circuit
//  to these when `ScreenshotMode.isActive` (see MovieDetailViewModel). Everything is
//  compiled out of Release.
//
//  Image hosts at capture time (all offline):
//    - poster `.../posters/<key>_m.jpg`      -> served from pd-posters/<key>.jpg
//    - fanart `.../fanart/<key>_mobile.jpg`  -> served from pd-posters/<key>.jpg
//      (PosterURLProtocol intercepts both). `ids.tmdb == nil` makes getCast return
//      [] with no network, so the copyrighted-photo cast row self-hides.

#if DEBUG
  import Foundation

  enum ScreenshotDetailFixtures {
    /// The movie the `movie-detail` screenshot opens. Matches a seeded `SDMovies`
    /// row (ScreenshotSeedData) and a `pd-posters/<poster>.jpg`. Change this one
    /// constant (and the matching fixture below) to feature a different title.
    static let featuredMovieID = 900_103  // His Girl Friday (1940)

    /// Rich detail model for the featured movie. Returns nil for anything else so
    /// the real network path is used for non-screenshot ids.
    static func movieDetails(_ simkl: Int) -> MovieDetailsModel? {
      guard simkl == featuredMovieID else { return nil }
      return MovieDetailsModel(
        title: "His Girl Friday",
        year: 1940,
        released: "1940-01-18",
        poster: "his-girl-friday-1940",  // /posters/ -> PD JPEG (exists)
        runtime: 92,
        fanart: "his-girl-friday-1940-fanart",  // /fanart/ -> cropped PD studio still
        rank: nil,
        certification: "Not Rated",
        language: "English",
        ratings: Ratings(simkl: Rating(rating: 7.9, votes: 4821), imdb: nil),
        overview:
          "Newspaper editor Walter Burns is about to lose his ace reporter — and "
          + "ex-wife — Hildy Johnson to a staid insurance man and a quiet life. To "
          + "keep her in the newsroom, Walter lures Hildy into covering one last "
          + "story: the imminent execution of a convicted killer, and the "
          + "fast-talking scramble that follows.",
        genres: ["Comedy", "Romance", "Drama"],
        trailers: nil,
        users_recommendations: recommendations,
        ids: MovieDetailsModelIds(tmdb: nil))  // nil -> getCast returns [] (no network, row hidden)
    }

    /// Non-nil so the featured title reads as "in your list": drives the status
    /// pill and unlocks the star RatingView + Add Memo button. The seeded SDMovies
    /// row supplies the actual star value via the view's local fetch.
    static func movieWatchlist(_ simkl: Int) -> MovieWatchlistModel? {
      guard simkl == featuredMovieID else { return nil }
      return MovieWatchlistModel(list: "completed", last_watched_at: nil, simkl: simkl)
    }

    /// A "Users Also Watched" shelf of vivid public-domain posters. Each id matches
    /// a seeded SDMovies row so the preview-card local lookup resolves; each poster
    /// key is a `/posters/`-served PD JPEG.
    private static let recommendations: [RecommendationModel] = [
      rec(900_106, "Meet John Doe", 1941, "meet-john-doe-1941"),
      rec(900_114, "Gulliver's Travels", 1939, "gulliver-s-travels-1939"),
      rec(900_108, "A Star Is Born", 1937, "a-star-is-born-1937"),
      rec(900_101, "The General", 1926, "the-general-1926"),
      rec(900_113, "D.O.A.", 1950, "d-o-a-1950"),
      rec(900_107, "My Man Godfrey", 1936, "my-man-godfrey-1936"),
    ]

    private static func rec(_ simkl: Int, _ title: String, _ year: Int, _ poster: String)
      -> RecommendationModel
    {
      RecommendationModel(
        title: title, year: year, poster: poster,
        ids: RecommendationModelIds(simkl: simkl, slug: poster), type: "movie")
    }
  }
#endif
