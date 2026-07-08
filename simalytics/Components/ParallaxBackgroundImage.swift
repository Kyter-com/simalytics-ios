//
//  ParallaxBackgroundImage.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/31/25.
//

import Kingfisher
import SwiftUI

struct ParallaxBackgroundImage: View {
  var fanart: String?

  private static let bypassURLCache = AnyModifier { request in
    var request = request
    request.cachePolicy = .reloadIgnoringLocalCacheData
    return request
  }

  var body: some View {
    if let fanart = fanart {
      GeometryReader { reader in
        let minY = reader.frame(in: .global).minY
        let height = minY > 0 ? minY + 150 : 150

        if minY > -150 {
          KFImage(
            URL(string: "\(SIMKL_CDN_URL)/fanart/\(fanart)_mobile.jpg")
          )
          .requestModifier(Self.bypassURLCache)
          .serialize(as: .JPEG)
          .cacheMemoryOnly(true)
          .fromMemoryCacheOrRefresh(true)
          .memoryCacheExpiration(.days(7))
          .fade(duration: 0.10)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: reader.size.width, height: height)
          .clipped()
          // Offset AFTER clipping so the stretched banner still covers the
          // area behind the transparent nav bar. Clipping before the offset
          // (the previous order) trimmed that coverage and exposed a white bar.
          .offset(y: -minY)
          .accessibilityHidden(true)
        }
      }
      .frame(height: 150)
    } else {
      Spacer()
    }
  }
}

// TODO: https://nilcoalescing.com/blog/StretchyHeaderInSwiftUI/?utm_source=substack&utm_medium=email
