//
//  AcknowledgementsView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 1/4/26.
//

import SwiftUI

struct Dependency: Identifiable {
  let id = UUID()
  let name: String
  let author: String
  let url: String
  let license: String
}

struct AcknowledgementsView: View {
  private let dependencies: [Dependency] = [
    Dependency(
      name: "Kingfisher",
      author: "onevcat",
      url: "https://github.com/onevcat/Kingfisher",
      license: "MIT"
    ),
    Dependency(
      name: "Sentry",
      author: "Sentry",
      url: "https://github.com/getsentry/sentry-cocoa",
      license: "MIT"
    ),
    Dependency(
      name: "SimpleKeychain",
      author: "Auth0",
      url: "https://github.com/auth0/SimpleKeychain",
      license: "MIT"
    ),
  ]

  var body: some View {
    List {
      Section {
        ForEach(dependencies) { dependency in
          Button(action: {
            if let url = URL(string: dependency.url) {
              UIApplication.shared.open(url)
            }
          }) {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text(dependency.name)
                  .font(.headline)
                  .foregroundColor(.primary)
                Text(dependency.author)
                  .font(.subheadline)
                  .foregroundColor(.secondary)
                Text(dependency.license)
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
              Spacer()
              Image(systemName: "arrow.up.forward")
                .font(.footnote)
                .foregroundColor(Color(UIColor.tertiaryLabel))
            }
          }
        }
      } header: {
        Text("Open Source Libraries")
      } footer: {
        Text("This app is built with the help of these amazing open source projects.")
      }
    }
    .navigationTitle("Acknowledgements")
    .navigationBarTitleDisplayMode(.inline)
  }
}
