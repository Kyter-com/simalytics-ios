//
//  UpNextV2View.swift
//  simalytics
//
//  Created by Nick Reisenauer on 6/8/25.
//

import SwiftData
import SwiftUI

struct UpNextV2View: View {
  @Query(
    filter: #Predicate<V1.SDShows> { show in
      show.next_to_watch_info_title != nil
    }, sort: \V1.SDShows.title) var shows: [V1.SDShows]

  var body: some View {
    List(shows, id: \.simkl) { show in
      Text(show.title ?? "Untitled")
      Text(show.next_to_watch_info_title ?? "No next episode")
    }
  }
}
