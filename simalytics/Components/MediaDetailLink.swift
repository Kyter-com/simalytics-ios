//
//  MediaDetailLink.swift
//  simalytics
//
//  Created by Muse Code on 9/25/26.
//

import SwiftUI

/// Pushes a media detail screen with a poster zoom transition.
///
/// On iOS 18+ the destination opens with a hero zoom from the tapped poster
/// (`matchedTransitionSource` + `navigationTransition(.zoom…)`). Earlier
/// releases fall back to a plain push, so the iOS 17 deployment target is
/// unaffected. Each link owns its transition namespace, so `sourceID` only
/// needs to be stable within the link itself.
struct MediaDetailLink<Destination: View, Label: View>: View {
  @Namespace private var zoom
  let sourceID: String
  let destination: () -> Destination
  let label: () -> Label

  init(
    sourceID: String,
    @ViewBuilder destination: @escaping () -> Destination,
    @ViewBuilder label: @escaping () -> Label
  ) {
    self.sourceID = sourceID
    self.destination = destination
    self.label = label
  }

  var body: some View {
    Group {
      if #available(iOS 18, *) {
        NavigationLink {
          destination()
            .navigationTransition(.zoom(sourceID: sourceID, in: zoom))
        } label: {
          label()
            .matchedTransitionSource(id: sourceID, in: zoom)
        }
      } else {
        NavigationLink(destination: destination(), label: label)
      }
    }
  }
}
