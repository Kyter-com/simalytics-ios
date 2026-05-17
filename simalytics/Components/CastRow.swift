//
//  CastRow.swift
//  simalytics
//
//  Created by Nick Reisenauer on 5/14/26.
//

import SwiftUI

struct CastCard: View {
  let member: TMDBCastMember

  private var imageUrl: String? {
    guard let path = member.profile_path, !path.isEmpty else { return nil }
    return "https://media.themoviedb.org/t/p/w342\(path)"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      CustomKFImage(
        imageUrlString: imageUrl,
        memoryCacheOnly: false,
        height: 135,
        width: 90
      )

      if let name = member.name, !name.isEmpty {
        Text(name)
          .font(.caption)
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      if let character = member.character, !character.isEmpty {
        Text(character)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      Spacer(minLength: 0)
    }
    .frame(width: 90)
  }
}

struct CastRow: View {
  let cast: [TMDBCastMember]

  var body: some View {
    if !cast.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        Text("Cast")
          .font(.headline)
          .padding(.horizontal)

        ScrollView(.horizontal) {
          HStack(alignment: .top, spacing: 12) {
            ForEach(cast.prefix(20)) { member in
              NavigationLink(destination: ActorDetailView(personID: member.id)) {
                CastCard(member: member)
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
      }
      .padding(.top, 8)
    }
  }
}
