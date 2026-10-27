#if targetEnvironment(macCatalyst)
import SwiftUI
import UIKit

/// Protocol input must retain literal quotes and dashes rather than typographic substitutions.
struct MacTechnicalTextEditor: UIViewRepresentable {
    @Binding var text: String
    let accessibilityName: String

    func makeUIView(context: Context) -> Input {
        let view = Input(accessibilityName: accessibilityName)
        view.text = text
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ view: Input, context: Context) {
        context.coordinator.text = $text
        view.accessibilityLabel = accessibilityName
        if view.text != text { view.text = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func textViewDidChange(_ textView: UITextView) { text.wrappedValue = textView.text }
    }

    final class Input: UITextView {
        init(accessibilityName: String) {
            super.init(frame: .zero, textContainer: nil)
            accessibilityLabel = accessibilityName
            font = .monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .callout).pointSize, weight: .regular)
            adjustsFontForContentSizeCategory = true
            textColor = .label
            backgroundColor = .clear
            autocapitalizationType = .none
            autocorrectionType = .no
            spellCheckingType = .no
            smartQuotesType = .no
            smartDashesType = .no
            smartInsertDeleteType = .no
            setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }

        required init?(coder: NSCoder) { return nil }
    }
}
#endif
