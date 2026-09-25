//
//  GlassBackground.swift
//  simalytics
//
//  Created by Muse Code on 9/25/26.
//

import SwiftUI

/// Frosted pill background that tracks the system Liquid Glass look.
///
/// iOS 26+ renders a real glass effect; earlier releases fall back to the
/// same regular material the app used before, so nothing changes there.
struct GlassBackground: ViewModifier {
  var cornerRadius: CGFloat = 8

  func body(content: Content) -> some View {
    Group {
      if #available(iOS 26, *) {
        content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
      } else {
        content.background(.regularMaterial, in: .rect(cornerRadius: cornerRadius))
      }
    }
  }
}

extension View {
  func glassBackground(cornerRadius: CGFloat = 8) -> some View {
    modifier(GlassBackground(cornerRadius: cornerRadius))
  }
}
