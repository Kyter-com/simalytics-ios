import SwiftUI
import UIKit

// Custom UIViewRepresentable TextEditor with rounded corners
struct RoundedTextEditor: UIViewRepresentable {
  @Binding var text: String
  var cornerRadius: CGFloat = 8
  var backgroundColor: UIColor = .secondarySystemBackground
  var placeholderText: String = ""
  var placeholderColor: UIColor = .gray
  var characterLimit: Int = 180

  // Create the UITextView
  func makeUIView(context: Context) -> UITextView {
    let textView = UITextView()
    textView.delegate = context.coordinator
    textView.font = UIFont.preferredFont(forTextStyle: .body)
    textView.backgroundColor = backgroundColor
    textView.layer.cornerRadius = cornerRadius
    textView.clipsToBounds = true
    textView.text = text.isEmpty ? placeholderText : text
    textView.textColor = text.isEmpty ? placeholderColor : .label
    textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
    return textView
  }

  // Update the UITextView when SwiftUI state changes
  func updateUIView(_ uiView: UITextView, context: Context) {
    // Only update if the text changed externally
    if text != uiView.text && !(text.isEmpty && uiView.text == placeholderText) {
      uiView.text = text
      uiView.textColor = .label
    }

    // Update placeholders as needed
    if text.isEmpty && uiView.text.isEmpty {
      uiView.text = placeholderText
      uiView.textColor = placeholderColor
    }
  }

  // Create a coordinator to manage the UITextView delegate
  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  // Coordinator class to handle UITextView delegate methods
  class Coordinator: NSObject, UITextViewDelegate {
    var parent: RoundedTextEditor

    init(_ parent: RoundedTextEditor) {
      self.parent = parent
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
      // Clear placeholder when editing begins
      if textView.text == parent.placeholderText {
        textView.text = ""
        textView.textColor = .label
      }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
      // Restore placeholder if needed
      if textView.text.isEmpty {
        textView.text = parent.placeholderText
        textView.textColor = parent.placeholderColor
      }
    }

    func textViewDidChange(_ textView: UITextView) {
      // Update the binding
      parent.text = textView.text
    }

    // Implement strict character limit - this will prevent more than the limit from being entered
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
      // Get the current text and create the updated text
      let currentText = textView.text ?? ""
      let updatedText = (currentText as NSString).replacingCharacters(in: range, with: text)

      // Only allow the change if it doesn't exceed the character limit
      return updatedText.count <= parent.characterLimit
    }
  }
}

struct MemoView: View {
  // MARK: - State Variables
  @State private var privacySelection = "Public"  // Tracks the selected privacy option
  @State private var memoText = ""  // Holds the text entered by the user
  @FocusState private var isTextEditorFocused: Bool  // Manages keyboard focus for the TextEditor

  // MARK: - Constants
  let characterLimit = 180  // Maximum allowed characters for the memo
  let privacyOptions = ["Public", "Private"]  // Options for the visibility picker
  let placeholderText = "Write your memo here..."  // Placeholder text for the TextEditor

  // MARK: - Environment
  @Environment(\.dismiss) var dismiss  // Action to close the current view (e.g., a sheet)

  // MARK: - Computed Properties
  // Determines the color of the character count text based on whether the limit is exceeded
  var characterCountColor: Color {
    memoText.count > characterLimit ? .red : .secondary
  }

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
            placeholderText: placeholderText,
            placeholderColor: UIColor.gray.withAlphaComponent(0.7),
            characterLimit: characterLimit
          )
          .frame(minHeight: 100, maxHeight: .infinity)
          .overlay(  // Add a border
            RoundedRectangle(cornerRadius: 8)
              .stroke(Color.gray.opacity(0.3), lineWidth: 1)
          )
          .accessibilityLabel("Memo input area")  // Accessibility improvement

          // --- Character Counter ---
          HStack {
            Spacer()  // Pushes the counter to the right
            Text(characterCountText)  // Display the character count (e.g., "25 / 180")
              .font(.caption)  // Use smaller font size
              .foregroundColor(characterCountColor)  // Apply dynamic color (red if over limit)
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
        // Done Button (trailing side)
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            // --- ACTION: Implement what happens when Done is tapped ---
            print("Memo Saved:")
            print("Text: \(memoText)")
            print("Visibility: \(privacySelection)")
            // Example: Call a function to save the memo data
            // saveMemo(text: memoText, visibility: privacySelection)
            // --- End Action ---

            dismiss()  // Close the sheet after the action
          }
          // Disable the Done button if the memo text is empty (ignoring whitespace)
          .disabled(memoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
      // Add a tap gesture to the background to dismiss the keyboard
      .onTapGesture {
        // In our case, tap anywhere will dismiss keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
      }
    }
  }
}

// MARK: - Preview
struct MemoView_Previews: PreviewProvider {
  static var previews: some View {
    // Simulate presenting MemoView within a sheet for previewing
    Text("Tap to show Memo Sheet")
      .sheet(isPresented: .constant(true)) {  // Use .constant(true) to always show in preview
        MemoView()
      }
  }
}
