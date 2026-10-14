#if DEBUG
  import SwiftUI

  /// Exercise the real back-button navigation context when validating detail layouts.
  struct ScreenshotDetailNavigation<Detail: View>: View {
    let title: String
    @ViewBuilder let detail: () -> Detail
    @State private var path = ["detail"]

    var body: some View {
      NavigationStack(path: $path) {
        List { NavigationLink("Open fixture", value: "detail") }
          .navigationTitle(title)
          .navigationBarTitleDisplayMode(.inline)
          .navigationDestination(for: String.self) { _ in detail() }
      }
    }
  }
#endif
