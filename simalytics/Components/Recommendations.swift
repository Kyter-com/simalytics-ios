//
//  Recommendations.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/30/25.
//

import SwiftUI

struct Recommendations: View {
  var recommendations: [RecommendationModel]?

  var body: some View {
    if let recommendations = recommendations, !recommendations.isEmpty {
      VStack(alignment: .leading) {
        Group {
          ExploreGroupTitle(title: "Users Also Watched")

          ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 16) {
              ForEach(
                recommendations, id: \.ids.simkl
              ) { item in
                NavigationLink(
                  destination: {
                    let type = item.type
                    let id = item.ids.simkl
                    if type == "tv" {
                      ShowDetailView(simkl_id: id)
                    } else if type == "movie" {
                      MovieDetailView(simkl_id: id)
                    } else if type == "anime" {
                      AnimeDetailView(simkl_id: id)
                    }
                  }
                ) {
                  VStack {
                    CustomKFImage(
                      imageUrlString: item.poster != nil
                        ? "\(SIMKL_CDN_URL)/posters/\(item.poster!)_m.jpg"
                        : NO_IMAGE_URL,
                      memoryCacheOnly: true,
                      height: 147,
                      width: 100
                    )
                    ExploreTitle(title: item.title)
                  }
                }
                .buttonStyle(.plain)
              }
            }
            .padding([.leading, .trailing, .bottom])
          }
        }
      }
    }
  }
}
