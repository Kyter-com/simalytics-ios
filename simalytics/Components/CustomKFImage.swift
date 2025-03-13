//
//  CustomKFImage.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/12/25.
//

import Kingfisher
import SwiftUI

struct CustomKFImage: View {
  let url: URL
  let memoryCacheOnly: Bool = true
  let height: CGFloat
  let width: CGFloat

  var body: some View {
    customKFImage(url)
      .fade(duration: 0.33)
      .placeholder {
        ProgressView()
      }
      .resizable()
      .serialize(as: .JPEG)
      .aspectRatio(contentMode: .fit)
      .frame(width: width, height: height)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
      )
  }

  private func customKFImage(_ url: URL) -> KFImage {
    var options: KingfisherOptionsInfo = [
      .forceTransition,
      .keepCurrentImageWhileLoading,
      .diskCacheExpiration(.days(30)),
      .memoryCacheExpiration(.days(7)),
    ]
    if memoryCacheOnly {
      options.append(.cacheMemoryOnly)
    }
    let result = KFImage(url)
    result.options = KingfisherParsedOptionsInfo(options)
    return result
  }
}
