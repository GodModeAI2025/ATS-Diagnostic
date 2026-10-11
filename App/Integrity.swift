import Foundation
import CryptoKit

enum Integrity {
    static func normalizeSHA256(_ text: String) throws -> String? {
        let normalized = text.filter { !$0.isWhitespace && $0 != ":" }.lowercased()
        if normalized.isEmpty { return nil }
        guard normalized.count == 64, normalized.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { throw ValidationError.invalid }
        return normalized
    }
    static func groupedDigest(_ value: String) -> String {
        let characters = Array(value)
        return stride(from: 0, to: characters.count, by: 4).map { String(characters[$0..<min($0 + 4, characters.count)]) }.joined(separator: " ")
    }
    enum ValidationError: LocalizedError {
        case invalid
        var errorDescription: String? { "Enter a SHA-256 checksum with 64 hexadecimal characters." }
    }
}
