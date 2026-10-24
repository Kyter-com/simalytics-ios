//
//  ScreenshotDiscoverFixtures.swift
//  simalytics
//
//  DEBUG-only Explore data for the App Store screenshot pipeline
//  (marketing/app-store-screenshots). Every title is a verified public-domain
//  work from pd-catalog.json and every `poster`/`fanart` keys a local PD JPEG
//  served by ScreenshotMode.PosterURLProtocol. Ids, ratings, and counts are
//  synthetic; nothing here is ever fetched from Simkl.

#if DEBUG
  import Foundation

  enum ScreenshotDiscoverFixtures {
    static var trending: [DiscoverMediaType: [DiscoverItem]] {
      [.movies: movies, .shows: shows, .anime: anime]
    }

    static var pools: [DiscoverMediaType: [DiscoverItem]] { trending }

    static var genreIndex: [DiscoverMediaType: [DiscoverGenre]] {
      func index(_ type: DiscoverMediaType) -> [DiscoverGenre] {
        let names = Set((trending[type] ?? []).flatMap { $0.genres ?? [] })
        return names.sorted().map {
          DiscoverGenre(
            name: $0, slug: $0.lowercased().replacingOccurrences(of: " ", with: "-"), count: 500)
        }
      }
      return [.movies: index(.movies), .shows: index(.shows), .anime: index(.anime)]
    }

    static func items(inGenre name: String, type: DiscoverMediaType) -> [DiscoverItem] {
      (trending[type] ?? []).filter { $0.genres?.contains(name) ?? false }
    }

    // MARK: Fixtures — vivid color posters lead so the shelves pop.

    private static let movies: [DiscoverItem] = [
      item(
        .movies, 910010, "His Girl Friday", 1940, "his-girl-friday-1940",
        fanart: "his-girl-friday-1940-fanart", ["Comedy", "Romance"], 8.1, "1h 32m", rank: 2140,
        overview: "A hard-charging editor schemes to win back his star reporter, and ex-wife, before she remarries."),
      item(.movies, 910001, "The Lost World", 1925, "the-lost-world-1925", ["Adventure", "Fantasy", "Science Fiction"], 7.2, "1h 33m",
        overview: "An expedition up the Amazon finds a plateau where dinosaurs still roam, and brings one home to London."),
      item(.movies, 910002, "The Gorilla", 1927, "the-gorilla-1927", ["Comedy", "Horror", "Mystery"], 6.6, "1h 18m",
        overview: "Two bumbling detectives chase a killer said to be a gorilla through a creaky old mansion."),
      item(.movies, 910003, "Don Q, Son of Zorro", 1925, "don-q-son-of-zorro-1925", ["Action", "Adventure"], 7.0, "1h 51m"),
      item(.movies, 910004, "Robin Hood", 1922, "robin-hood-1922", ["Action", "Adventure", "Romance"], 7.1, "2h 23m"),
      item(.movies, 910005, "Ben-Hur: A Tale of the Christ", 1925, "ben-hur-1925", ["Adventure", "Drama", "History"], 7.8, "2h 23m", rank: 2600),
      item(.movies, 910006, "The Black Pirate", 1926, "the-black-pirate-1926", ["Action", "Adventure"], 7.0, "1h 34m"),
      item(.movies, 910007, "7th Heaven", 1927, "7th-heaven-1927", ["Drama", "Romance"], 7.6, "1h 50m", rank: 3900),
      item(.movies, 910008, "The Gold Rush", 1925, "the-gold-rush-1925", ["Adventure", "Comedy", "Family"], 8.2, "1h 35m"),
      item(.movies, 910009, "The General", 1926, "the-general-1926", ["Action", "Comedy", "War"], 8.3, "1h 18m"),
      item(.movies, 910011, "Meet John Doe", 1941, "meet-john-doe-1941", ["Comedy", "Drama"], 7.5, "2h 2m", rank: 3300),
      item(.movies, 910012, "A Star Is Born", 1937, "a-star-is-born-1937", ["Drama", "Romance"], 7.3, "1h 51m"),
      item(.movies, 910013, "The Kid", 1921, "the-kid-1921", ["Comedy", "Drama", "Family"], 8.3, "1h 8m"),
      item(.movies, 910014, "Charade", 1963, "charade-1963", ["Comedy", "Mystery", "Romance", "Thriller"], 8.0, "1h 53m"),
      item(.movies, 910015, "The Cabinet of Dr. Caligari", 1920, "the-cabinet-of-dr-caligari-1920", ["Horror", "Mystery", "Thriller"], 8.0, "1h 16m", rank: 2900),
      item(.movies, 910016, "Detour", 1945, "detour-1945", ["Crime", "Thriller"], 7.2, "1h 7m"),
      item(.movies, 910017, "The Stranger", 1946, "the-stranger-1946", ["Crime", "Mystery", "Thriller"], 7.3, "1h 35m"),
      item(.movies, 910018, "My Man Godfrey", 1936, "my-man-godfrey-1936", ["Comedy", "Romance"], 7.9, "1h 34m", rank: 4100),
      item(.movies, 910019, "Carnival of Souls", 1962, "carnival-of-souls-1962", ["Horror", "Mystery"], 7.0, "1h 18m"),
      item(.movies, 910020, "House on Haunted Hill", 1959, "house-on-haunted-hill-1959", ["Horror", "Mystery"], 6.8, "1h 15m"),
      item(.movies, 910021, "D.O.A.", 1950, "d-o-a-1950", ["Crime", "Thriller"], 7.2, "1h 23m"),
      item(.movies, 910022, "Nanook of the North", 1922, "nanook-of-the-north-1922", ["Documentary"], 7.5, "1h 19m", rank: 5200),
      item(.movies, 910023, "A Trip to the Moon", 1902, "a-trip-to-the-moon-1902", ["Adventure", "Fantasy", "Science Fiction"], 8.1, "13m"),
      item(.movies, 910024, "The Phantom of the Opera", 1925, "the-phantom-of-the-opera-1925", ["Drama", "Horror"], 7.5, "1h 33m"),
      item(.movies, 910025, "Gulliver's Travels", 1939, "gulliver-s-travels-1939", ["Animation", "Family", "Fantasy"], 6.5, "1h 16m"),
    ]

    private static let shows: [DiscoverItem] = [
      item(.shows, 920001, "The Cisco Kid", 1950, "in-old-arizona-1929", ["Adventure", "Western"], 7.4, "26m", network: "NBC", episodes: 156,
        overview: "The Cisco Kid and his sidekick Pancho ride the Old West, righting wrongs with charm and a quick draw."),
      item(.shows, 920002, "The Lone Ranger", 1949, "the-lone-ranger-1938-serial", ["Action", "Western"], 7.6, "26m", network: "ABC (US)", episodes: 221,
        overview: "A masked Texas Ranger and his friend Tonto bring outlaws to justice across the frontier."),
      item(.shows, 920003, "Hopalong Cassidy", 1949, "hopalong-cassidy-1936", ["Western"], 8.0, "26m", network: "NBC", episodes: 52,
        overview: "Cowboy hero Hopalong Cassidy keeps the peace on the range with his trusty horse Topper."),
      item(.shows, 920004, "Sherlock Holmes", 1954, "sherlock-holmes-1922", ["Crime", "Mystery"], 8.1, "26m", network: "NBC", episodes: 39),
      item(.shows, 920005, "Dragnet", 1951, "dragnet-1951", ["Crime", "Drama"], 7.9, "30m", network: "NBC", episodes: 276),
      item(.shows, 920006, "The Beverly Hillbillies", 1962, "the-beverly-hillbillies-1962", ["Comedy", "Family"], 7.3, "25m", network: "CBS", episodes: 274),
      item(.shows, 920007, "Alcoa Presents: One Step Beyond", 1959, "alcoa-presents-one-step-beyond-1959", ["Drama", "Mystery", "Science-Fiction"], 8.2, "25m", network: "ABC (US)", episodes: 96),
      item(.shows, 920008, "The Red Skelton Show", 1951, "the-red-skelton-show-1951", ["Comedy"], 7.1, "30m", network: "CBS", episodes: 120),
      item(.shows, 920009, "You Bet Your Life", 1950, "you-bet-your-life-1950", ["Comedy", "Game Show"], 7.4, "30m", network: "NBC", episodes: 423),
      item(.shows, 920010, "The George Burns and Gracie Allen Show", 1950, "the-george-burns-and-gracie-allen-show-1950", ["Comedy", "Family"], 7.6, "30m", network: "CBS", episodes: 291),
    ]

    private static let anime: [DiscoverItem] = [
      item(.anime, 930001, "Namakura Gatana", 1917, "namakura-gatana-1917", ["Action", "Comedy"], 7.2, "4m", episodes: 1,
        overview: "A hapless samurai buys a dull sword and sets out to prove himself on the road."),
      item(.anime, 930002, "Urashima Tarō", 1918, "namakura-gatana-1917", ["Adventure", "Fantasy"], 6.9, "5m", episodes: 1,
        overview: "A fisherman who rescues a turtle is carried away to a palace beneath the sea."),
      item(.anime, 930003, "Momotarō", 1918, "namakura-gatana-1917", ["Adventure", "Action"], 6.8, "5m", episodes: 1,
        overview: "A boy born from a peach sets out with animal friends to defeat the ogres of Onigashima."),
    ]

    private static func item(
      _ type: DiscoverMediaType, _ simkl: Int, _ title: String, _ year: Int, _ poster: String,
      fanart: String? = nil, _ genres: [String], _ rating: Double, _ runtime: String,
      rank: Int = 900, network: String? = nil, episodes: Int? = nil, overview: String? = nil
    ) -> DiscoverItem {
      DiscoverItem(
        title: title, url: nil, poster: poster, fanart: fanart,
        ids: .init(simkl_id: simkl, slug: nil), release_date: "01/01/\(year)", rank: rank,
        watched: 2_000 - simkl % 100 * 40, plan_to_watch: 4_000 + simkl % 97 * 35,
        // An outside score and a drop rate fill the Loved Everywhere and Hard to
        // Quit tiles, so the Collections grid shows six.
        ratings: .init(
          simkl: .init(rating: rating, votes: 1_200), imdb: .init(rating: rating, votes: 9_000),
          mal: nil),
        runtime: runtime, status: "ended", genres: genres, network: network,
        total_episodes: episodes, anime_type: type == .anime ? "movie" : nil,
        drop_rate: "\(Double(simkl % 9) / 10 + 0.2)%", overview: overview, type: type)
    }
  }
#endif
