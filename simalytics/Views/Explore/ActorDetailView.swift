//
//  ActorDetailView.swift
//  simalytics
//
//  Created by Codex on 5/17/26.
//

import SwiftUI

struct ActorDetailView: View {
  @Environment(Auth.self) private var auth
  @AppStorage("hideAnime") private var hideAnime = false
  let personID: Int

  @State private var details: TMDBPersonDetails?
  @State private var filmography: [ActorFilmographyItem] = []
  @State private var isLoading = true

  private var visibleFilmography: [ActorFilmographyItem] {
    filmography.filter { item in
      !hideAnime || !item.isAnime
    }
  }

  var body: some View {
    Group {
      if isLoading {
        ProgressView("Loading...")
      } else if let details {
        ScrollView {
          VStack(alignment: .leading, spacing: 20) {
            ActorHeader(details: details)

            if let biography = details.biography?.nilIfEmpty {
              VStack(alignment: .leading, spacing: 8) {
                Text("Biography")
                  .font(.headline)
                Text(biography)
                  .font(.body)
                  .foregroundStyle(.secondary)
              }
              .padding(.horizontal)
            }

            ActorFilmographySection(items: visibleFilmography)
          }
          .padding(.bottom)
        }
        .navigationTitle(details.name)
        .navigationBarTitleDisplayMode(.inline)
      } else {
        ContentUnavailableView {
          Label("Actor unavailable", systemImage: "person.crop.rectangle")
        } description: {
          Text("Actor details could not be loaded.")
        }
      }
    }
    .task(id: personID) {
      isLoading = true
      let loadedDetails = await ActorDetailView.getActorDetails(auth.simklAccessToken, personID: personID)
      details = loadedDetails
      if let loadedDetails {
        filmography = await ActorDetailView.filmographyItems(from: loadedDetails)
      } else {
        filmography = []
      }
      isLoading = false
    }
  }
}

private struct ActorHeader: View {
  let details: TMDBPersonDetails

  private var imageUrl: String? {
    guard let profilePath = details.profile_path?.nilIfEmpty else { return nil }
    return "https://media.themoviedb.org/t/p/w342\(profilePath)"
  }

  var body: some View {
    HStack(alignment: .bottom, spacing: 16) {
      CustomKFImage(
        imageUrlString: imageUrl,
        memoryCacheOnly: false,
        height: 210,
        width: 140
      )

      VStack(alignment: .leading, spacing: 10) {
        Text(details.name)
          .font(.title2)
          .fontWeight(.semibold)

        if let department = details.known_for_department?.nilIfEmpty {
          Label(department, systemImage: "star")
            .foregroundStyle(.secondary)
        }

        if let birthday = details.birthday?.nilIfEmpty {
          Label(actorDateText(birthday, deathday: details.deathday), systemImage: "calendar")
            .foregroundStyle(.secondary)
        }

        if let birthplace = details.place_of_birth?.nilIfEmpty {
          Label(birthplace, systemImage: "mappin.and.ellipse")
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }
      .font(.subheadline)

      Spacer(minLength: 0)
    }
    .padding(.horizontal)
    .padding(.top)
  }

  private func actorDateText(_ birthday: String, deathday: String?) -> String {
    guard let deathday = deathday?.nilIfEmpty else { return birthday }
    return "\(birthday) - \(deathday)"
  }
}

private struct ActorFilmographySection: View {
  let items: [ActorFilmographyItem]

  private var movies: [ActorFilmographyItem] {
    items.filter { $0.credit.media_type == "movie" }
  }

  private var shows: [ActorFilmographyItem] {
    items.filter { $0.credit.media_type == "tv" }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      if !movies.isEmpty {
        ActorCreditShelf(title: "Movies", items: movies)
      }

      if !shows.isEmpty {
        ActorCreditShelf(title: "Shows", items: shows)
      }

      if movies.isEmpty && shows.isEmpty {
        ContentUnavailableView {
          Label("No credits", systemImage: "film.stack")
        } description: {
          Text("No filmography items were found.")
        }
        .padding(.horizontal)
      }
    }
  }
}

private struct ActorCreditShelf: View {
  let title: String
  let items: [ActorFilmographyItem]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.headline)
        .padding(.horizontal)

      ScrollView(.horizontal) {
        HStack(alignment: .top, spacing: 12) {
          ForEach(items) { item in
            ActorCreditCard(item: item)
          }
        }
        .padding(.horizontal)
      }
      .scrollIndicators(.hidden)
    }
  }
}

private struct ActorCreditCard: View {
  let item: ActorFilmographyItem

  private var posterUrl: String? {
    guard let posterPath = item.credit.poster_path?.nilIfEmpty else { return nil }
    return "https://media.themoviedb.org/t/p/w342\(posterPath)"
  }

  var body: some View {
    Group {
      if let destination = item.destination {
        NavigationLink(destination: MediaDestinationView(destination: destination)) {
          cardContent
        }
        .buttonStyle(.plain)
      } else {
        cardContent
          .opacity(0.65)
      }
    }
    .frame(width: 100)
  }

  private var cardContent: some View {
    VStack(alignment: .leading, spacing: 5) {
      CustomKFImage(
        imageUrlString: posterUrl,
        memoryCacheOnly: false,
        height: 147,
        width: 100
      )

      Text(item.credit.displayTitle)
        .font(.caption)
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)

      if let year = item.credit.year {
        Text(year)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      if !item.credit.role.isEmpty {
        Text(item.credit.role)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
    }
  }
}
