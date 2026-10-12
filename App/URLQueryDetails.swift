import Foundation

struct URLQueryParameter: Identifiable, Equatable, Sendable {
    struct ID: Hashable, Sendable {
        let rawSegment: String
        let occurrence: Int
    }
    let id: ID
    let rawName: String
    let rawValue: String?
    var name: String? { rawName.removingPercentEncoding }
    var value: String? { rawValue?.removingPercentEncoding }
}

/// Reads the original query delimiters without URLComponents normalizing malformed escapes.
struct URLQueryDetails: Sendable {
    static let byteLimit = 64 * 1024
    static let parameterLimit = 256
    let hasQuery: Bool
    let oversized: Bool
    let queryBytes: Int
    let parameterCount: Int?
    let parameters: [URLQueryParameter]

    init(url: String) {
        let beforeFragment = url.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0]
        guard let question = beforeFragment.firstIndex(of: "?") else {
            hasQuery = false; oversized = false; queryBytes = 0; parameterCount = 0; parameters = []; return
        }
        hasQuery = true
        let raw = beforeFragment[beforeFragment.index(after: question)...]
        queryBytes = raw.utf8.count
        oversized = queryBytes > Self.byteLimit
        guard !oversized else { parameterCount = nil; parameters = []; return }
        guard !raw.isEmpty else { parameterCount = 0; parameters = []; return }
        parameterCount = raw.utf8.reduce(1) { $0 + ($1 == 0x26 ? 1 : 0) }
        var occurrences: [String: Int] = [:]
        parameters = raw.split(separator: "&", maxSplits: Self.parameterLimit, omittingEmptySubsequences: false)
            .prefix(Self.parameterLimit).map { segment in
                let original = String(segment)
                let occurrence = occurrences[original, default: 0]
                occurrences[original] = occurrence + 1
                let fields = segment.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                return URLQueryParameter(id: .init(rawSegment: original, occurrence: occurrence),
                    rawName: String(fields[0]), rawValue: fields.count == 2 ? String(fields[1]) : nil)
            }
    }

    /// Escapes controls, bidi formatting and literal backslashes for an unambiguous display.
    static func visibleText(_ text: String) -> String {
        text.unicodeScalars.map { scalar -> String in
            switch scalar.value {
            case 0x5c: return "\\\\"
            case 0x09: return "\\t"
            case 0x0a: return "\\n"
            case 0x0d: return "\\r"
            case 0...0x1f, 0x7f...0x9f, 0x202a...0x202e, 0x2066...0x2069:
                return "\\u{\(String(scalar.value, radix: 16, uppercase: true))}"
            default: return String(scalar)
            }
        }.joined()
    }
}
