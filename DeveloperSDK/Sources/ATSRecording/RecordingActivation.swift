import Foundation

public enum RecordingActivationSource: Sendable { case custom, shake }

/// The host controls presentation. Activation is disabled until explicitly enabled.
@MainActor public final class RecordingActivation {
    public var isEnabled = false
    public var handler: (@MainActor (RecordingActivationSource) -> Void)?
    public init() {}
    @discardableResult public func activate(source: RecordingActivationSource = .custom) -> Bool {
        guard isEnabled, let handler else { return false }
        handler(source)
        return true
    }
}

#if canImport(UIKit)
import UIKit

/// An opt-in window for a host-owned UIWindowScene. Unhandled motion continues
/// through UIKit normally; an enabled recording callback consumes its shake.
@MainActor public final class RecordingWindow: UIWindow {
    public weak var recordingActivation: RecordingActivation?
    public override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake, recordingActivation?.activate(source: .shake) == true { return }
        super.motionEnded(motion, with: event)
    }
}
#endif
