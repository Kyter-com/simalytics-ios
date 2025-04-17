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
  @Environment(GlobalLoadingIndicator.self) private var globalLoadingIndicator

  var body: some View {
    NavigationView {
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
          NavigationLink(destination: MovieListView(status: "completed")) {
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

              Text("\(showsCompletedCount)")
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
            await syncLatestActivities(auth.simklAccessToken, modelContainer: modelContext.container)
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
  }
}
