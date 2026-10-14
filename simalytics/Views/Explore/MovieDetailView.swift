//
//  MovieDetailView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/6/25.
//

import Kingfisher
import SwiftData
import SwiftUI

struct MovieDetailView: View {
  @Environment(Auth.self) private var auth
  @Environment(\.modelContext) private var modelContext
  @State private var movieDetails: MovieDetailsModel?
  @State private var movieWatchlist: MovieWatchlistModel?
  @State private var cast: [TMDBCastMember] = []
  @State private var isLoading = true
  @State private var watchlistStatus: String?
  @State private var localRating: Double = 0
  @State private var showingMemoSheet = false
  @State private var memoText: String = ""
  @State private var privacySelection: String = "Public"
  var simkl_id: Int

  // MARK: - Sheets
  @State private var showingJustWatchSheet = false

  var body: some View {
    if isLoading {
      ProgressView("Loading...")
        .task(id: simkl_id) {
          movieDetails = await MovieDetailView.getMovieDetails(simkl_id)
          movieWatchlist = await MovieDetailView.getMovieWatchlist(simkl_id, auth.simklAccessToken)
          watchlistStatus = movieWatchlist?.list

          cast = await getCast(auth.simklAccessToken, movieDetails?.ids?.tmdb, mediaType: "movie")

          if let fanart = movieDetails?.fanart {
            let imageURL = URL(string: "\(SIMKL_CDN_URL)/fanart/\(fanart)_mobile.jpg")!
            KingfisherManager.shared.retrieveImage(with: imageURL) { _ in }
          }

          do {
            let movies = try modelContext.fetch(
              FetchDescriptor<V1.SDMovies>(predicate: #Predicate { $0.simkl == simkl_id })
            )
            if let movie = movies.first {
              let simklRating = Double(movie.user_rating ?? 0)
              self.localRating = simklRating
              self.memoText = movie.memo_text ?? ""
              self.privacySelection = movie.memo_is_private ?? true ? "Private" : "Public"
            }
          } catch {}

          isLoading = false
        }
    } else if movieDetails == nil {
      ContentUnavailableView {
        Label("Movie unavailable", systemImage: "film")
      } description: {
        Text("Simkl didn't return details for this movie.")
      }
    } else {
      ScrollView {
        ParallaxBackgroundImage(fanart: movieDetails?.fanart)

        MediaDetailHeader(
          poster: movieDetails?.poster, title: movieDetails?.title ?? "movie", posterHeight: 225
        ) {
          if let year = movieDetails?.year {
            LabeledContent {
              Text(String(year))
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
            } label: {
              Label("Released", systemImage: "calendar")
                .foregroundStyle(.secondary)
            }
          }
          if let runtime = movieDetails?.runtime {
            LabeledContent {
              Text("\(String(runtime)) Min")
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
            } label: {
              Label("Runtime", systemImage: "clock")
                .foregroundStyle(.secondary)
            }
          }
          if let certification = movieDetails?.certification {
            LabeledContent {
              Text(certification)
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
            } label: {
              Label("MPAA", systemImage: "figure.and.child.holdinghands")
                .foregroundStyle(.secondary)
            }
          }
          if let language = movieDetails?.language {
            LabeledContent {
              Text(language)
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
            } label: {
              Label("Language", systemImage: "globe")
                .foregroundStyle(.secondary)
            }
          }
          if let simklRating = movieDetails?.ratings?.simkl?.rating {
            LabeledContent {
              Text(String(simklRating))
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
            } label: {
              Label("SIMKL Rating", systemImage: "trophy")
                .foregroundStyle(.secondary)
            }
          }
        } status: {
          if !auth.simklAccessToken.isEmpty {
            MovieWatchlistButton(status: $watchlistStatus, simkl_id: simkl_id)
          }
        }

        if let title = movieDetails?.title {
          Text(title)
            .font(.title)
            .bold()
            .fontDesign(.rounded)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding([.leading, .trailing])
            .offset(y: -10)
        }

        if let genres = movieDetails?.genres {
          Text(genres.joined(separator: " • "))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding([.leading, .trailing])
            .fontDesign(.monospaced)
        }

        if let overview = movieDetails?.overview {
          Text(overview)
            .font(.footnote)
            .padding([.leading, .trailing])
            .padding(.top, 8)
        }

        if watchlistStatus != nil {
          MediaRatingView(simklID: simkl_id, type: .movie, rating: $localRating)
        }

        MediaActionButtons(
          canAddMemo: watchlistStatus != nil,
          addMemo: { showingMemoSheet = true },
          whereToWatch: { showingJustWatchSheet = true })

        CastRow(cast: cast)

        Recommendations(recommendations: movieDetails?.users_recommendations)
      }
      .navigationBarTitleDisplayMode(.inline)
      .sheet(isPresented: $showingMemoSheet) {
        MemoView(
          memoText: $memoText, privacySelection: $privacySelection, simkl_id: simkl_id,
          item_status: watchlistStatus ?? "", simkl_type: "movie"
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
      }
      .sheet(isPresented: $showingJustWatchSheet) {
        JustWatchView(
          tmdbId: movieDetails?.ids?.tmdb,
          mediaType: "movie"
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
      }
    }
  }
}
