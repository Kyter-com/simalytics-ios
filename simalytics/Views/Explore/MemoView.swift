import SwiftData
import SwiftUI

struct MemoView: View {
  @State private var privacySelection = "Public"
  @State private var memoText = ""
  @FocusState private var isTextEditorFocused: Bool
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject private var auth: Auth
  @Environment(\.modelContext) private var modelContext

  var simkl_id: Int
  var item_status: String

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
              await addMemoToMovie(
                accessToken: auth.simklAccessToken, simkl: simkl_id, memoText: memoText,
                isPrivate: privacySelection == "Private",
                status: item_status, modelContainer: modelContext.container)
            }

            dismiss()
          }
          .disabled(memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
      .onTapGesture {
        // Tap anywhere will dismiss keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
      }
      .onAppear {
        Task { @MainActor [modelContext, simkl_id] in
          do {
            let movies = try modelContext.fetch(
              FetchDescriptor<V1.SDMovies>(predicate: #Predicate { $0.simkl == simkl_id })
            )
            if let movie = movies.first {
              self.memoText = movie.memo_text ?? ""
              self.privacySelection = movie.memo_is_private ?? false ? "Private" : "Public"
            }
          } catch {}
        }
      }
    }
  }
}
