import UIKit

/// Holds only the system-granted time needed to finish an already queued write.
@MainActor final class BackgroundWriteLease {
    private var identifier: UIBackgroundTaskIdentifier = .invalid
    func begin() {
        guard identifier == .invalid else { return }
        identifier = UIApplication.shared.beginBackgroundTask(withName: "Save diagnostic history") { [weak self] in
            Task { @MainActor in self?.end() }
        }
    }
    func end() {
        guard identifier != .invalid else { return }
        let active = identifier
        identifier = .invalid
        UIApplication.shared.endBackgroundTask(active)
    }
}
