import Foundation

/// Geometry shared by pinch, drag, double-tap, and rotation.
enum PosterViewport {
  static func boundedScale(_ scale: CGFloat) -> CGFloat {
    min(max(scale, 1), 5)
  }

  static func clampedOffset(
    _ offset: CGSize, scale: CGFloat, imageSize: CGSize, viewport: CGSize
  ) -> CGSize {
    guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
    let fit = min(viewport.width / imageSize.width, viewport.height / imageSize.height)
    let maxX = max(0, (imageSize.width * fit * boundedScale(scale) - viewport.width) / 2)
    let maxY = max(0, (imageSize.height * fit * boundedScale(scale) - viewport.height) / 2)
    return CGSize(
      width: min(max(offset.width, -maxX), maxX),
      height: min(max(offset.height, -maxY), maxY))
  }
}
