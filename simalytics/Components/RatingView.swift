//
//  RatingView.swift
//  FeedApp
//
//  Created by Devendra Kumar on 24/04/23.
//
// https://github.com/devendrabhumca12/RatingView/blob/main/RatingView/RatingView.swift

import SwiftUI

public enum StarRounding: Int {
  case roundToHalfStar = 0
  case ceilToHalfStar = 1
  case floorToHalfStar = 2
  case roundToFullStar = 3
  case ceilToFullStar = 4
  case floorToFullStar = 5
}

struct RatingView: View {
  let maxRating: Int
  let rating: Double
  let onSelect: (Double) -> Void
  let starColor: Color
  let starRounding: StarRounding

  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.layoutDirection) private var layoutDirection
  @ScaledMetric(relativeTo: .body) private var scaledSize: CGFloat = 20
  private let fullStarImage: Image = Image(systemName: "star.fill")
  private let halfStarImage: Image = Image(systemName: "star.lefthalf.fill")
  private let emptyStarImage: Image = Image(systemName: "star")

  @State private var selectedStar: Int?

  init(
    maxRating: Int, rating: Double, starColor: Color = .blue,
    starRounding: StarRounding = .floorToFullStar, size: CGFloat = 20,
    onSelect: @escaping (Double) -> Void
  ) {
    self.maxRating = maxRating
    self.rating = rating
    self.onSelect = onSelect
    self.starColor = starColor
    self.starRounding = starRounding
    _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: .body)
  }

  private var allowsHalfStars: Bool {
    [.roundToHalfStar, .ceilToHalfStar, .floorToHalfStar].contains(starRounding)
  }

  var body: some View {
    // One adjustable control, with a full-height touch surface. Ten-star mode
    // stays on one line even when ten separate 44-point buttons would not fit.
    GeometryReader { geometry in
      let segmentWidth = geometry.size.width / CGFloat(maxRating)
      HStack(spacing: 0) {
        ForEach(1...maxRating, id: \.self) { index in
          starImageView(index: index, size: min(scaledSize, max(1, segmentWidth - 6)))
            .foregroundStyle(starColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .contentShape(.rect)
      .onTapGesture { location in
        let x = layoutDirection == .rightToLeft ? geometry.size.width - location.x : location.x
        guard
          let value = RatingSelection.value(
            at: x, width: geometry.size.width, maximum: maxRating, allowsHalfStars: allowsHalfStars
          )
        else { return }
        updateRating(to: value, star: Int(value.rounded(.up)))
      }
    }
    .frame(height: max(44, scaledSize + 8))
    .frame(maxWidth: CGFloat(maxRating) * max(44, scaledSize + 8))
    .task(id: selectedStar) {
      guard selectedStar != nil else { return }
      do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
      selectedStar = nil
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Your rating")
    .accessibilityValue("\(rating.formatted()) out of \(maxRating)")
    .accessibilityAdjustableAction { direction in
      guard isEnabled else { return }
      let step = allowsHalfStars ? 0.5 : 1.0
      switch direction {
      case .increment: onSelect(min(Double(maxRating), rating + step))
      case .decrement: onSelect(max(0, rating - step))
      @unknown default: break
      }
    }
    .accessibilityAction(named: "Remove rating") {
      if isEnabled { onSelect(0) }
    }
  }

  private func starImageView(index: Int, size: CGFloat) -> some View {
    let iFloat = Double(index)
    let image: Image
    switch starRounding {
    case .roundToHalfStar:
      image =
        rating >= iFloat - 0.25
        ? fullStarImage : (rating >= iFloat - 0.75 ? halfStarImage : emptyStarImage)
    case .ceilToHalfStar:
      image =
        rating > iFloat - 0.5
        ? fullStarImage : (rating > iFloat - 1 ? halfStarImage : emptyStarImage)
    case .floorToHalfStar:
      image =
        rating >= iFloat
        ? fullStarImage : (rating >= iFloat - 0.5 ? halfStarImage : emptyStarImage)
    case .roundToFullStar:
      image = rating >= iFloat - 0.5 ? fullStarImage : emptyStarImage
    case .ceilToFullStar:
      image = rating > iFloat - 1 ? fullStarImage : emptyStarImage
    case .floorToFullStar:
      image = rating >= iFloat ? fullStarImage : emptyStarImage
    }
    return
      image
      .resizable()
      .aspectRatio(contentMode: .fit)
      .frame(width: size, height: size)
      .scaleEffect(selectedStar == index && !reduceMotion ? 1.2 : 1)
      .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: selectedStar)
  }

  private func updateRating(to value: Double, star index: Int) {
    guard isEnabled else { return }
    onSelect(rating == value ? 0 : value)

    guard !reduceMotion else { return }

    selectedStar = index
  }
}
