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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading)
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
              ForEach(free, id: \.provider_id) { option in
                VStack {
                  CustomKFImage(
                    imageUrlString: "https://media.themoviedb.org/t/p/original/\(option.logo_path ?? "")",
                    memoryCacheOnly: true,
                    height: 50,
                    width: 50
                  )
                }
              }
            }
            .padding([.leading, .trailing, .bottom])
          }
        }

        if let flatrate = justWatchListings?.flatrate, !flatrate.isEmpty {
          Text("Stream")
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading)
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
              ForEach(flatrate, id: \.provider_id) { option in
                VStack {
                  CustomKFImage(
                    imageUrlString: "https://media.themoviedb.org/t/p/original/\(option.logo_path ?? "")",
                    memoryCacheOnly: true,
                    height: 50,
                    width: 50
                  )
                }
              }
            }
            .padding([.leading, .trailing, .bottom])
          }
        }

        if let buy = justWatchListings?.buy, !buy.isEmpty {
          Text("Buy")
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading)
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
              ForEach(buy, id: \.provider_id) { option in
                VStack {
                  CustomKFImage(
                    imageUrlString: "https://media.themoviedb.org/t/p/original/\(option.logo_path ?? "")",
                    memoryCacheOnly: true,
                    height: 50,
                    width: 50
                  )
                }
              }
            }
            .padding([.leading, .trailing, .bottom])
          }
        }

        Spacer()
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
