//
//  ListView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/1/25.
//

import SwiftData
import SwiftUI

struct ListView: View {
  @EnvironmentObject private var auth: Auth
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.modelContext) private var modelContext
  @State private var moviesPlanToWatchCount: Int = 0
  @State private var moviesDroppedCount: Int = 0
  @State private var moviesCompletedCount: Int = 0
  @State private var showsPlanToWatchCount: Int = 0
  @State private var showsCompletedCount: Int = 0
  @State private var showsHoldCount: Int = 0
  @State private var showsDroppedCount: Int = 0
  @State private var showsWatchingCount: Int = 0
  @State private var animePlanToWatchCount: Int = 0
  @State private var animeDroppedCount: Int = 0
  @State private var animeCompletedCount: Int = 0
  @State private var animeHoldCount: Int = 0
  @State private var animeWatchingCount: Int = 0
  @Environment(GlobalLoadingIndicator.self) private var globalLoadingIndicator

  var body: some View {
    NavigationStack {
      List {
        Section(header: Text("Movies")) {

          NavigationLink(destination: MovieListView(status: "plantowatch")) {
            HStack {
              Image(systemName: "star")
                .bold()
                .foregroundColor(colorScheme == .dark ? Color.yellow : Color.yellow.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.yellow.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("Plan to Watch")

              Spacer()

              Text("\(moviesPlanToWatchCount)")
                .foregroundColor(.gray)
                .font(.subheadline)
            }
          }

          NavigationLink(destination: MovieListView(status: "dropped")) {
            HStack {
              Image(systemName: "hand.thumbsdown")
                .bold()
                .foregroundColor(colorScheme == .dark ? Color.red : Color.red.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("Dropped")

              Spacer()

              Text("\(moviesDroppedCount)")
                .foregroundColor(.gray)
                .font(.subheadline)
            }
          }

          NavigationLink(destination: MovieListView(status: "completed")) {
            HStack {
              Image(systemName: "checkmark.circle")
                .bold()
                .foregroundColor(colorScheme == .dark ? Color.green : Color.green.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("Completed")

              Spacer()

              Text("\(moviesCompletedCount)")
                .foregroundColor(.gray)
                .font(.subheadline)
            }
          }
        }

        Section(header: Text("TV Shows")) {
          NavigationLink(destination: TVListView(status: "plantowatch")) {
            HStack {
              Image(systemName: "star")
                .bold()
                .foregroundColor(colorScheme == .dark ? Color.yellow : Color.yellow.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.yellow.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("Plan to Watch")

              Spacer()

              Text("\(showsPlanToWatchCount)")
                .foregroundColor(.gray)
                .font(.subheadline)
            }
          }

          NavigationLink(destination: TVListView(status: "completed")) {
            HStack {
              Image(systemName: "checkmark.circle")
                .bold()
                .foregroundColor(colorScheme == .dark ? Color.green : Color.green.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("Completed")

              Spacer()

              Text("\(showsCompletedCount)")
                .foregroundColor(.gray)
                .font(.subheadline)
            }
          }

          NavigationLink(destination: TVListView(status: "hold")) {
            HStack {
              Image(systemName: "pause")
                .bold()
                .foregroundColor(colorScheme == .dark ? Color.gray : Color.gray.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("On Hold")

              Spacer()

              Text("\(showsHoldCount)")
                .foregroundColor(.gray)
                .font(.subheadline)
            }
          }

          NavigationLink(destination: TVListView(status: "dropped")) {
            HStack {
              Image(systemName: "hand.thumbsdown")
                .bold()
                .foregroundColor(colorScheme == .dark ? Color.red : Color.red.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("Dropped")

              Spacer()

              Text("\(showsDroppedCount)")
                .foregroundColor(.gray)
                .font(.subheadline)
            }
          }

          NavigationLink(destination: TVListView(status: "watching")) {
            HStack {
              Image(systemName: "popcorn")
                .bold()
                .foregroundColor(colorScheme == .dark ? Color.purple : Color.purple.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.purple.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("Watching")

              Spacer()

              Text("\(showsWatchingCount)")
                .foregroundColor(.gray)
                .font(.subheadline)
            }
          }

        }

        Section(header: Text("Anime")) {

          NavigationLink(destination: AnimeListView(status: "plantowatch")) {
            HStack {
              Image(systemName: "star")
                .bold()
                .foregroundColor(colorScheme == .dark ? Color.yellow : Color.yellow.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.yellow.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("Plan to Watch")

              Spacer()

              Text("\(animePlanToWatchCount)")
                .foregroundColor(.gray)
                .font(.subheadline)
            }
          }

          NavigationLink(destination: AnimeListView(status: "dropped")) {
            HStack {
              Image(systemName: "hand.thumbsdown")
                .bold()
                .foregroundColor(colorScheme == .dark ? Color.red : Color.red.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("Dropped")

              Spacer()

              Text("\(animeDroppedCount)")
                .foregroundColor(.gray)
                .font(.subheadline)
            }
          }

          NavigationLink(destination: AnimeListView(status: "completed")) {
            HStack {
              Image(systemName: "checkmark.circle")
                .bold()
                .foregroundColor(colorScheme == .dark ? Color.green : Color.green.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("Completed")

              Spacer()

              Text("\(animeCompletedCount)")
                .foregroundColor(.gray)
                .font(.subheadline)
            }
          }

          NavigationLink(destination: AnimeListView(status: "hold")) {
            HStack {
              Image(systemName: "pause")
                .bold()
                .foregroundColor(colorScheme == .dark ? Color.gray : Color.gray.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("On Hold")

              Spacer()

              Text("\(animeHoldCount)")
                .foregroundColor(.gray)
                .font(.subheadline)
            }
          }

          NavigationLink(destination: AnimeListView(status: "watching")) {
            HStack {
              Image(systemName: "popcorn")
                .bold()
                .foregroundColor(colorScheme == .dark ? Color.purple : Color.purple.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.purple.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("Watching")

              Spacer()

              Text("\(animeWatchingCount)")
                .foregroundColor(.gray)
                .font(.subheadline)
            }
          }

        }
      }
      .listStyle(.insetGrouped)
      .navigationTitle("Lists")
      .onAppear {
        Task {
          getCounts()
        }
      }
      .onChange(of: globalLoadingIndicator.isSyncing) {
        Task {
          getCounts()
        }
      }
      .refreshable {
        Task {
          if !auth.simklAccessToken.isEmpty {
            globalLoadingIndicator.startSync()
            await syncLatestActivities(
              auth.simklAccessToken, modelContainer: modelContext.container)
            getCounts()
            globalLoadingIndicator.stopSync()
          }
        }
      }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          if globalLoadingIndicator.isSyncing {
            ProgressView()
          }
        }
      }
    }
  }

  func getCounts() {
    moviesPlanToWatchCount =
      (try? modelContext.fetchCount(
        FetchDescriptor<V1.SDMovies>(
          predicate: #Predicate { movie in
            movie.status == "plantowatch"
          }
        ))) ?? 0

    moviesDroppedCount =
      (try? modelContext.fetchCount(
        FetchDescriptor<V1.SDMovies>(
          predicate: #Predicate { movie in
            movie.status == "dropped"
          }
        ))) ?? 0

    moviesCompletedCount =
      (try? modelContext.fetchCount(
        FetchDescriptor<V1.SDMovies>(
          predicate: #Predicate { movie in
            movie.status == "completed"
          }
        ))) ?? 0

    showsPlanToWatchCount =
      (try? modelContext.fetchCount(
        FetchDescriptor<V1.SDShows>(
          predicate: #Predicate { show in
            show.status == "plantowatch"
          }
        ))) ?? 0

    showsCompletedCount =
      (try? modelContext.fetchCount(
        FetchDescriptor<V1.SDShows>(
          predicate: #Predicate { show in
            show.status == "completed"
          }
        ))) ?? 0

    showsHoldCount =
      (try? modelContext.fetchCount(
        FetchDescriptor<V1.SDShows>(
          predicate: #Predicate { show in
            show.status == "hold"
          }
        ))) ?? 0

    showsDroppedCount =
      (try? modelContext.fetchCount(
        FetchDescriptor<V1.SDShows>(
          predicate: #Predicate { show in
            show.status == "dropped"
          }
        ))) ?? 0

    showsWatchingCount =
      (try? modelContext.fetchCount(
        FetchDescriptor<V1.SDShows>(
          predicate: #Predicate { show in
            show.status == "watching"
          }
        ))) ?? 0

    animePlanToWatchCount =
      (try? modelContext.fetchCount(
        FetchDescriptor<V1.SDAnimes>(
          predicate: #Predicate { anime in
            anime.status == "plantowatch"
          }
        ))) ?? 0

    animeDroppedCount =
      (try? modelContext.fetchCount(
        FetchDescriptor<V1.SDAnimes>(
          predicate: #Predicate { anime in
            anime.status == "dropped"
          }
        ))) ?? 0

    animeCompletedCount =
      (try? modelContext.fetchCount(
        FetchDescriptor<V1.SDAnimes>(
          predicate: #Predicate { anime in
            anime.status == "completed"
          }
        ))) ?? 0

    animeHoldCount =
      (try? modelContext.fetchCount(
        FetchDescriptor<V1.SDAnimes>(
          predicate: #Predicate { anime in
            anime.status == "hold"
          }
        ))) ?? 0

    animeWatchingCount =
      (try? modelContext.fetchCount(
        FetchDescriptor<V1.SDAnimes>(
          predicate: #Predicate { anime in
            anime.status == "watching"
          }
        ))) ?? 0
  }
}
