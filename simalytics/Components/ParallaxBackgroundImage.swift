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

  var body: some View {
    if let fanart = fanart {
      GeometryReader { reader in
        let minY = reader.frame(in: .global).minY
        let height = minY > 0 ? minY + 150 : 150

        if minY > -150 {
          KFImage(
            URL(string: "\(SIMKL_CDN_URL)/fanart/\(fanart)_mobile.jpg")
          )
          .serialize(as: .JPEG)
          .cacheMemoryOnly(true)
          .memoryCacheExpiration(.days(7))
          .fade(duration: 0.10)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .offset(y: -minY)
          .frame(width: UIScreen.main.bounds.width, height: height)
        }
      }
      .frame(height: 150)
    }
  }
}
