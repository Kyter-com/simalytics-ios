import Foundation
import Observation
import SwiftData
import Testing

@testable import Simalytics

private func item(
  _ id: Int, _ type: DiscoverMediaType = .movies, rating: Double? = 8, votes: Int = 1_000,
  imdb: Double? = nil, rank: Int? = 100, watched: Int = 10, planToWatch: Int = 0,
  runtime: String? = nil, status: String? = "ended", genres: [String] = [],
  network: String? = nil, episodes: Int? = nil, animeType: String? = nil, year: Int = 2024,
  fanart: String? = "f/\(1)", dropRate: String? = nil, metadata: String? = nil,
  language: String? = nil, theater: String? = nil, home: String? = nil
) -> DiscoverItem {
  DiscoverItem(
    title: "Title \(id)", url: nil, poster: "p/\(id)", fanart: fanart,
    ids: .init(simkl_id: id, slug: "title-\(id)"), release_date: "01/02/\(year)", rank: rank,
    watched: watched, plan_to_watch: planToWatch,
    ratings: .init(
      simkl: .init(rating: rating, votes: votes), imdb: imdb.map { .init(rating: $0, votes: 9) },
      mal: nil),
    runtime: runtime, status: status, genres: genres, network: network,
    total_episodes: episodes, anime_type: animeType, drop_rate: dropRate, metadata: metadata,
    original_language: language, theater: theater, dvd_date: home, type: type)
}

/// Library entries for movies, keyed like `DiscoverItem.id`.
private func movieLibrary(
  _ ids: ClosedRange<Int>, status: String? = "completed", rating: Int? = nil
) -> [String: DiscoverLibrary.Entry] {
  let entry = DiscoverLibrary.Entry(status: status, rating: rating)
  return Dictionary(uniqueKeysWithValues: ids.map { ("movies-\($0)", entry) })
}

/// Noon on Oct 20, 2026, local time, so date windows don't straddle midnight.
private let october20 = Calendar.current.date(
  from: DateComponents(year: 2026, month: 10, day: 20, hour: 12))!

struct DiscoverItemTests {
  @Test("Trending files decode, skipping unused fields")
  func decodesTrendingItem() throws {
    let json = """
      [{"title":"Spider-Man","url":"/movies/1902343/spider-man","poster":"20/2042","fanart":"",
        "alt_titles":[{"name":"Homem-Aranha","lang":214,"type":"official"}],
        "ids":{"simkl_id":1902343,"slug":"spider-man","imdb":"tt22084616"},
        "release_date":"07/29/2026","rank":902,"drop_rate":"0.3%","watched":203,
        "plan_to_watch":8160,"ratings":{"simkl":{"rating":8.27,"votes":4331},
        "imdb":{"rating":7.9,"votes":357493}},"runtime":"2h 25m","status":"ended",
        "genres":["Action","Adventure"],"trailer":"P3uI5sLosKU"}]
      """
    let items = try JSONDecoder().decode(LossyArray<DiscoverItem>.self, from: Data(json.utf8))
      .elements
    let movie = try #require(items.first)
    #expect(movie.simklID == 1_902_343)
    #expect(movie.year == 2026)
    #expect(movie.simklRating == 8.27)
    #expect(movie.runtimeMinutes == 145)
    #expect(movie.fanartPath == nil)
    #expect(movie.webURL.absoluteString == "https://simkl.com/movies/1902343/spider-man")
  }

  @Test("One malformed title doesn't drop the rest of the file")
  func lossyArray() throws {
    let json = """
      [{"title":"Good","ids":{"simkl_id":1}},{"title":"No ids"},"junk",{"title":"Also good","ids":{"simkl_id":2}}]
      """
    let items = try JSONDecoder().decode(LossyArray<DiscoverItem>.self, from: Data(json.utf8))
      .elements
    #expect(items.map(\.simklID) == [1, 2])
  }

  @Test(
    "Runtime strings parse to minutes",
    arguments: [
      ("2h 25m", 145), ("45m", 45), ("1h", 60), ("2h25m", 145), ("", nil), ("about 2h", nil),
    ] as [(String, Int?)])
  func runtime(raw: String, minutes: Int?) {
    #expect(item(1, runtime: raw).runtimeMinutes == minutes)
  }

  @Test("Release years come from either date order")
  func releaseYear() {
    #expect(DiscoverItem.year(fromReleaseDate: "07/29/2026") == 2026)
    #expect(DiscoverItem.year(fromReleaseDate: "1983-11-21T00:00:00-05:00") == 1983)
    #expect(DiscoverItem.year(fromReleaseDate: "soon") == nil)
  }

  @Test("Drop rates, box office, and release dates parse from Simkl's strings")
  func derivedFields() {
    let movie = item(
      1, dropRate: "0.3%", metadata: "July 29, 2026 • Budget $225M • Box office $2,516M",
      theater: "10/03/2026", home: "2026-10-13")
    #expect(movie.dropRate == 0.3)
    #expect(movie.boxOffice == 2_516_000_000)
    #expect(item(2, metadata: "March 1, 2026 • Box office $1.2B").boxOffice == 1_200_000_000)
    #expect(item(3, metadata: "March 1, 2026 • Budget $20M").boxOffice == nil)
    let calendar = Calendar.current
    #expect(movie.theaterDate.map { calendar.component(.day, from: $0) } == 3)
    #expect(movie.homeReleaseDate.map { calendar.component(.month, from: $0) } == 10)
    #expect(DiscoverItem.date(fromSimkl: "soon") == nil)
  }

  @Test("Synopses and trailers decode; blank synopses and junk trailer ids are dropped")
  func synopsisAndTrailer() throws {
    let json = """
      [{"title":"A","ids":{"simkl_id":1},"overview":"  A mystery.\\n","trailer":"P3uI5sLosKU"},
       {"title":"B","ids":{"simkl_id":2},"overview":"","trailer":"not a video"}]
      """
    let items = try JSONDecoder().decode(LossyArray<DiscoverItem>.self, from: Data(json.utf8))
      .elements
    #expect(items[0].summary == "A mystery.")
    #expect(items[0].trailerURL?.absoluteString == "https://www.youtube.com/watch?v=P3uI5sLosKU")
    #expect(items[1].summary == nil)
    #expect(items[1].trailerURL == nil)
  }

  @Test("Adult-tagged titles are flagged; zero scores read as unrated")
  func adultAndUnrated() {
    #expect(item(1, genres: ["Hentai"]).isAdult)
    #expect(item(2, genres: ["Erotica", "Horror"]).isAdult)
    #expect(!item(3, genres: ["Horror"]).isAdult)
    #expect(item(4, rating: 0).simklRating == nil)
  }
}

struct DiscoverRecipeTests {
  @Test("Top rated needs enough votes and keeps file order on ties")
  func topRated() {
    let items = [
      item(1, rating: 9.5, votes: 20), item(2, rating: 8), item(3, rating: 9), item(4, rating: 8),
    ]
    #expect(DiscoverRecipes.topRated(items).map(\.simklID) == [3, 2, 4])
  }

  @Test("Hidden gems skip Simkl's top 2,000 and low scores")
  func hiddenGems() {
    let items = [
      item(1, rating: 8.5, rank: 150), item(2, rating: 8.1, rank: 4_000),
      item(3, rating: 7.0, rank: 5_000), item(4, rating: 7.9, rank: nil),
    ]
    #expect(DiscoverRecipes.hiddenGems(items).map(\.simklID) == [2])
  }

  @Test("Quick watches are movies of 90 minutes or less")
  func quickWatches() {
    let items = [
      item(1, runtime: "1h 25m"), item(2, runtime: "2h"), item(3, .shows, runtime: "30m"),
      item(4, runtime: nil),
    ]
    #expect(DiscoverRecipes.quickWatches(items).map(\.simklID) == [1])
  }

  @Test("Marathon-worthy series are finished, 20–100 episodes, and rated 8+")
  func marathonWorthy() {
    let items = [
      item(1, .shows, rating: 8.6, watched: 5, episodes: 62),
      item(2, .shows, status: "ongoing", episodes: 40),
      item(3, .anime, rating: 9.1, watched: 50, episodes: 24),
      item(4, .shows, rating: 7.5, episodes: 50), item(5, .shows, rating: 9, episodes: 500),
      item(6, .movies, rating: 9, episodes: 30),
    ]
    #expect(DiscoverRecipes.marathonWorthy(items).map(\.simklID) == [3, 1])
  }

  @Test("Networks match Simkl's alternate spellings")
  func networks() {
    let items = [
      item(1, .shows, rating: 8, network: "HBO"), item(2, .shows, rating: 9, network: "HBO Max"),
      item(3, .shows, rating: 6.5, network: "HBO"), item(4, .shows, rating: 9, network: "Netflix"),
    ]
    #expect(DiscoverRecipes.network(items, "HBO").map(\.simklID) == [2, 1])
  }

  @Test("Decades bound the year and need votes")
  func decades() {
    let items = [
      item(1, rating: 8, year: 1994), item(2, rating: 9, year: 2001), item(3, votes: 5, year: 1999),
      item(4, rating: 9, year: 1990),
    ]
    #expect(DiscoverRecipes.decade(items, 1990).map(\.simklID) == [4, 1])
  }

  @Test("Loved Everywhere needs 8+ on Simkl and outside, most watched first")
  func lovedEverywhere() {
    let items = [
      item(1, rating: 9, imdb: 7.5), item(2, rating: 8.2, imdb: 8.4, watched: 5),
      item(3, rating: 8.9, imdb: 8.1, watched: 50), item(4, rating: 7.9, imdb: 9),
    ]
    #expect(DiscoverRecipes.lovedEverywhere(items).map(\.simklID) == [3, 2])
  }

  @Test("In Theaters skips titles already home; New at Home is recent home releases")
  func theatersAndHome() {
    let items = [
      item(1, theater: "10/03/2026"), item(2, theater: "10/01/2026", home: "10/13/2026"),
      item(3, theater: "06/01/2026", home: "09/30/2026"), item(4, theater: "11/20/2026"),
      item(5, .shows, theater: "10/03/2026"), item(6, home: "10/25/2026"),
    ]
    #expect(DiscoverRecipes.inTheaters(items, now: october20).map(\.simklID) == [1])
    #expect(DiscoverRecipes.newAtHome(items, now: october20).map(\.simklID) == [2, 3])
  }

  @Test("Weekend binges are short finished series; epics run 2½ hours")
  func bingesAndEpics() {
    let items = [
      item(1, .shows, rating: 8, episodes: 8), item(2, .shows, rating: 8, episodes: 12),
      item(3, .shows, rating: 7, episodes: 6), item(4, .anime, rating: 9, watched: 90, episodes: 1),
      item(5, runtime: "2h 45m"), item(6, rating: 6.5, runtime: "3h"), item(7, runtime: "2h 29m"),
    ]
    #expect(DiscoverRecipes.weekendBinge(items).map(\.simklID) == [4, 1])
    #expect(DiscoverRecipes.epicMovies(items).map(\.simklID) == [5])
  }

  @Test("Box office ranks by gross; world hits skip English and anime")
  func boxOfficeAndWorld() {
    let items = [
      item(1, metadata: "Box office $361M"), item(2, metadata: "Box office $2,923M"),
      item(3, .shows, watched: 5, language: "ko"), item(4, watched: 50, language: "es"),
      item(5, language: "en"), item(6, .anime, language: "ja"),
      item(7, metadata: "May 1, 2026 • Box office $7"),
    ]
    #expect(DiscoverRecipes.boxOffice(items).map(\.simklID) == [2, 1])
    #expect(DiscoverRecipes.worldHits(items).map(\.simklID) == [4, 3])
  }

  @Test("Hard to Quit ranks drop rates within each type, then interleaves")
  func hardToQuit() {
    let items = [
      item(1, dropRate: "0.9%"), item(2, dropRate: "0.1%"), item(3, .shows, dropRate: "3.0%"),
      item(4, .shows, dropRate: "1.2%"), item(5, dropRate: "0.2%"),
      item(6, votes: 20, dropRate: "0.0%"),
    ]
    #expect(DiscoverRecipes.hardToQuit(items).map(\.simklID) == [4, 2, 3, 5, 1])
  }

  @Test("Genre spotlights match spellings across types")
  func genreSpotlight() {
    let items = [
      item(1, watched: 5, genres: ["Science Fiction"]),
      item(2, .shows, watched: 9, genres: ["Science-Fiction"]),
      item(3, .anime, watched: 1, genres: ["Sci-Fi"]), item(4, genres: ["Drama"]),
    ]
    #expect(DiscoverRecipes.genre(items, key: "sciencefiction").map(\.simklID) == [2, 1, 3])
  }

  @Test("Mixed rows alternate types and drop repeats")
  func interleaveAndUnique() {
    let movies = [item(1), item(2), item(3)]
    let shows = [item(1, .shows)]
    #expect(
      DiscoverRecipes.interleaved([movies, shows]).map(\.id)
        == ["movies-1", "tv-1", "movies-2", "movies-3"])
    #expect(DiscoverRecipes.unique(movies + [item(2)]).map(\.simklID) == [1, 2, 3])
  }

  @Test("Sort menus name each list's own order and never offer Top Rated twice")
  func sortMenus() {
    let list = { (kind: DiscoverListKind) in DiscoverList(kind: kind, types: [.movies], items: []) }
    for kind in [DiscoverListKind.topRated, .hiddenGems, .decade(1990), .network("Netflix")] {
      #expect(list(kind).featuredSort == nil)
    }
    #expect(list(.boxOffice).featuredSort == "Box Office")
    #expect(list(.weekendBinge).featuredSort == "Most Watched")
    #expect(DiscoverSort.options(featured: nil) == [.rating, .newest, .title])
    #expect(DiscoverSort.options(featured: "Most Watched") == DiscoverSort.allCases)
  }
}

struct DiscoverGenreTests {
  @Test("Adult, ecchi, and tiny genres stay out; sci-fi spellings merge")
  func groups() {
    let index: [DiscoverMediaType: [DiscoverGenre]] = [
      .movies: [
        .init(name: "Science Fiction", slug: "science-fiction", count: 500),
        .init(name: "Erotica", slug: "erotica", count: 172),
        .init(name: "Western", slug: "western", count: 213),
      ],
      .shows: [
        .init(name: "Science-Fiction", slug: "science-fiction", count: 500),
        .init(name: "Video Game Play", slug: "video-game-play", count: 1),
      ],
      .anime: [
        .init(name: "Sci-Fi", slug: "sci-fi", count: 500),
        .init(name: "Hentai", slug: "hentai", count: 74),
        .init(name: "Ecchi", slug: "ecchi", count: 352),
        .init(name: "Action", slug: "action", count: 500),
      ],
    ]
    let groups = DiscoverGenreGroup.groups(from: index, types: DiscoverMediaType.allCases)
    #expect(groups.map(\.name) == ["Action", "Science Fiction", "Western"])
    let sciFi = groups[1]
    #expect(sciFi.types == [.shows, .movies, .anime])
    #expect(sciFi.genres[.anime]?.slug == "sci-fi")
    #expect(
      DiscoverGenreGroup.groups(from: index, types: [.shows]).map(\.name) == ["Science-Fiction"])
  }

  @Test("TV and anime spellings of Sports and History share one tile")
  func spellingFolds() {
    #expect(DiscoverGenre.key(for: "Sport") == DiscoverGenre.key(for: "Sports"))
    #expect(DiscoverGenre.key(for: "Historical") == DiscoverGenre.key(for: "History"))
    #expect(DiscoverGenre.key(for: "Slice Of Life") == "sliceoflife")
  }
}

struct ExploreSnapshotTests {
  private let pools: [DiscoverMediaType: [DiscoverItem]] = [
    .movies: (1...12).map { item($0, rating: 7 + Double($0) / 10, runtime: "1h 20m") },
    .shows: (101...112).map {
      item($0, .shows, rating: 8.5, rank: 3_000, network: "Netflix", episodes: 30)
    },
    .anime: (201...205).map { item($0, .anime, animeType: "movie") }
      + [item(206, .anime, genres: ["Hentai"])],
  ]

  private var trending: [DiscoverMediaType: [DiscoverItem]] {
    [
      .movies: [item(1, fanart: nil), item(2), item(3), item(4)],
      .shows: [item(101, .shows, genres: ["Erotica"]), item(102, .shows), item(103, .shows)],
      .anime: [item(201, .anime)],
    ]
  }

  @Test("The page leads with the hero, genres, and streaming, then today's top 10s")
  func sectionOrder() {
    let index: [DiscoverMediaType: [DiscoverGenre]] = [
      .movies: [.init(name: "Action", slug: "action", count: 500)]
    ]
    let snapshot = ExploreSnapshot(
      trending: trending, pools: pools, genreIndex: index, types: [.shows, .movies],
      now: october20)
    #expect(
      snapshot.sections.prefix(6).map(\.id)
        == ["hero", "genres", "streaming", "trending-tv", "trending-movies", "collections"])
    // Movies trade Just Released for theater and home rows.
    let premieres: [DiscoverMediaType: [DiscoverItem]] = [
      .movies: (301...306).map { item($0, status: "premiere") }
    ]
    let mixed = ExploreSnapshot(
      trending: [:], pools: premieres, genreIndex: [:], types: [.shows, .movies], now: october20)
    #expect(mixed.sections.contains { $0.id.hasPrefix("justReleased") })
    let movies = ExploreSnapshot(
      trending: [:], pools: premieres, genreIndex: [:], types: [.movies], now: october20)
    #expect(!movies.sections.contains { $0.id.hasPrefix("justReleased") })
  }

  @Test("Adult titles never reach a row; short lists are left out")
  func filtering() {
    let snapshot = ExploreSnapshot(
      trending: trending, pools: pools, genreIndex: [:], types: DiscoverMediaType.allCases)
    let everything =
      snapshot.hero + snapshot.trending.flatMap(\.items)
      + snapshot.collections.flatMap(\.items)
    #expect(!everything.contains { $0.isAdult })
    // Five clean anime movies fall short of a shelf.
    #expect(!snapshot.collections.contains { $0.kind == .animeMovies })
    #expect(snapshot.streaming.map(\.title) == ["Netflix"])
    #expect(snapshot.networks.isEmpty)
  }

  @Test("The hero leads with movies, prefers backdrops, and knows today's ranks")
  func hero() {
    let snapshot = ExploreSnapshot(
      trending: trending, pools: [:], genreIndex: [:], types: [.shows, .movies])
    #expect(snapshot.hero.map(\.id) == ["movies-2", "tv-102", "movies-3", "tv-103", "movies-4"])
    #expect(snapshot.ranks["movies-2"] == 2)
    #expect(snapshot.ranks["tv-102"] == 1)
    #expect(snapshot.trending.map(\.type) == [.shows, .movies])
  }

  @Test("Hiding anime removes its filter and rows")
  func hideAnime() {
    #expect(ExploreFilter.anime.types(hideAnime: true).isEmpty)
    #expect(ExploreFilter.all.types(hideAnime: true) == [.shows, .movies])
  }

  @Test("Hiding the library drops listed titles everywhere, and charts keep true ranks")
  func hidingLibrary() {
    let library: [String: DiscoverLibrary.Entry] = [
      "movies-1": .init(status: "completed", rating: nil),
      "tv-102": .init(status: "watching", rating: nil),
      // Rated but on no list, so it isn't hidden.
      "movies-5": .init(status: nil, rating: 8),
    ]
    let snapshot = ExploreSnapshot(
      trending: trending, pools: pools, genreIndex: [:], types: [.shows, .movies],
      library: library, hidesLibrary: true)
    let shown =
      snapshot.hero + snapshot.trending.flatMap(\.items) + snapshot.collections.flatMap(\.items)
      + snapshot.streaming.flatMap(\.items)
    #expect(!shown.contains { $0.id == "movies-1" || $0.id == "tv-102" })
    #expect(shown.contains { $0.id == "movies-5" })
    // The next titles keep their places in today's charts.
    #expect(snapshot.trending.first { $0.type == .movies }?.items.first?.id == "movies-2")
    #expect(snapshot.ranks["movies-2"] == 2)
    #expect(snapshot.ranks["tv-103"] == 2)

    let unhidden = ExploreSnapshot(
      trending: trending, pools: pools, genreIndex: [:], types: [.shows, .movies],
      library: library)
    #expect(unhidden.trending.first { $0.type == .movies }?.items.first?.id == "movies-1")
  }

  @Test("For You comes right after the hero")
  func forYouPlacement() throws {
    let horror = (1...12).map { item($0, genres: ["Horror"]) }
    let comedy = (21...24).map { item($0, genres: ["Comedy"]) }
    let library = movieLibrary(1...5, rating: 9).merging(movieLibrary(21...23, rating: 5)) { $1 }
    let snapshot = ExploreSnapshot(
      trending: [.movies: Array(horror.prefix(4))], pools: [.movies: horror + comedy],
      genreIndex: [:], types: [.movies], library: library)
    let forYou = try #require(snapshot.forYou)
    #expect(snapshot.sections.prefix(2).map(\.id) == ["hero", forYou.id])
    #expect(forYou.items.map(\.simklID) == Array(6...12))
  }
}

struct ForYouTests {
  @Test("For You picks unwatched titles in the genres rated highest")
  func picksFromRatings() throws {
    let rated =
      (1...4).map { item($0, genres: ["Horror"]) } + (11...14).map { item($0, genres: ["Comedy"]) }
    let library = movieLibrary(1...4, rating: 9).merging(movieLibrary(11...14, rating: 5)) { $1 }
    let candidates =
      (5...10).map { item($0, genres: ["Horror"]) } + (15...20).map { item($0, genres: ["Comedy"]) }
      + [item(31, genres: ["Horror", "Comedy"])]
    let taste = try #require(DiscoverTaste(library: library, catalog: rated + candidates))
    #expect(taste.favorites == ["Horror"])
    #expect(taste.fromRatings)
    // Library titles never return, and the love-hate mix nets out to neutral.
    let picks = DiscoverRecipes.forYou(rated + candidates, taste: taste, library: library)
    #expect(picks.map(\.simklID) == Array(5...10))
  }

  @Test("Short on ratings, watch history speaks; too little hides the row")
  func fallbacks() throws {
    let watched = (1...6).map { item($0, genres: ["Horror"]) }
    let library = movieLibrary(1...6)
    let taste = try #require(DiscoverTaste(library: library, catalog: watched))
    #expect(!taste.fromRatings)
    let list = DiscoverList(
      kind: .forYou(favorites: taste.favorites, fromRatings: taste.fromRatings), types: [.movies],
      items: [])
    #expect(list.shelfTitle == "Movies for You")
    #expect(list.subtitle == "Because you watch a lot of Horror")

    #expect(DiscoverTaste(library: movieLibrary(1...4), catalog: watched) == nil)
  }
}

@MainActor
struct DiscoverLibraryTests {
  private func session() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [QuickChangeProtocol.self]
    return URLSession(configuration: configuration)
  }

  @Test("Reads every title's list and rating from SwiftData")
  func readsLibrary() throws {
    let container = try ModelContainer(
      for: Schema(V1.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = ModelContext(container)
    context.insert(V1.SDMovies(simkl: 1, status: "completed", user_rating: 9))
    context.insert(V1.SDShows(simkl: 2, status: "watching"))
    context.insert(V1.SDAnimes(simkl: 3, user_rating: 7))
    try context.save()
    let entries = try #require(DiscoverLibrary.fetchEntries(in: container))
    #expect(entries["movies-1"] == .init(status: "completed", rating: 9))
    #expect(entries["tv-2"] == .init(status: "watching", rating: nil))
    #expect(entries["anime-3"] == .init(status: nil, rating: 7))
  }

  @Test("Plan to Watch is added only once Simkl says the title is on no list")
  func addsWhenUnlisted() async {
    let library = DiscoverLibrary()
    let token = "quick:\(UUID()):none"
    let movie = item(42)
    #expect(await library.addToPlanToWatch(movie, accessToken: token, session: session()) == .added)
    #expect(
      QuickChangeProtocol.calls(for: token) == ["/sync/watched", "/sync/add-to-list plantowatch"])
    // Shown at once, then the synced library takes over.
    #expect(library.status(of: movie) == "plantowatch")
    library.apply([movie.id: .init(status: "plantowatch", rating: nil)])
    #expect(library.pending.isEmpty)
    #expect(library.status(of: movie) == "plantowatch")
  }

  @Test("A title already on a list is never moved")
  func leavesListedTitles() async {
    let library = DiscoverLibrary()
    let token = "quick:\(UUID()):completed"
    #expect(
      await library.addToPlanToWatch(item(42), accessToken: token, session: session())
        == .alreadyListed("completed"))
    #expect(QuickChangeProtocol.calls(for: token) == ["/sync/watched"])
    #expect(library.status(of: item(42)) == nil)
  }

  @Test("Removal only clears titles still on Plan to Watch")
  func removesOnlyPlanToWatch() async {
    let library = DiscoverLibrary()
    let watching = "quick:\(UUID()):watching"
    #expect(
      await library.removeFromPlanToWatch(item(42), accessToken: watching, session: session())
        == .alreadyListed("watching"))
    #expect(QuickChangeProtocol.calls(for: watching) == ["/sync/watched"])

    let planned = "quick:\(UUID()):plantowatch"
    #expect(
      await library.removeFromPlanToWatch(item(42), accessToken: planned, session: session())
        == .removed)
    #expect(QuickChangeProtocol.calls(for: planned) == ["/sync/watched", "/sync/history/remove"])
    #expect(library.status(of: item(42)) == nil)
  }

  @Test("Offline, nothing changes")
  func offline() async {
    let library = DiscoverLibrary()
    let outcome = await library.addToPlanToWatch(
      item(42), accessToken: "quick:\(UUID()):offline", session: session())
    guard case .failed = outcome else {
      Issue.record("An unreachable Simkl must not count as added")
      return
    }
    #expect(library.status(of: item(42)) == nil)
    #expect(library.updating.isEmpty)
  }
}

@MainActor
struct DiscoverStoreTests {
  private func makeStore(
    _ id: String, mode: String = "ok", directory: URL? = nil,
    now: @escaping @Sendable () -> Date = { Date() },
    reporter: @escaping @Sendable (Error) -> Void = { _ in }
  ) -> (DiscoverStore, URL) {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [DiscoverFixtureProtocol.self]
    configuration.httpAdditionalHeaders = ["X-Test-ID": id, "X-Test-Mode": mode]
    let directory =
      directory ?? FileManager.default.temporaryDirectory.appending(path: "Discover-\(UUID())")
    return (
      DiscoverStore(
        cache: DiscoverDiskCache(directory: directory),
        session: URLSession(configuration: configuration), now: now, reporter: reporter),
      directory
    )
  }

  @Test("Loads the CDN files once and serves the copy while it's fresh")
  func loadsOnce() async {
    let id = UUID().uuidString
    let (store, directory) = makeStore(id)
    defer { try? FileManager.default.removeItem(at: directory) }
    await store.load(hideAnime: false)
    #expect(store.phase == .loaded)
    #expect(store.trending[.shows]?.first?.type == .shows)
    #expect(store.pools[.anime]?.first?.type == .anime)
    #expect(store.genreIndex[.movies]?.first?.slug == "horror")
    let paths = DiscoverFixtureProtocol.paths(for: id)
    #expect(paths.count == 7)
    #expect(paths.allSatisfy { $0.contains("client_id=") && $0.contains("app-name=") })
    await store.load(hideAnime: false)
    #expect(DiscoverFixtureProtocol.paths(for: id).count == 7)
  }

  @Test("Search's today-only load skips the 30-day files")
  func todayOnly() async {
    let id = UUID().uuidString
    let (store, directory) = makeStore(id)
    defer { try? FileManager.default.removeItem(at: directory) }
    await store.load(hideAnime: true, todayOnly: true)
    #expect(DiscoverFixtureProtocol.paths(for: id).count == 1)
    await store.load(hideAnime: true)
    // Anime pools and genres stay unfetched while anime is hidden.
    #expect(DiscoverFixtureProtocol.paths(for: id).count == 5)
  }

  @Test("A relaunch paints from disk even when offline")
  func restoresFromDisk() async {
    let (first, directory) = makeStore(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    await first.load(hideAnime: false)
    // Every file's write must land, not just the last one started.
    await waitForCache(in: directory)
    let (second, _) = makeStore(UUID().uuidString, mode: "offline", directory: directory)
    await second.load(hideAnime: false)
    #expect(second.phase == .loaded)
    #expect(second.trending[.movies]?.map(\.simklID) == first.trending[.movies]?.map(\.simklID))
    #expect(second.trending[.movies]?.first?.type == .movies)
  }

  @Test("Stale files refresh; a failed refresh keeps what's on screen")
  func staleness() async {
    let id = UUID().uuidString
    let clock = TestClock()
    let (store, directory) = makeStore(id, now: { clock.now })
    defer { try? FileManager.default.removeItem(at: directory) }
    await store.load(hideAnime: false)
    clock.advance(by: 2 * 60 * 60)
    await store.load(hideAnime: false)
    // Only the hourly today file was due.
    #expect(DiscoverFixtureProtocol.paths(for: id).count == 8)
    #expect(DiscoverFixtureProtocol.paths(for: id).last?.contains("today_100") == true)
  }

  @Test("Snapshots build off the main actor, are cached, and follow each refresh")
  func snapshotsFollowRefreshes() async {
    let (store, directory) = makeStore(UUID().uuidString, mode: "changing")
    defer { try? FileManager.default.removeItem(at: directory) }
    await store.load(hideAnime: false)
    let key = store.snapshotKey(for: .all, hideAnime: false)
    #expect(store.cachedSnapshot(for: key) == nil)
    let first = await store.snapshot(for: key)
    #expect(store.cachedSnapshot(for: key) != nil)

    // Explore's body reads the key, so a refresh must redraw it.
    let refreshed = TestFlag()
    withObservationTracking {
      _ = store.snapshotKey(for: .all, hideAnime: false)
    } onChange: {
      refreshed.set()
    }
    await store.load(hideAnime: false, force: true)
    #expect(refreshed.isSet)
    let next = store.snapshotKey(for: .all, hideAnime: false)
    #expect(next != key)
    #expect(store.cachedSnapshot(for: key) == nil)
    let second = await store.snapshot(for: next)
    let movies = { (snapshot: ExploreSnapshot) in
      snapshot.trending.first { $0.type == .movies }?.items.map(\.id)
    }
    #expect(movies(second) != movies(first))
  }

  @Test("A library change keeps only the new library's snapshots")
  func snapshotsFollowTheLibrary() async {
    let (store, directory) = makeStore(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    await store.load(hideAnime: false)
    let before = store.snapshotKey(for: .all, hideAnime: false)
    _ = await store.snapshot(for: before)
    let library = DiscoverLibrary.Contents(
      entries: ["movies-1": .init(status: "completed", rating: nil)], revision: 1)
    let after = store.snapshotKey(
      for: .all, hideAnime: false, library: library, hidesLibrary: true)
    let hidden = await store.snapshot(for: after, library: library)
    #expect(store.cachedSnapshot(for: before) == nil)
    #expect(store.cachedSnapshot(for: after) != nil)
    #expect(!hidden.trending.flatMap(\.items).contains { $0.id == "movies-1" })
  }

  @Test("An unchanged file costs a 304, and is rechecked after 5, 15, then 30 minutes")
  func notModified() async {
    let id = UUID().uuidString
    let clock = TestClock()
    let (store, directory) = makeStore(id, mode: "conditional", now: { clock.now })
    defer { try? FileManager.default.removeItem(at: directory) }
    await store.load(hideAnime: false)
    #expect(DiscoverFixtureProtocol.conditionalPaths(for: id).isEmpty)
    let titles = store.trending[.movies]?.map(\.simklID)

    clock.advance(by: 2 * 60 * 60)
    await store.load(hideAnime: false)
    // Only the hourly file was due, and it was asked about rather than downloaded.
    #expect(
      DiscoverFixtureProtocol.conditionalPaths(for: id) == ["/discover/trending/today_100.json"])
    #expect(store.trending[.movies]?.map(\.simklID) == titles)
    #expect(store.phase == .loaded)

    // (minutes waited, conditional requests so far)
    for (minutes, asked) in [(4, 1), (2, 2), (14, 2), (2, 3), (29, 3), (2, 4), (31, 5)] {
      clock.advance(by: TimeInterval(minutes) * 60)
      await store.load(hideAnime: false)
      #expect(DiscoverFixtureProtocol.conditionalPaths(for: id).count == asked)
    }
  }

  @Test("After a relaunch, a due file is asked about with its saved Last-Modified")
  func conditionalAfterRelaunch() async {
    let clock = TestClock()
    let (first, directory) = makeStore(UUID().uuidString, mode: "conditional", now: { clock.now })
    defer { try? FileManager.default.removeItem(at: directory) }
    await first.load(hideAnime: false)
    await waitForCache(in: directory)

    clock.advance(by: 2 * 60 * 60)
    let id = UUID().uuidString
    let (second, _) = makeStore(id, mode: "conditional", directory: directory, now: { clock.now })
    await second.load(hideAnime: false)
    #expect(DiscoverFixtureProtocol.paths(for: id).count == 1)
    #expect(
      DiscoverFixtureProtocol.conditionalPaths(for: id) == ["/discover/trending/today_100.json"])
    #expect(second.trending[.movies]?.map(\.simklID) == first.trending[.movies]?.map(\.simklID))
  }

  /// Cache writes happen in the background.
  private func waitForCache(in directory: URL) async {
    let sources: [DiscoverSource] =
      [.today] + DiscoverMediaType.allCases.flatMap { [.pool($0), .genreIndex($0)] }
    for _ in 0..<100
    where !sources.allSatisfy({
      FileManager.default.fileExists(atPath: directory.appending(path: $0.cacheName).path)
    }) {
      try? await Task.sleep(for: .milliseconds(20))
    }
  }

  @Test("Offline with nothing cached shows the failure state, and isn't reported")
  func failure() async {
    let reports = TestReports()
    let (store, directory) = makeStore(
      UUID().uuidString, mode: "offline", reporter: { reports.record($0) })
    defer { try? FileManager.default.removeItem(at: directory) }
    await store.load(hideAnime: false)
    #expect(store.phase == .failed)
    #expect(!store.hasContent)
    #expect(reports.paths.isEmpty)
  }

  @Test("A broken file reaches Sentry with its path, once a session")
  func reportsBrokenFiles() async {
    let reports = TestReports()
    let (store, directory) = makeStore(
      UUID().uuidString, mode: "broken", reporter: { reports.record($0) })
    defer { try? FileManager.default.removeItem(at: directory) }
    await store.load(hideAnime: false)
    await store.load(hideAnime: false)
    #expect(store.phase == .failed)
    let sources: [DiscoverSource] =
      [.today] + DiscoverMediaType.allCases.flatMap { [.pool($0), .genreIndex($0)] }
    #expect(reports.paths.sorted() == sources.map(\.path).sorted())

    let horror = DiscoverGenre(name: "Horror", slug: "horror", count: 500)
    for _ in 0..<2 { _ = try? await store.items(in: horror, type: .movies) }
    #expect(reports.paths.filter { $0.hasSuffix("horror_month_500.json") }.count == 1)
  }

  @Test("Genre pages load on open, drop adult titles, and are cached")
  func genreItems() async throws {
    let id = UUID().uuidString
    let (store, directory) = makeStore(id)
    defer { try? FileManager.default.removeItem(at: directory) }
    let horror = DiscoverGenre(name: "Horror", slug: "horror", count: 500)
    let items = try await store.items(in: horror, type: .movies)
    #expect(items.map(\.simklID) == [11])
    _ = try await store.items(in: horror, type: .movies)
    #expect(DiscoverFixtureProtocol.paths(for: id) == [DiscoverFixtureProtocol.paths(for: id)[0]])
    #expect(DiscoverFixtureProtocol.paths(for: id)[0].contains("movies/genre/horror_month_500.json"))
  }
}

private final class TestClock: @unchecked Sendable {
  private let lock = NSLock()
  private var date = Date(timeIntervalSince1970: 1_800_000_000)

  var now: Date { lock.withLock { date } }
  func advance(by interval: TimeInterval) { lock.withLock { date += interval } }
}

private final class TestFlag: @unchecked Sendable {
  private let lock = NSLock()
  private var value = false

  var isSet: Bool { lock.withLock { value } }
  func set() { lock.withLock { value = true } }
}

/// Collects what the store would send to Sentry.
private final class TestReports: @unchecked Sendable {
  private let lock = NSLock()
  private var errors: [Error] = []

  var paths: [String] { lock.withLock { errors.compactMap { ($0 as? DiscoverFileError)?.path } } }
  func record(_ error: Error) { lock.withLock { errors.append(error) } }
}

/// Serves small discover files and records each test's requests by its header id.
/// "conditional" mode stamps files with a `Last-Modified` and answers 304 when
/// asked about that same version; "broken" serves JSON in the wrong shape.
private final class DiscoverFixtureProtocol: URLProtocol, @unchecked Sendable {
  nonisolated(unsafe) private static var requests: [String: [String]] = [:]
  nonisolated(unsafe) private static var conditional: [String: [String]] = [:]
  private static let lock = NSLock()
  static let lastModified = "Wed, 21 Oct 2026 15:32:02 GMT"

  static func paths(for id: String) -> [String] { lock.withLock { requests[id] ?? [] } }
  /// Paths requested with `If-Modified-Since`.
  static func conditionalPaths(for id: String) -> [String] {
    lock.withLock { conditional[id] ?? [] }
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    let url = request.url!
    let id = request.value(forHTTPHeaderField: "X-Test-ID") ?? ""
    let mode = request.value(forHTTPHeaderField: "X-Test-Mode")
    let validator = request.value(forHTTPHeaderField: "If-Modified-Since")
    Self.lock.withLock {
      Self.requests[id, default: []].append(url.absoluteString)
      if validator != nil { Self.conditional[id, default: []].append(url.path) }
    }
    if mode == "offline" {
      client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
      return
    }
    if mode == "conditional", validator == Self.lastModified {
      let response = HTTPURLResponse(
        url: url, statusCode: 304, httpVersion: nil,
        headerFields: ["Last-Modified": Self.lastModified])!
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocolDidFinishLoading(self)
      return
    }
    let path = url.path
    let body: String
    if mode == "broken" {
      body = "{}"
    } else if path.hasSuffix("trending/today_100.json") {
      // "changing" adds a new title on every request, so a refresh has news.
      let extra =
        request.value(forHTTPHeaderField: "X-Test-Mode") == "changing"
        ? ",\(Self.item(100 + Self.paths(for: id).count))" : ""
      body = """
        {"movies":[\(Self.item(1)),\(Self.item(2))\(extra)],"tv":[\(Self.item(3))],"anime":[\(Self.item(4))]}
        """
    } else if path.hasSuffix("genre/index.json") {
      body = #"[{"name":"Horror","slug":"horror","count":500}]"#
    } else if path.contains("/genre/") {
      body = "[\(Self.item(11)),\(Self.item(12, genres: #"["Erotica"]"#))]"
    } else {
      body = "[\(Self.item(5)),\(Self.item(6))]"
    }
    let response = HTTPURLResponse(
      url: url, statusCode: 200, httpVersion: nil,
      headerFields: mode == "conditional" ? ["Last-Modified": Self.lastModified] : nil)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(body.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}

  private static func item(_ id: Int, genres: String = "[]") -> String {
    #"{"title":"T\#(id)","ids":{"simkl_id":\#(id)},"genres":\#(genres)}"#
  }
}

/// Stands in for Simkl's list endpoints. The access token carries the test's
/// id and the list `/sync/watched` reports ("none" for no list, or "offline").
private final class QuickChangeProtocol: URLProtocol, @unchecked Sendable {
  nonisolated(unsafe) private static var recorded: [String: [String]] = [:]
  private static let lock = NSLock()

  /// Each request's path, plus the list it moved a title to.
  static func calls(for token: String) -> [String] { lock.withLock { recorded[token] ?? [] } }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    let token = (request.value(forHTTPHeaderField: "Authorization") ?? "")
      .replacingOccurrences(of: "Bearer ", with: "")
    let list = token.split(separator: ":").last.map(String.init) ?? ""
    let path = request.url?.path ?? ""
    let body = Self.body(of: request)
    let entry = (body?.values.first as? [[String: Any]])?.first
    let call = (entry?["to"] as? String).map { "\(path) \($0)" } ?? path
    Self.lock.withLock { Self.recorded[token, default: []].append(call) }
    if list == "offline" {
      client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
      return
    }
    let json =
      switch path {
      case "/sync/watched":
        list == "none"
          ? #"[{"ids":{"simkl":42},"result":"not_found","type":"movie"}]"#
          : #"[{"simkl":42,"result":true,"list":"\#(list)"}]"#
      case "/sync/history/remove":
        #"{"deleted":{"movies":1,"shows":0},"not_found":{"movies":[],"shows":[]}}"#
      default:
        #"{"added":{"movies":1,"shows":0},"not_found":{"movies":[],"shows":[]}}"#
      }
    let response = HTTPURLResponse(
      url: request.url!, statusCode: path == "/sync/watched" ? 200 : 201, httpVersion: nil,
      headerFields: nil)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(json.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}

  /// URLSession hands protocols the body as a stream.
  private static func body(of request: URLRequest) -> [String: Any]? {
    var data = request.httpBody
    if data == nil, let stream = request.httpBodyStream {
      stream.open()
      defer { stream.close() }
      var read = Data()
      var bytes = [UInt8](repeating: 0, count: 1024)
      while stream.hasBytesAvailable {
        let count = stream.read(&bytes, maxLength: bytes.count)
        if count <= 0 { break }
        read.append(contentsOf: bytes.prefix(count))
      }
      data = read
    }
    return data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
  }
}
