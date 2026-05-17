//
//  MediaDestinationView.swift
//  simalytics
//
//  Created by Codex on 5/17/26.
//

import SwiftUI

enum MediaDestination: Hashable {
  case movie(Int)
  case show(Int)
  case anime(Int)
}

struct MediaDestinationView: View {
  let destination: MediaDestination

  var body: some View {
    switch destination {
    case .movie(let simklID):
      MovieDetailView(simkl_id: simklID)
    case .show(let simklID):
      ShowDetailView(simkl_id: simklID)
    case .anime(let simklID):
      AnimeDetailView(simkl_id: simklID)
    }
  }
}

