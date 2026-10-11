import Foundation

struct PolicyDirective: Identifiable, Sendable {
    let id: Int
    let name: String
    let value: String
}
enum PolicyDirectives {
    static func parse(name: String, value: String) -> [PolicyDirective] {
        let permissions = name.lowercased() == "permissions-policy"
        guard permissions || ["content-security-policy", "content-security-policy-report-only"].contains(name.lowercased()) else { return [] }
        let separator: Character = permissions ? "," : ";"
        var chunks: [String] = [], current = "", quote: Character?, depth = 0, escaped = false
        for character in value {
            if escaped { current.append(character); escaped = false; continue }
            if quote != nil && character == "\\" { escaped = true; current.append(character); continue }
            if let activeQuote = quote {
                if character == activeQuote { quote = nil }
            } else if character == "\"" || character == "'" { quote = character }
            else if character == "(" { depth += 1 }
            else if character == ")" { depth = max(0, depth - 1) }
            if character == separator && quote == nil && depth == 0 { chunks.append(current); current = "" }
            else { current.append(character) }
        }
        chunks.append(current)
        return chunks.compactMap { chunk -> (String,String)? in
            let text = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            let parts = permissions ? text.split(separator: "=",maxSplits: 1) : text.split(maxSplits: 1,whereSeparator: \.isWhitespace)
            return (String(parts[0]).trimmingCharacters(in: .whitespaces), parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : "No value specified")
        }.enumerated().map { PolicyDirective(id: $0.offset, name: $0.element.0, value: $0.element.1) }
    }
}
