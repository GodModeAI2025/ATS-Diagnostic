import SwiftUI
import UIKit

/// Attaches only to this view's window and preserves controls and text editing.
struct KeyboardDismissSurface: UIViewRepresentable {
    func makeUIView(context: Context) -> Surface { Surface() }
    func updateUIView(_ uiView: Surface, context: Context) {}
    final class Surface: UIView, UIGestureRecognizerDelegate {
        private weak var installedWindow: UIWindow?
        private lazy var tap = UITapGestureRecognizer(target: self, action: #selector(dismissEditing))
        override func didMoveToWindow() {
            super.didMoveToWindow()
            installedWindow?.removeGestureRecognizer(tap)
            installedWindow = window
            tap.cancelsTouchesInView = false
            tap.delegate = self
            window?.addGestureRecognizer(tap)
        }
        @objc private func dismissEditing() { installedWindow?.endEditing(true) }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let candidate = view {
                if candidate is UITextField || candidate is UITextView || candidate is UIControl { return false }
                view = candidate.superview
            }
            return true
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
    }
}
