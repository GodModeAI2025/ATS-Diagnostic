import Foundation
import CryptoKit

/// Queue-confined bounded transport observer for automatic capture integrations.
struct RecordingResponseAccumulator {
    let previewLimit: Int
    private(set) var preview = Data()
    private(set) var count = 0
    private var hash = SHA256()
    private var overflowed = false
    init(previewLimit: Int) { self.previewLimit = max(0, min(previewLimit, 16 * 1024 * 1024)) }
    mutating func receive(_ data: Data) {
        let (total, overflow) = count.addingReportingOverflow(data.count)
        if overflow { overflowed = true } else { count = total }
        hash.update(data: data)
        let remaining = previewLimit - preview.count
        if remaining > 0 { preview.append(data.prefix(remaining)) }
    }
    func snapshot(transportSucceeded: Bool) -> Snapshot {
        Snapshot(preview: preview, observedBytes: overflowed ? nil : count,
                 sha256: transportSucceeded && !overflowed ? hash.finalize().map { String(format: "%02x", $0) }.joined() : nil,
                 complete: transportSucceeded && !overflowed)
    }
    struct Snapshot: Sendable {
        let preview: Data
        let observedBytes: Int?
        let sha256: String?
        let complete: Bool
    }
}
