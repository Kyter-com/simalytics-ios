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
  @State private var rawCredits: [TMDBPersonCredit] = []
  @State private var filmography: [ActorFilmographyItem] = []
  @State private var isLoading = true
  @State private var isResolvingFilmography = false

  private var visibleFilmography: [ActorFilmographyItem] {
    filmography.filter { item in
      !hideAnime || !item.isAnime
    }
  }

  private var visibleRawCredits: [TMDBPersonCredit] {
    rawCredits
  }

  var body: some View {
    Group {
      if let details {
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

            ActorFilmographySection(
              items: visibleFilmography,
              placeholderCredits: visibleRawCredits,
              isResolving: isResolvingFilmography
            )
          }
          .padding(.bottom)
        }
        .navigationTitle(details.name)
        .navigationBarTitleDisplayMode(.inline)
      } else if isLoading {
        ActorDetailSkeleton()
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
      isResolvingFilmography = false
      let loadedDetails = await ActorDetailView.getActorDetails(auth.simklAccessToken, personID: personID)
      details = loadedDetails
      if let loadedDetails {
        rawCredits = Array(loadedDetails.sortedFilmographyCredits.prefix(80))
        isLoading = false
        isResolvingFilmography = true
        filmography = await ActorDetailView.filmographyItems(from: loadedDetails)
      } else {
        rawCredits = []
        filmography = []
        isLoading = false
      }
      isResolvingFilmography = false
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
    HStack(alignment: .top, spacing: 16) {
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
  let placeholderCredits: [TMDBPersonCredit]
  let isResolving: Bool

  private var movies: [ActorFilmographyItem] {
    items.filter { $0.credit.media_type == "movie" }
  }

  private var shows: [ActorFilmographyItem] {
    items.filter { $0.credit.media_type == "tv" }
  }

  private var placeholderMovies: [TMDBPersonCredit] {
    placeholderCredits.filter { $0.media_type == "movie" }
  }

  private var placeholderShows: [TMDBPersonCredit] {
    placeholderCredits.filter { $0.media_type == "tv" }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      if isResolving && movies.isEmpty && !placeholderMovies.isEmpty {
        ActorCreditPlaceholderShelf(title: "Movies", credits: placeholderMovies)
      } else if !movies.isEmpty {
        ActorCreditShelf(title: "Movies", items: movies)
      }

      if isResolving && shows.isEmpty && !placeholderShows.isEmpty {
        ActorCreditPlaceholderShelf(title: "Shows", credits: placeholderShows)
      } else if !shows.isEmpty {
        ActorCreditShelf(title: "Shows", items: shows)
      }

      if !isResolving && movies.isEmpty && shows.isEmpty {
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

private struct ActorCreditPlaceholderShelf: View {
  let title: String
  let credits: [TMDBPersonCredit]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Text(title)
          .font(.headline)
        ProgressView()
          .controlSize(.small)
      }
      .padding(.horizontal)

      ScrollView(.horizontal) {
        HStack(alignment: .top, spacing: 12) {
          ForEach(credits.prefix(12), id: \.stableID) { credit in
            ActorCreditPlaceholderCard(credit: credit)
          }
        }
        .padding(.horizontal)
      }
      .scrollIndicators(.hidden)
    }
  }
}

private struct ActorCreditPlaceholderCard: View {
  let credit: TMDBPersonCredit

  private var posterUrl: String? {
    guard let posterPath = credit.poster_path?.nilIfEmpty else { return nil }
    return "https://media.themoviedb.org/t/p/w342\(posterPath)"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      CustomKFImage(
        imageUrlString: posterUrl,
        memoryCacheOnly: false,
        height: 147,
        width: 100
      )

      Text(credit.displayTitle)
        .font(.caption)
        .lineLimit(2)
        .frame(maxWidth: .infinity, alignment: .leading)

      Text(credit.year ?? "Resolving")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(width: 100)
    .redacted(reason: .placeholder)
    .allowsHitTesting(false)
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

private struct ActorDetailSkeleton: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        HStack(alignment: .top, spacing: 16) {
          RoundedRectangle(cornerRadius: 8)
            .fill(.secondary.opacity(0.25))
            .frame(width: 140, height: 210)

          VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
              .fill(.secondary.opacity(0.25))
              .frame(width: 160, height: 24)
            RoundedRectangle(cornerRadius: 4)
              .fill(.secondary.opacity(0.25))
              .frame(width: 110, height: 16)
            RoundedRectangle(cornerRadius: 4)
              .fill(.secondary.opacity(0.25))
              .frame(width: 130, height: 16)
          }

          Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.top)

        VStack(alignment: .leading, spacing: 8) {
          RoundedRectangle(cornerRadius: 4)
            .fill(.secondary.opacity(0.25))
            .frame(width: 90, height: 18)
          RoundedRectangle(cornerRadius: 4)
            .fill(.secondary.opacity(0.25))
            .frame(height: 14)
          RoundedRectangle(cornerRadius: 4)
            .fill(.secondary.opacity(0.25))
            .frame(height: 14)
          RoundedRectangle(cornerRadius: 4)
            .fill(.secondary.opacity(0.25))
            .frame(width: 220, height: 14)
        }
        .padding(.horizontal)

        ActorStaticPlaceholderShelf(title: "Movies")
        ActorStaticPlaceholderShelf(title: "Shows")
      }
      .padding(.bottom)
      .redacted(reason: .placeholder)
    }
    .navigationTitle("Actor")
    .navigationBarTitleDisplayMode(.inline)
  }
}

private struct ActorStaticPlaceholderShelf: View {
  let title: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.headline)
        .padding(.horizontal)

      ScrollView(.horizontal) {
        HStack(alignment: .top, spacing: 12) {
          ForEach(0..<5, id: \.self) { index in
            VStack(alignment: .leading, spacing: 5) {
              RoundedRectangle(cornerRadius: 8)
                .fill(.secondary.opacity(0.25))
                .frame(width: 100, height: 147)
              RoundedRectangle(cornerRadius: 4)
                .fill(.secondary.opacity(0.25))
                .frame(width: index.isMultiple(of: 2) ? 88 : 70, height: 12)
              RoundedRectangle(cornerRadius: 4)
                .fill(.secondary.opacity(0.25))
                .frame(width: 44, height: 10)
            }
            .frame(width: 100)
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
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if !item.credit.role.isEmpty {
        Text(item.credit.role)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
    }
  }
}
