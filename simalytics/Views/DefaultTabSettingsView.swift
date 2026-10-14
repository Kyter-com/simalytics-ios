import SwiftUI

struct DefaultTabSettingsView: View {
  @AppStorage(AppTab.preferenceKey) private var defaultTab: AppTab = .upNext
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    Form {
      Section {
        Picker("Default Tab", selection: $defaultTab) {
          ForEach(AppTab.allCases) { tab in
            HStack(spacing: 14) {
              if !dynamicTypeSize.isAccessibilitySize {
                Image(systemName: tab.symbol)
                  .font(.title2)
                  .foregroundStyle(tab == defaultTab ? Color.accentColor : .secondary)
                  .frame(width: 44, height: 44)
                  .glassBackground(cornerRadius: 12)
                  .accessibilityHidden(true)
              }
              VStack(alignment: .leading, spacing: 4) {
                Text(tab.title)
                  .font(.headline)
                  .foregroundStyle(.primary)
                Text(tab.subtitle)
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
              }
              .padding(.vertical, 6)
            }
            .tag(tab)
          }
        }
        .pickerStyle(.inline)
        .labelsHidden()
      } header: {
        Text("Start where you want")
      } footer: {
        Text("Simalytics will open this tab the next time you launch the app.")
      }
    }
    .navigationTitle("Default Tab")
    .navigationBarTitleDisplayMode(.inline)
    .sensoryFeedback(.selection, trigger: defaultTab)
  }
}
