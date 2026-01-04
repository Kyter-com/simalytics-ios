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
  @EnvironmentObject private var auth: Auth
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.modelContext) private var modelContext
  @AppStorage("useFiveStarRating") private var useFiveStarRating = false
  @State private var movieDetails: MovieDetailsModel?
  @State private var movieWatchlist: MovieWatchlistModel?
  @State private var isLoading = true
  @State private var watchlistStatus: String?
  @State private var localRating: Double = 0
  @State private var originalRating: Double = 0
  @State private var showingMemoSheet = false
  @State private var memoText: String = ""
  @State private var privacySelection: String = "Public"
  var simkl_id: Int

  // MARK: - Sheets
  @State private var showingJustWatchSheet = false
  @State private var showingFullscreenPoster = false

  var body: some View {
    if isLoading {
      ProgressView("Loading...")
        .onAppear {
          Task {
            movieDetails = await MovieDetailView.getMovieDetails(simkl_id)
            movieWatchlist = await MovieDetailView.getMovieWatchlist(simkl_id, auth.simklAccessToken)
            watchlistStatus = movieWatchlist?.list

            if let fanart = movieDetails?.fanart {
              let imageURL = URL(string: "\(SIMKL_CDN_URL)/fanart/\(fanart)_mobile.jpg")!
              KingfisherManager.shared.retrieveImage(with: imageURL) { _ in }
            }

            isLoading = false

            Task { @MainActor [modelContext, simkl_id] in
              do {
                let movies = try modelContext.fetch(
                  FetchDescriptor<V1.SDMovies>(predicate: #Predicate { $0.simkl == simkl_id })
                )
                if let movie = movies.first {
                  let simklRating = Double(movie.user_rating ?? 0)
                  self.localRating = useFiveStarRating ? simklRating / 2 : simklRating
                  self.originalRating = self.localRating
                  self.memoText = movie.memo_text ?? ""
                  self.privacySelection = movie.memo_is_private ?? true ? "Private" : "Public"
                }
              } catch {}
            }
          }
        }
    } else {
      ScrollView {
        ParallaxBackgroundImage(fanart: movieDetails?.fanart)

        HStack {
          CustomKFImage(
            imageUrlString: movieDetails?.poster != nil
              ? "\(SIMKL_CDN_URL)/posters/\(movieDetails?.poster ?? "")_m.jpg" : nil,
            memoryCacheOnly: true,
            height: 225,
            width: 150
          )
          .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(
              colorScheme == .dark ? Color.black : Color.white, lineWidth: 4)
          )
          .onTapGesture {
            if movieDetails?.poster != nil {
              showingFullscreenPoster = true
            }
          }

          Spacer()
          VStack(alignment: .leading) {
            Spacer()
              .frame(height: 8)
            Spacer()
            if let year = movieDetails?.year {
              LabeledContent {
                Text(String(year))
                  .fontDesign(.monospaced)
                  .foregroundColor(.secondary)
              } label: {
                Label("Released", systemImage: "calendar")
                  .foregroundColor(.secondary)
              }
            }
            if let runtime = movieDetails?.runtime {
              LabeledContent {
                Text("\(String(runtime)) Min")
                  .fontDesign(.monospaced)
                  .foregroundColor(.secondary)
              } label: {
                Label("Runtime", systemImage: "clock")
                  .foregroundColor(.secondary)
              }
            }
            if let certification = movieDetails?.certification {
              LabeledContent {
                Text(certification)
                  .fontDesign(.monospaced)
                  .foregroundColor(.secondary)
              } label: {
                Label("MPAA", systemImage: "figure.and.child.holdinghands")
                  .foregroundColor(.secondary)
              }
            }
            if let language = movieDetails?.language {
              LabeledContent {
                Text(language)
                  .fontDesign(.monospaced)
                  .foregroundColor(.secondary)
              } label: {
                Label("Language", systemImage: "globe")
                  .foregroundColor(.secondary)
              }
            }
            if let simklRating = movieDetails?.ratings?.simkl?.rating {
              LabeledContent {
                Text(String(simklRating))
                  .fontDesign(.monospaced)
                  .foregroundColor(.secondary)
              } label: {
                Label("SIMKL Rating", systemImage: "trophy")
                  .foregroundColor(.secondary)
              }
            }
            Spacer()
            if !auth.simklAccessToken.isEmpty {
              MovieWatchlistButton(status: $watchlistStatus, simkl_id: simkl_id)
            }
            Spacer()
              .frame(height: 2)
          }
        }
        .padding([.leading, .trailing])
        .offset(y: -10)
        .background(colorScheme == .dark ? Color.black : Color.white)

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
            .foregroundColor(.secondary)
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
          RatingView(
            maxRating: useFiveStarRating ? 5 : 10,
            rating: $localRating,
            starColor: .blue,
            starRounding: .roundToFullStar,
            size: useFiveStarRating ? 28 : 20
          )
          .padding([.leading, .trailing])
          .padding(.top, 8)
        }

        HStack {
          if watchlistStatus != nil {
            Button(action: {
              showingMemoSheet.toggle()
            }) {
              Label("Add Memo", systemImage: "square.and.pencil")
                .padding([.leading, .trailing])
                .padding(.top, 8)
            }
          }
          Button(action: {
            showingJustWatchSheet.toggle()
          }) {
            Label("Where to Watch", systemImage: "sparkles.tv")
              .padding([.leading, .trailing])
              .padding(.top, 8)
          }
        }

        Spacer()

        Recommendations(recommendations: movieDetails?.users_recommendations)
      }
      .onChange(of: localRating) {
        if localRating == originalRating { return }
        Task {
          let ratingForSimkl = useFiveStarRating ? localRating * 2 : localRating
          await MovieDetailView.addMovieRating(simkl_id, auth.simklAccessToken, ratingForSimkl)
          await syncLatestActivities(auth.simklAccessToken, modelContainer: modelContext.container)
        }
      }
      .sheet(isPresented: $showingMemoSheet) {
        MemoView(
          memoText: $memoText, privacySelection: $privacySelection, simkl_id: simkl_id, item_status: watchlistStatus ?? "", simkl_type: "movie"
        )
        .presentationDetents([.medium, .large])
      }
      .sheet(isPresented: $showingJustWatchSheet) {
        JustWatchView(
          tmdbId: movieDetails?.ids?.tmdb,
          mediaType: "movie"
        )
        .presentationDetents([.fraction(0.99)])
      }
      .fullScreenCover(isPresented: $showingFullscreenPoster) {
        if let poster = movieDetails?.poster {
          FullscreenPosterView(posterPath: poster)
        }
      }
    }
  }
}
