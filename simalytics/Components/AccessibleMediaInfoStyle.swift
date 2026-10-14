import SwiftUI

/// Give labels and their values the full width at accessibility text sizes.
struct AccessibleMediaInfoStyle: LabeledContentStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      configuration.label
      configuration.content
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .fixedSize(horizontal: false, vertical: true)
  }
}
