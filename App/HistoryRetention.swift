import Foundation

/// Limits the encoded history, including bodies, headers and certificates.
enum HistoryRetention {
    static let maximumBytes = 64 * 1024 * 1024
    static func retain(_ records: [DiagnosticRecord], countLimit: Int, byteLimit: Int = maximumBytes) throws -> [DiagnosticRecord] {
        let encoder = JSONEncoder()
        var retained: [DiagnosticRecord] = []
        var bytes = 2 // JSON array brackets
        for record in records.prefix(max(0, countLimit)) {
            let size = try encoder.encode(record).count
            let separator = retained.isEmpty ? 0 : 1
            guard size <= byteLimit - min(bytes, byteLimit) - separator else { break }
            retained.append(record)
            bytes += size + separator
        }
        return retained
    }
}
