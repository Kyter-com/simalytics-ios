//
//  ListView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/1/25.
//

import SwiftData
import SwiftUI

struct ListView: View {
  @State private var counts = LibraryCounts()
  @Environment(Auth.self) private var auth
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.modelContext) private var modelContext
  @AppStorage("hideAnime") private var hideAnime = false
  @Environment(GlobalLoadingIndicator.self) private var globalLoadingIndicator

  var body: some View {
    NavigationStack {
      List {
        Section(header: Text("Movies")) {

          NavigationLink(destination: MovieListView(status: "plantowatch")) {
            HStack {
              Image(systemName: "star")
                .bold()
                .foregroundStyle(colorScheme == .dark ? Color.yellow : Color.yellow.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.yellow.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("Plan to Watch")

              Spacer()

              Text("\(counts.moviesPlanToWatchCount)")
                .foregroundStyle(.gray)
                .font(.subheadline)
            }
          }

          NavigationLink(destination: MovieListView(status: "completed")) {
            HStack {
              Image(systemName: "checkmark.circle")
                .bold()
                .foregroundStyle(colorScheme == .dark ? Color.green : Color.green.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("Completed")

              Spacer()

              Text("\(counts.moviesCompletedCount)")
                .foregroundStyle(.gray)
                .font(.subheadline)
            }
          }

          NavigationLink(destination: MovieListView(status: "dropped")) {
            HStack {
              Image(systemName: "hand.thumbsdown")
                .bold()
                .foregroundStyle(colorScheme == .dark ? Color.red : Color.red.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("Dropped")

              Spacer()

              Text("\(counts.moviesDroppedCount)")
                .foregroundStyle(.gray)
                .font(.subheadline)
            }
          }
        }

        Section(header: Text("TV Shows")) {
          NavigationLink(destination: TVListView(status: "plantowatch")) {
            HStack {
              Image(systemName: "star")
                .bold()
                .foregroundStyle(colorScheme == .dark ? Color.yellow : Color.yellow.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.yellow.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("Plan to Watch")

              Spacer()

              Text("\(counts.showsPlanToWatchCount)")
                .foregroundStyle(.gray)
                .font(.subheadline)
            }
          }

          NavigationLink(destination: TVListView(status: "completed")) {
            HStack {
              Image(systemName: "checkmark.circle")
                .bold()
                .foregroundStyle(colorScheme == .dark ? Color.green : Color.green.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("Completed")

              Spacer()

              Text("\(counts.showsCompletedCount)")
                .foregroundStyle(.gray)
                .font(.subheadline)
            }
          }

          NavigationLink(destination: TVListView(status: "hold")) {
            HStack {
              Image(systemName: "pause")
                .bold()
                .foregroundStyle(colorScheme == .dark ? Color.gray : Color.gray.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("On Hold")

              Spacer()

              Text("\(counts.showsHoldCount)")
                .foregroundStyle(.gray)
                .font(.subheadline)
            }
          }

          NavigationLink(destination: TVListView(status: "dropped")) {
            HStack {
              Image(systemName: "hand.thumbsdown")
                .bold()
                .foregroundStyle(colorScheme == .dark ? Color.red : Color.red.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("Dropped")

              Spacer()

              Text("\(counts.showsDroppedCount)")
                .foregroundStyle(.gray)
                .font(.subheadline)
            }
          }

          NavigationLink(destination: TVListView(status: "watching")) {
            HStack {
              Image(systemName: "popcorn")
                .bold()
                .foregroundStyle(colorScheme == .dark ? Color.purple : Color.purple.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.purple.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("Watching")

              Spacer()

              Text("\(counts.showsWatchingCount)")
                .foregroundStyle(.gray)
                .font(.subheadline)
            }
          }

        }

        if !hideAnime {
          Section(header: Text("Anime")) {

            NavigationLink(destination: AnimeListView(status: "plantowatch")) {
            HStack {
              Image(systemName: "star")
                .bold()
                .foregroundStyle(colorScheme == .dark ? Color.yellow : Color.yellow.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.yellow.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("Plan to Watch")

              Spacer()

              Text("\(counts.animePlanToWatchCount)")
                .foregroundStyle(.gray)
                .font(.subheadline)
            }
          }

          NavigationLink(destination: AnimeListView(status: "completed")) {
            HStack {
              Image(systemName: "checkmark.circle")
                .bold()
                .foregroundStyle(colorScheme == .dark ? Color.green : Color.green.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("Completed")

              Spacer()

              Text("\(counts.animeCompletedCount)")
                .foregroundStyle(.gray)
                .font(.subheadline)
            }
          }

          NavigationLink(destination: AnimeListView(status: "hold")) {
            HStack {
              Image(systemName: "pause")
                .bold()
                .foregroundStyle(colorScheme == .dark ? Color.gray : Color.gray.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("On Hold")

              Spacer()

              Text("\(counts.animeHoldCount)")
                .foregroundStyle(.gray)
                .font(.subheadline)
            }
          }

          NavigationLink(destination: AnimeListView(status: "dropped")) {
            HStack {
              Image(systemName: "hand.thumbsdown")
                .bold()
                .foregroundStyle(colorScheme == .dark ? Color.red : Color.red.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.red.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("Dropped")

              Spacer()

              Text("\(counts.animeDroppedCount)")
                .foregroundStyle(.gray)
                .font(.subheadline)
            }
          }

          NavigationLink(destination: AnimeListView(status: "watching")) {
            HStack {
              Image(systemName: "popcorn")
                .bold()
                .foregroundStyle(colorScheme == .dark ? Color.purple : Color.purple.darker())
                .frame(width: 30, height: 30)
                .background(
                  RoundedRectangle(cornerRadius: 8)
                    .fill(Color.purple.opacity(0.2))
                )
                .padding(.trailing, 5)

              Text("Watching")

              Spacer()

              Text("\(counts.animeWatchingCount)")
                .foregroundStyle(.gray)
                .font(.subheadline)
            }
          }

          }
        }
      }
      .listStyle(.insetGrouped)
      .navigationTitle("Lists")
      // Show the saved library immediately, then refresh when a sync finishes.
      // Launch starts a sync right away, so waiting for it would show zeros.
      .task(id: globalLoadingIndicator.isSyncing) {
        await getCounts()
      }
      .refreshable {
        if !auth.simklAccessToken.isEmpty {
          globalLoadingIndicator.startSync()
          await syncLatestActivities(
            auth.simklAccessToken, modelContainer: modelContext.container)
          globalLoadingIndicator.stopSync()
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

  private func getCounts() async {
    do {
      let refreshed = try await LibraryCounts.fetch(from: modelContext.container)
      try Task.checkCancellation()
      counts = refreshed
    } catch {
      if !isSimklCancellationError(error) { reportError(error) }
    }
  }
}
