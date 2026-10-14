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
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 2) { stars(1...maxRating) }
      VStack(spacing: 2) {
        HStack(spacing: 2) { stars(1...max(1, maxRating / 2)) }
        HStack(spacing: 2) { stars((max(1, maxRating / 2) + 1)...maxRating) }
      }
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

  private func stars(_ range: ClosedRange<Int>) -> some View {
    ForEach(range, id: \.self) { index in
      let hitSize = max(44, scaledSize + 8)
      starImageView(index: index)
        .foregroundStyle(starColor)
        .frame(width: hitSize, height: hitSize)
        .contentShape(.rect)
        // Tap location is needed to select the left half of a star.
        .onTapGesture { location in
          let value = Double(index) - (allowsHalfStars && location.x < hitSize / 2 ? 0.5 : 0)
          updateRating(to: value, star: index)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Rate \(index) out of \(maxRating)")
        .accessibilityValue("Current rating \(rating.formatted()) out of \(maxRating)")
        .accessibilityAction { updateRating(to: Double(index), star: index) }
        .accessibilityActions {
          if allowsHalfStars {
            Button("Rate \((Double(index) - 0.5).formatted()) out of \(maxRating)") {
              updateRating(to: Double(index) - 0.5, star: index)
            }
          }
        }
    }
  }

  func starImageView(index: Int) -> some View {
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
      .frame(width: scaledSize, height: scaledSize)
      .scaleEffect(selectedStar == index && !reduceMotion ? 1.2 : 1)
      .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: selectedStar)
  }

  private func updateRating(to value: Double, star index: Int) {
    guard isEnabled else { return }
    onSelect(rating == value ? 0 : value)

    guard !reduceMotion else { return }

    selectedStar = index
    Task {
      try? await Task.sleep(for: .milliseconds(250))
      await MainActor.run {
        selectedStar = nil
      }
    }
  }
}
