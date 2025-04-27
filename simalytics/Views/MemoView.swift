import SwiftUI

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

          // ZStack allows layering the TextEditor and the Placeholder
          ZStack(alignment: .topLeading) {
            // The TextEditor for memo input
            TextEditor(text: $memoText)
              .frame(minHeight: 100, maxHeight: .infinity)  // Define flexible height
              .focused($isTextEditorFocused)  // Link focus state to the editor
              .padding(.horizontal, 4)  // Inner horizontal padding
              .padding(.vertical, 4)  // Inner vertical padding
              .background(  // Apply a subtle background
                RoundedRectangle(cornerRadius: 8)
                  .fill(Color(uiColor: .secondarySystemBackground))
              )
              .overlay(  // Add a border
                RoundedRectangle(cornerRadius: 8)
                  .stroke(Color.gray.opacity(0.3), lineWidth: 1)
              )
              .onChange(of: memoText) { newValue, _ in  // Monitor text changes to enforce limit
                if newValue.count > characterLimit {
                  // Automatically truncate text if it exceeds the limit
                  // Use prefix(characterLimit) to keep only the allowed number of characters
                  memoText = String(newValue.prefix(characterLimit))
                }
              }
              .accessibilityLabel("Memo input area")  // Accessibility improvement

            // Placeholder Text: Only shown when memoText is empty
            if memoText.isEmpty {
              Text(placeholderText)
                .foregroundColor(.gray.opacity(0.7))  // Style placeholder text
                .padding(.horizontal, 8)  // Match TextEditor horizontal padding
                .padding(.vertical, 12)  // Match TextEditor vertical padding
                .allowsHitTesting(false)  // Prevent placeholder from intercepting taps
            }
          }

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
        isTextEditorFocused = false
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
