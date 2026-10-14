import SwiftUI

struct MediaActionButtons: View {
  let canAddMemo: Bool
  let addMemo: () -> Void
  let whereToWatch: () -> Void

  var body: some View {
    Group {
      if #available(iOS 26, *) {
        GlassEffectContainer(spacing: 12) {
          actionLayout
        }
        .buttonStyle(.glass)
      } else {
        actionLayout.buttonStyle(.bordered)
      }
    }
    .controlSize(.large)
    .padding(.horizontal)
    .padding(.top, 8)
  }

  private var actionLayout: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 12) { buttons }
      VStack(spacing: 12) { buttons }
    }
  }

  @ViewBuilder private var buttons: some View {
    if canAddMemo {
      Button("Add Memo", systemImage: "square.and.pencil", action: addMemo)
    }
    Button("Where to Watch", systemImage: "sparkles.tv", action: whereToWatch)
  }
}
