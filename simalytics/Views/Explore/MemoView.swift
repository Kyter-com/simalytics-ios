import SwiftData
import SwiftUI
import UIKit

struct RoundedTextEditor: UIViewRepresentable {
  @Binding var text: String
  var cornerRadius: CGFloat = 8
  var backgroundColor: UIColor = .secondarySystemBackground
  var characterLimit: Int = 180

  func makeUIView(context: Context) -> UITextView {
    let textView = UITextView()
    textView.delegate = context.coordinator
    textView.font = UIFont.preferredFont(forTextStyle: .body)
    textView.backgroundColor = backgroundColor
    textView.layer.cornerRadius = cornerRadius
    textView.clipsToBounds = true
    textView.text = text
    textView.textColor = .label
    textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
    return textView
  }

  func updateUIView(_ uiView: UITextView, context: Context) {
    if text != uiView.text {
      uiView.text = text
      uiView.textColor = .label
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  class Coordinator: NSObject, UITextViewDelegate {
    var parent: RoundedTextEditor

    init(_ parent: RoundedTextEditor) {
      self.parent = parent
    }

    func textViewDidChange(_ textView: UITextView) {
      parent.text = textView.text
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
      let currentText = textView.text ?? ""
      let updatedText = (currentText as NSString).replacingCharacters(in: range, with: text)
      return updatedText.count <= parent.characterLimit
    }
  }
}

struct MemoView: View {
  @State private var privacySelection = "Public"
  @State private var memoText = ""
  @FocusState private var isTextEditorFocused: Bool

  var simkl_id: Int
  var item_status: String

  let characterLimit = 180
  let privacyOptions = ["Public", "Private"]

  @Environment(\.dismiss) var dismiss
  @EnvironmentObject private var auth: Auth
  @Environment(\.modelContext) private var modelContext

  // Formats the character count string
  var characterCountText: String {
    "\(memoText.count) / \(characterLimit)"
  }

  // MARK: - Body
  var body: some View {
    // Use NavigationStack for title and toolbar, common practice for sheets
    NavigationStack {
      // Main container for the view's content
      VStack(alignment: .leading, spacing: 16) {

        // --- Visibility Picker Section ---
        VStack(alignment: .leading) {
          Text("Visibility")  // Label for the picker
            .font(.headline)
          Picker("Visibility", selection: $privacySelection) {  // The segmented picker
            ForEach(privacyOptions, id: \.self) { option in
              Text(option)
            }
          }
          .pickerStyle(.segmented)  // Style the picker as segments
          // .labelsHidden() // Uncomment this if the "Visibility" text label is not needed
        }

        // --- Memo TextEditor Section ---
        VStack(alignment: .leading) {
          Text("Memo")  // Label for the text editor
            .font(.headline)

          // Custom TextEditor with built-in rounded corners
          RoundedTextEditor(
            text: $memoText,
            cornerRadius: 8,
            backgroundColor: .secondarySystemBackground,
            characterLimit: characterLimit
          )
          .frame(minHeight: 100, maxHeight: .infinity)
          .overlay(  // Add a border
            RoundedRectangle(cornerRadius: 8)
              .stroke(Color.gray.opacity(0.3), lineWidth: 1)
          )
          .accessibilityLabel("Memo input area")  // Accessibility improvement

          HStack {
            Spacer()  // Pushes the counter to the right
            Text(characterCountText)  // Display the character count (e.g., "25 / 180")
              .font(.caption)  // Use smaller font size
              .foregroundColor(.secondary)  // Apply dynamic color (red if over limit)
              .padding(.top, 4)  // Add some space above the counter
          }
          .accessibilityLabel("Character count: \(characterCountText)")  // Accessibility
        }

        Spacer()  // Pushes all content towards the top of the VStack
      }
      .padding()  // Add padding around the entire content VStack
      .navigationTitle("Write Memo")  // Set the title displayed in the navigation bar
      .navigationBarTitleDisplayMode(.inline)  // Use inline style for the title in sheets
      .toolbar {  // Define items to appear in the navigation bar's toolbar
        // Cancel Button (leading side)
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()  // Close the sheet without saving/processing
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
        UIApplication.shared.sendAction(
          #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
