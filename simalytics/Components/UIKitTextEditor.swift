//
//  UIKitTextEditor.swift
//  simalytics
//
//  Created by Nick Reisenauer on 4/29/25.
//

import SwiftUI
import UIKit

struct RoundedTextEditor: UIViewRepresentable {
  @Binding var text: String
  var cornerRadius: CGFloat = 8
  var backgroundColor: UIColor = .secondarySystemBackground

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
      return updatedText.count <= 180
    }
  }
}
