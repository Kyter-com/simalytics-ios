#if DEBUG
  import Foundation

  /// Offline, synthetic episode catalogs for layout and interaction validation.
  /// Artwork comes from the existing public-domain screenshot assets.
  enum ScreenshotEpisodeFixtures {
    static let showID = 990_201
    static let animeID = 990_401
    static var mutationResult: SimklMutationResult {
      ProcessInfo.processInfo.environment["SIMALYTICS_EPISODE_TEST_FAILURE"] == "1"
        ? .failed(userMessage: "Couldn't save this episode. Please try again.") : .succeeded
    }
    static let longDescription = Array(
      repeating:
        "The travelers follow a winding path through the mountains, meeting new companions and discovering a forgotten village. Each encounter changes their understanding of the journey ahead. The story continues across several scenes with a detailed account of their choices and the people they meet.",
      count: 12
    ).joined(separator: "\n\n")

    static var showDetails: ShowDetailsModel {
      ShowDetailsModel(
        title: "Adventure Serial", poster: "the-general-1926", fanart: nil, year: 1926,
        first_aired: nil, ratings: nil, year_start_end: "1926", runtime: 24, total_episodes: 36,
        overview: "A public-domain artwork collection with an offline episode catalog.",
        genres: ["Adventure"], users_recommendations: [], ids: nil)
    }

    static var animeDetails: AnimeDetailsModel {
      AnimeDetailsModel(
        title: "Animation Collection", fanart: nil, poster: "namakura-gatana-1917",
        genres: ["Animation"], overview: "An offline collection for browsing long episode lists.",
        first_aired: nil, year_start_end: "1917", users_recommendations: [],
        total_episodes: 202, ratings: nil, runtime: 12, anime_type: "tv", year: 1917,
        certification: nil, country: nil, ids: nil)
    }

    static var showEpisodes: [ShowEpisodeModel] {
      [1, 28, 29].flatMap { season in
        (1...12).map { number in
          ShowEpisodeModel(
            title: number == 2
              ? "The Journey Through the Mountains and the Unexpected Return of an Old Friend"
              : "Chapter \(number)",
            description: number.isMultiple(of: 2) ? longDescription : "A new journey begins.",
            season: season, episode: number, type: nil, date: "2020-01-01T12:00:00Z",
            img: number.isMultiple(of: 3) ? nil : "his-girl-friday-1940-fanart", aired: true,
            ids: ShowEpisodeModelIds(simkl_id: 990_000 + season * 100 + number))
        }
      }
    }

    static var animeEpisodes: [AnimeEpisodeModel] {
      ([1, 2] + Array(1100...1299)).map { number in
        AnimeEpisodeModel(
          title: number.isMultiple(of: 2)
            ? "A Very Long Journey with Friends Through a Changing World" : "Chapter \(number)",
          description: number.isMultiple(of: 2) ? longDescription : "A new journey begins.",
          episode: number, type: nil, aired: true, img: "his-girl-friday-1940-fanart",
          date: "2020-01-01T12:00:00Z", season: number / 100 + 1,
          ids: AnimeEpisodeModelIds(simkl_id: 990_000 + number))
      }
    }

    static func watchedSeason(_ season: Int, numbers: [Int]) -> [WatchlistSeason] {
      [
        WatchlistSeason(
          number: season, episodes_total: nil, episodes_aired: nil, episodes_to_be_aired: nil,
          episodes_watched: numbers.count,
          episodes: numbers.map {
            WatchlistEpisode(number: $0, watched: true, aired: true, last_watched_at: nil)
          })
      ]
    }
  }
#endif
