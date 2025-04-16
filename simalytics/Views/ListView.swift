//
//  ListView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/1/25.
//

import SwiftData
import SwiftUI

struct ListView: View {
  @Environment(\.colorScheme) var colorScheme
  @Environment(\.modelContext) private var modelContext
  @State private var moviesPlanToWatchCount: Int = 0

  var body: some View {
    NavigationView {
      List {
        Section(header: Text("Movies")) {
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

            Image(systemName: "chevron.right")
              .foregroundColor(.gray)
              .font(.system(size: 14))
          }
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

            Text("1")
              .foregroundColor(.gray)
              .font(.subheadline)

            Image(systemName: "chevron.right")
              .foregroundColor(.gray)
              .font(.system(size: 14))
          }
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

            Text("1")
              .foregroundColor(.gray)
              .font(.subheadline)

            Image(systemName: "chevron.right")
              .foregroundColor(.gray)
              .font(.system(size: 14))
          }
        }
      }
      .listStyle(.insetGrouped)
      .navigationTitle("Lists")
      .onAppear {
        Task {
          moviesPlanToWatchCount = (try? modelContext.fetchCount(FetchDescriptor<V1.SDMovies>())) ?? 0
        }
      }
    }
  }
}
