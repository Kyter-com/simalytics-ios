//
//  BlurView.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/27/25.
//

import SwiftUI
import UIKit

struct BlurView: UIViewRepresentable {
  var style: UIBlurEffect.Style

  func makeUIView(context: Context) -> UIVisualEffectView {
    let blurEffect = UIBlurEffect(style: style)
    let blurView = UIVisualEffectView(effect: blurEffect)
    return blurView
  }

  func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
