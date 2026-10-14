import Testing

@testable import Simalytics

struct RatingSelectionTests {
  @Test(arguments: 1...10, [320.0, 366.0, 440.0])
  func eachTenStarPositionSelectsItsRating(star: Int, width: Double) {
    let position = (Double(star) - 0.5) * width / 10
    #expect(
      RatingSelection.value(at: position, width: width, maximum: 10, allowsHalfStars: false)
        == Double(star))
  }

  @Test(arguments: 1...10)
  func fiveStarModeKeepsHalfStarSelection(half: Int) {
    let position = (Double(half) - 0.5) * 22
    #expect(
      RatingSelection.value(at: position, width: 220, maximum: 5, allowsHalfStars: true) == Double(
        half) / 2)
  }

  @Test func edgesStayWithinTheScale() {
    #expect(RatingSelection.value(at: -1, width: 320, maximum: 10, allowsHalfStars: false) == 1)
    #expect(RatingSelection.value(at: 320, width: 320, maximum: 10, allowsHalfStars: false) == 10)
    #expect(RatingSelection.value(at: 321, width: 320, maximum: 5, allowsHalfStars: true) == 5)
    #expect(RatingSelection.value(at: 22, width: 220, maximum: 5, allowsHalfStars: true) == 1)
    #expect(RatingSelection.value(at: 0, width: 0, maximum: 10, allowsHalfStars: false) == nil)
  }
}
