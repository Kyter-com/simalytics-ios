//
//  JustWatchView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 5/27/25.
//

import SwiftUI

struct JustWatchView: View {
  @Environment(\.dismiss) var dismiss
  @Binding var justWatchListings: JustWatchListings?

  var body: some View {
    NavigationStack {
      VStack {
        if let free = justWatchListings?.free, !free.isEmpty {
          Text("Watch Free")
            .font(.headline)
          ForEach(free, id: \.provider_id) { option in
            Text(option.provider_name ?? "")
          }
        }

        if let flatrate = justWatchListings?.flatrate, !flatrate.isEmpty {
          Text("Stream")
            .font(.headline)
          ForEach(flatrate, id: \.provider_id) { option in
            Text(option.provider_name ?? "")
          }
        }

        if let buy = justWatchListings?.buy, !buy.isEmpty {
          Text("Buy")
            .font(.headline)
          ForEach(buy, id: \.provider_id) { option in
            Text(option.provider_name ?? "")
          }
        }
      }
      .navigationTitle("Where to Watch")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
          .bold()
        }
      }
    }
  }
}
