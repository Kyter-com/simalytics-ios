//
//  CustomKFImage.swift
//  simalytics
//
//  Created by Nick Reisenauer on 3/12/25.
//

import Kingfisher
import SwiftUI

struct CustomKFImage: View {
  let imageUrlString: String?
  let memoryCacheOnly: Bool
  let height: CGFloat
  let width: CGFloat

  var body: some View {
    Group {
      if let imageUrlString = imageUrlString, !imageUrlString.isEmpty, let url = URL(string: imageUrlString) {
        KFImage(url)
          .fade(duration: 0.33)
          .placeholder {
            ProgressView()
          }
          .resizable()
          .serialize(as: .JPEG)
          .cacheMemoryOnly(memoryCacheOnly)
          .fromMemoryCacheOrRefresh(true)
          .memoryCacheExpiration(.days(7))
          .diskCacheExpiration(.days(30))
          .cancelOnDisappear(true)
          .aspectRatio(contentMode: .fit)
          .frame(width: width, height: height)
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
          )
      } else {
        Rectangle()
          .fill(Color(.systemGray5))
          .frame(width: width, height: height)
          .clipShape(RoundedRectangle(cornerRadius: 8))
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
          )
          .overlay(
            Image(systemName: "photo.badge.exclamationmark")
              .font(.system(size: min(width, height) * 0.4))
              .foregroundColor(.secondary)
          )
      }
    }
  }
}
