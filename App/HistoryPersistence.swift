import Foundation

/// Serializes disk writes away from the UI actor. Revisions prevent late tasks
/// from restoring an older snapshot after a clear or newer recording.
actor HistoryPersistence {
    private let file: URL
    private var newestRevision: UInt64 = 0
    init(file: URL) { self.file = file }

    @discardableResult
    func save(_ records: [DiagnosticRecord], revision: UInt64) throws -> Bool {
        guard revision >= newestRevision else { return false }
        newestRevision = revision
        let data = try JSONEncoder().encode(records)
        try data.write(to: file, options: [.atomic, .completeFileProtection])
        return true
    }
}
