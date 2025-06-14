import SwiftData
import SwiftUI

struct MemoView: View {
  @Binding var memoText: String
  @Binding var privacySelection: String
  @FocusState private var isTextEditorFocused: Bool
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject private var auth: Auth
  @Environment(\.modelContext) private var modelContext

  var simkl_id: Int
  var item_status: String
  var simkl_type: String

  var characterCountText: String { "\(memoText.count) / \(180)" }

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 16) {
        VStack(alignment: .leading) {
          Text("Visibility")
            .font(.headline)
          Picker("Visibility", selection: $privacySelection) {
            ForEach(["Public", "Private"], id: \.self) { option in
              Text(option)
            }
          }
          .pickerStyle(.segmented)
        }

        VStack(alignment: .leading) {
          Text("Memo")
            .font(.headline)

          RoundedTextEditor(
            text: $memoText,
            cornerRadius: 8,
            backgroundColor: .secondarySystemBackground,
          )
          .frame(minHeight: 100, maxHeight: .infinity)
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(Color.gray.opacity(0.3), lineWidth: 1)
          )
          .accessibilityLabel("Memo input area")

          HStack {
            Spacer()
            Text(characterCountText)
              .font(.caption)
              .foregroundColor(.secondary)
              .padding(.top, 4)
          }
          .accessibilityLabel("Character count: \(characterCountText)")
        }

        Spacer()
      }
      .padding()
      .navigationTitle("Write Memo")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            Task {
              if simkl_type == "movie" {
                await addMemoToMovie(
                  accessToken: auth.simklAccessToken, simkl: simkl_id, memoText: memoText,
                  isPrivate: privacySelection == "Private",
                  status: item_status, modelContainer: modelContext.container)
              } else if simkl_type == "show" {
                await addMemoToShow(
                  accessToken: auth.simklAccessToken, simkl: simkl_id, memoText: memoText,
                  isPrivate: privacySelection == "Private",
                  status: item_status, modelContainer: modelContext.container)
              } else if simkl_type == "anime" {
                await addMemoToAnime(
                  accessToken: auth.simklAccessToken, simkl: simkl_id, memoText: memoText,
                  isPrivate: privacySelection == "Private",
                  status: item_status, modelContainer: modelContext.container)
              }
            }
            dismiss()
          }
          .bold()
          .disabled(memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
      .onTapGesture {
        // Tap anywhere will dismiss keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
      }
    }
  }
}
// TODO: Background genre/tmdb info sync
