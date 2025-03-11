//
//  PulseCircle.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/10/25.
//

import SwiftUI

struct PulseCircle: View {
  @State private var isAnimating = false
  var active: Bool

  var body: some View {
    ZStack {
      Circle()
        .fill(active ? Color.green : Color.red)
        .frame(width: 10, height: 10)
      Circle()
        .fill(active ? Color.green.opacity(0.5) : Color.red.opacity(0.5))
        .frame(width: 10, height: 10)
        .scaleEffect(isAnimating ? 2.5 : 1.0)
        .opacity(isAnimating ? 0.0 : 0.6)
        .animation(
          Animation.easeInOut(duration: 1.5)
            .repeatForever(autoreverses: false),
          value: isAnimating
        )
    }
    .onAppear {
      isAnimating = true
    }
    .onDisappear {
      isAnimating = false
    }
  }
}

#Preview {
  PulseCircle(active: true)
  PulseCircle(active: false)
}
