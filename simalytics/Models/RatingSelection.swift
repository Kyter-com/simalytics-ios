import Foundation

enum RatingSelection {
  /// Maps the continuous rating strip to whole stars, or each half in five-star mode.
  static func value(
    at position: CGFloat, width: CGFloat, maximum: Int, allowsHalfStars: Bool
  ) -> Double? {
    guard width.isFinite, width > 0, position.isFinite, maximum > 0 else { return nil }
    let subdivisions = allowsHalfStars ? 2.0 : 1.0
    let count = Double(maximum) * subdivisions
    let index = floor(min(max(position / width, 0), 1) * count)
    return min(index + 1, count) / subdivisions
  }
}
