import SwiftUI

struct EpisodeSectionHeader: View {
  let groups: [EpisodeListGroup]
  @Binding var selection: Int
  let watched: Int
  let total: Int
  let canJump: Bool
  let jump: () -> Void
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      let layout =
        dynamicTypeSize.isAccessibilitySize
        ? AnyLayout(VStackLayout(alignment: .leading))
        : AnyLayout(HStackLayout())
      layout {
        Text("Episodes")
          .font(.title2.bold())
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityAddTraits(.isHeader)
        Menu {
          Picker("Episode group", selection: $selection) {
            ForEach(groups) { group in
              Text(group.title).tag(group.id)
            }
          }
          .pickerStyle(.inline)
        } label: {
          HStack(spacing: 6) {
            Text(groups.first { $0.id == selection }?.title ?? "Select episodes")
              .fixedSize(horizontal: false, vertical: true)
            Image(systemName: "chevron.up.chevron.down")
              .imageScale(.small)
          }
          .frame(minHeight: 44, alignment: .leading)
        }
        .layoutPriority(1)
        .accessibilityLabel("Episode group")
        .accessibilityValue(groups.first { $0.id == selection }?.title ?? "")
        .accessibilityIdentifier("episode-group-picker")
      }
      layout {
        Text("\(watched) of \(total) watched")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          .monospacedDigit()
          .frame(maxWidth: .infinity, alignment: .leading)
        Button(action: jump) {
          Label("Next unwatched", systemImage: "arrow.down.to.line")
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .disabled(!canJump)
        .accessibilityIdentifier("episode-jump-next")
      }
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
    .background(.background)
    .overlay(alignment: .bottom) { Divider() }
  }
}
