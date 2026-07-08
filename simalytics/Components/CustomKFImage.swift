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
  let contentMode: SwiftUI.ContentMode

  private static let bypassURLCache = AnyModifier { request in
    var request = request
    request.cachePolicy = .reloadIgnoringLocalCacheData
    return request
  }

  @Environment(\.displayScale) private var displayScale

  init(
    imageUrlString: String?,
    memoryCacheOnly: Bool,
    height: CGFloat,
    width: CGFloat,
    contentMode: SwiftUI.ContentMode = .fill
  ) {
    self.imageUrlString = imageUrlString
    self.memoryCacheOnly = memoryCacheOnly
    self.height = height
    self.width = width
    self.contentMode = contentMode
  }

  var body: some View {
    Group {
      if let imageUrlString = imageUrlString, !imageUrlString.isEmpty, let url = URL(string: imageUrlString) {
        let processorSize = CGSize(width: max(width * displayScale, 1), height: max(height * displayScale, 1))
        KFImage(url)
          .requestModifier(Self.bypassURLCache)
          .fade(duration: 0.33)
          .placeholder {
            ProgressView()
          }
          .resizable()
          .setProcessor(DownsamplingImageProcessor(size: processorSize))
          // cacheOriginalImage + a non-default processor triggers Kingfisher's
          // dual-cache path (CacheCallbackCoordinator), whose state machine
          // has no internal locking and traps on concurrent apply() calls when
          // many cells finish around the same time (e.g. layout toggle).
          .cacheMemoryOnly(memoryCacheOnly)
          .memoryCacheExpiration(.days(7))
          .diskCacheExpiration(.days(30))
          .cancelOnDisappear(true)
          .aspectRatio(contentMode: contentMode)
          .frame(width: width, height: height)
          .clipShape(.rect(cornerRadius: 8))
          .overlay {
            RoundedRectangle(cornerRadius: 8)
              .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
          }
      } else {
        Rectangle()
          .fill(.quaternary)
          .frame(width: width, height: height)
          .clipShape(.rect(cornerRadius: 8))
          .overlay {
            RoundedRectangle(cornerRadius: 8)
              .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
          }
          .overlay {
            Image(systemName: "photo.badge.exclamationmark")
              .font(.system(size: min(width, height) * 0.4))
              .foregroundStyle(.secondary)
          }
      }
    }
    .accessibilityHidden(true)
  }
}
