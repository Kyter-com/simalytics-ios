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
    let processor = DownsamplingImageProcessor(size: CGSize(width: width * UIScreen.main.scale, height: height * UIScreen.main.scale))
    // Using .scale ensures that we downsample to the exact number of pixels for the display,
    // which is important for image quality on Retina displays.

    Group {
      if let imageUrlString = imageUrlString, !imageUrlString.isEmpty, let url = URL(string: imageUrlString) {
        KFImage(url)
          .processor(processor) // Add the DownsamplingImageProcessor
          .fade(duration: 0.33)
          .placeholder {
            ProgressView()
              .frame(width: width, height: height) // Ensure placeholder respects frame
          }
          .resizable()
          // .serialize(as: .JPEG) // Consider if this is always needed.
          // If source images are often PNGs with transparency that needs preserving, this could be an issue.
          // However, for typical photos/posters, JPEG is fine for cache size. Assuming it's intentional.
          .cacheMemoryOnly(memoryCacheOnly)
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
