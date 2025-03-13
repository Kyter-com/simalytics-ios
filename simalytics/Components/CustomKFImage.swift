//
//  CustomKFImage.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/12/25.
//

import Kingfisher
import SwiftUI

struct CustomKFImage: View {
  let imageUrlString: String
  let memoryCacheOnly: Bool
  let height: CGFloat
  let width: CGFloat

  var body: some View {
    KFImage(URL(string: imageUrlString)!)
      .fade(duration: 0.33)
      .placeholder {
        ProgressView()
      }
      .resizable()
      .serialize(as: .JPEG)
      .cacheMemoryOnly(memoryCacheOnly)
      .memoryCacheExpiration(.days(7))
      .diskCacheExpiration(.days(30))
      .aspectRatio(contentMode: .fit)
      .frame(width: width, height: height)
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
      )
  }
}
