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
  private let parallaxImageHeight: CGFloat = 250 // Increased height for parallax buffer

  private func getWsrvUrl(fanartPath: String) -> URL? {
    let screenScale = UIScreen.main.scale
    let screenWidth = UIScreen.main.bounds.width

    // Request images at a slightly higher resolution than needed for crispness, especially with parallax
    let requestedWidth = Int(screenWidth * screenScale)
    let requestedHeight = Int(parallaxImageHeight * screenScale)

    // Original image URL (ensure this base URL is correct for fanart)
    // Assuming SIMKL_CDN_URL is "https://wsrv.nl/?url=https://simkl.in"
    // and fanartPath is something like "c1/12345/c1234567.jpg"
    // The fanart itself might not need the "_mobile.jpg" if wsrv.nl is resizing it.
    // Let's assume the fanart string is just the path like "c1/12345/c1234567" and .jpg is standard.
    // If fanart already includes ".jpg" or similar, adjust accordingly.
    // For Simkl, fanart URLs are typically like /fanart/{fanart_id_path}/{fanart_id_filename}.jpg
    // The initial URL was SIMKL_CDN_URL + "/fanart/" + fanart + "_mobile.jpg"
    // SIMKL_CDN_URL = "https://wsrv.nl/?url=https://simkl.in"
    // So, the full image path for wsrv.nl's url param is "https://simkl.in/fanart/\(fanart)_mobile.jpg"

    let originalImageUrlString = "https://simkl.in/fanart/\(fanartPath)_mobile.jpg"
    guard let encodedOriginalImageUrl = originalImageUrlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
      return nil
    }

    let wsrvBaseUrl = "https://wsrv.nl/"
    // Parameters:
    // url: the original image URL
    // w: target width
    // h: target height
    // fit: cover (ensures the image covers the dimensions, cropping if necessary)
    // q: quality (e.g., 80)
    // output: specify format if desired (e.g., jpg, webp). wsrv.nl handles negotiation.
    // weof: Will try to optimize the image without affecting quality and without changing the image format.

    let urlString = "\(wsrvBaseUrl)?url=\(encodedOriginalImageUrl)&w=\(requestedWidth)&h=\(requestedHeight)&fit=cover&q=80&weof"

    return URL(string: urlString)
  }

  var body: some View {
    if let fanart = fanart, let imageUrl = getWsrvUrl(fanartPath: fanart) {
      GeometryReader { reader in
        let minY = reader.frame(in: .global).minY
        // The visible height of the parallax container is 150.
        // The actual image view can be taller (parallaxImageHeight) and offset.
        let currentImageHeight = minY > 0 ? minY + 150 : 150

        // Only render and manipulate if the view is somewhat visible
        // The -150 here refers to the top of the GeometryReader container.
        // The image itself is taller (parallaxImageHeight), so its own minY will be different.
        if minY > -parallaxImageHeight { // Adjust condition based on actual image height and desired behavior
          KFImage(imageUrl)
            .placeholder {
              Rectangle()
                .fill(Color.gray.opacity(0.3)) // Simple placeholder
                .frame(width: UIScreen.main.bounds.width, height: currentImageHeight)
            }
            // Disk caching is enabled by default if .cacheMemoryOnly(false) or not specified.
            // .cacheMemoryOnly(false) // Explicitly ensure disk cache if needed, but default is usually sufficient
            .memoryCacheExpiration(.days(7)) // Keep default or adjust
            .diskCacheExpiration(.days(30))   // Keep default or adjust
            .fade(duration: 0.25) // Slightly longer fade for smoother appearance
            .resizable()
            .aspectRatio(contentMode: .fill) // Should be covered by wsrv.nl's fit=cover, but good to have.
            .offset(y: -minY) // This creates the parallax effect
            .frame(width: UIScreen.main.bounds.width, height: currentImageHeight)
            // The image itself is taller to allow for parallax scrolling.
            // We ensure its frame matches the dynamic currentImageHeight.
        }
      }
      .frame(height: 150) // This is the fixed height of the parallax container view
    } else {
      // Fallback if fanart is nil or URL construction fails
      Rectangle()
        .fill(Color.gray.opacity(0.1))
        .frame(height: 150)
        // Optionally, add an icon or message here
    }
  }
}
