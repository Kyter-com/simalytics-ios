import Foundation
import Testing

@testable import Simalytics

struct PosterViewportTests {
  @Test("Zoom cannot shrink or exceed five times", arguments: [0.1, 1, 2.5, 5, 100])
  func zoomLimits(value: Double) {
    #expect((1...5).contains(PosterViewport.boundedScale(value)))
  }

  @Test("Panning reaches image edges without exposing blank space")
  func panBounds() {
    let image = CGSize(width: 600, height: 900)
    let viewport = CGSize(width: 400, height: 800)
    let requested = CGSize(width: 1_000, height: -1_000)
    #expect(
      PosterViewport.clampedOffset(requested, scale: 1, imageSize: image, viewport: viewport)
        == .zero)
    #expect(
      PosterViewport.clampedOffset(requested, scale: 2, imageSize: image, viewport: viewport)
        == CGSize(width: 200, height: -200))
    let landscape = CGSize(width: 800, height: 400)
    #expect(
      PosterViewport.clampedOffset(requested, scale: 2, imageSize: image, viewport: landscape)
        == CGSize(width: 0, height: -200))
  }
}
