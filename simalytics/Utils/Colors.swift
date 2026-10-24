//
//  Colors.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/27/25.
//

import SwiftUI

extension Color {
  /// `Color(hex: 0xE5484D)`
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255)
  }

  func darker(by percentage: CGFloat = 30.0) -> Color {
    return self.adjust(by: -1 * abs(percentage))
  }

  func adjust(by percentage: CGFloat = 30.0) -> Color {
    let uiColor = UIColor(self)
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
    return Color(
      red: min(r + percentage / 100, 1.0),
      green: min(g + percentage / 100, 1.0),
      blue: min(b + percentage / 100, 1.0),
      opacity: Double(a)
    )
  }
}
