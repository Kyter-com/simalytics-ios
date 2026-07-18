//
//  SmartPreviewCard.swift
//  simalytics
//
//  Created by Nick Reisenauer on 1/8/26.
//

import SwiftUI

/// A preview card that uses value-only data preloaded by its parent.
struct SmartPreviewCard: View {
  let simklId: Int
  let title: String
  let year: Int?
  let poster: String?
  let mediaType: String
  let localData: LocalMediaData?

  var body: some View {
    PreviewCard(
      title: title,
      year: localData?.year ?? year,
      poster: poster,
      userRating: localData?.userRating,
      status: localData?.status,
      mediaType: mediaType,
      animeType: localData?.animeType,
      watchedEpisodes: localData?.watchedEpisodes,
      totalEpisodes: localData?.totalEpisodes
    )
  }
}
