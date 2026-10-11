import Foundation
import CryptoKit

enum Integrity {
    static func normalizeSHA256(_ text: String) throws -> String? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ":", with: "").lowercased()
        if normalized.isEmpty { return nil }
        guard normalized.count == 64, normalized.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { throw ValidationError.invalid }
        return normalized
    }
    enum ValidationError: LocalizedError {
        case invalid
        var errorDescription: String? { "Enter a SHA-256 checksum with 64 hexadecimal characters." }
    }
}
