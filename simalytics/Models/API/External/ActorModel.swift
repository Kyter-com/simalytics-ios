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

struct SimklIDLookupResponse: Codable {
  let type: String?
  let ids: SimklIDLookupIDs?
}

struct SimklIDLookupIDs: Codable {
  let simkl: Int?
}
