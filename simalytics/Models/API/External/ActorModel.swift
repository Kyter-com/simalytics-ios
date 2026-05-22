//
//  ActorModel.swift
//  simalytics
//
//  Created by Codex on 5/17/26.
//

import Foundation

struct TMDBPersonDetails: Codable {
  let id: Int
  let name: String
  let biography: String?
  let birthday: String?
  let deathday: String?
  let place_of_birth: String?
  let profile_path: String?
  let known_for_department: String?
  let combined_credits: TMDBPersonCombinedCredits?
}

extension TMDBPersonDetails {
  var sortedFilmographyCredits: [TMDBPersonCredit] {
    let cast = combined_credits?.cast ?? []
    let crew = combined_credits?.crew ?? []
    return TMDBPersonCredit.deduplicated(cast + crew)
      .filter { $0.media_type == "movie" || $0.media_type == "tv" }
      .sorted { lhs, rhs in
        let lhsDate = lhs.date ?? ""
        let rhsDate = rhs.date ?? ""
        if lhsDate != rhsDate { return lhsDate > rhsDate }
        return (lhs.popularity ?? 0) > (rhs.popularity ?? 0)
      }
  }
}

struct TMDBPersonCombinedCredits: Codable {
  let cast: [TMDBPersonCredit]?
  let crew: [TMDBPersonCredit]?
}

struct TMDBPersonCredit: Codable, Identifiable, Hashable {
  let id: Int
  let media_type: String
  let credit_id: String?
  let title: String?
  let name: String?
  let character: String?
  let job: String?
  let department: String?
  let poster_path: String?
  let release_date: String?
  let first_air_date: String?
  let popularity: Double?

  var stableID: String {
    "\(media_type)-\(id)-\(credit_id ?? role)"
  }

  var displayTitle: String {
    title ?? name ?? "Untitled"
  }

  var date: String? {
    release_date?.nilIfEmpty ?? first_air_date?.nilIfEmpty
  }

  var year: String? {
    date.map { String($0.prefix(4)) }
  }

  var role: String {
    character?.nilIfEmpty ?? job?.nilIfEmpty ?? department?.nilIfEmpty ?? ""
  }

  static func deduplicated(_ credits: [TMDBPersonCredit]) -> [TMDBPersonCredit] {
    var seen = Set<String>()
    var result: [TMDBPersonCredit] = []

    for credit in credits {
      let key = "\(credit.media_type)-\(credit.id)"
      guard !seen.contains(key) else { continue }
      seen.insert(key)
      result.append(credit)
    }

    return result
  }
}

struct ActorFilmographyItem: Identifiable, Hashable {
  let credit: TMDBPersonCredit
  let destination: MediaDestination?

  var id: String {
    credit.stableID
  }

  var isAnime: Bool {
    guard case .anime = destination else { return false }
    return true
  }
}
