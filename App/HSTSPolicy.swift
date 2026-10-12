import Foundation

/// Parses the observed field only; does not infer browser cache or preload membership.
struct HSTSPolicy: Equatable, Sendable {
    enum Result: Equatable, Sendable { case missing, invalid, policy(HSTSPolicy) }
    let maxAgeSeconds: String
    let includesSubdomains: Bool
    let preloadRequested: Bool
    var disablesPolicy: Bool { maxAgeSeconds.allSatisfy { $0 == "0" } }

    static func parse(_ value: String?) -> Result {
        guard let value else { return .missing }
        var parts: [String] = [], current = "", quoted = false, escaped = false
        for c in value {
            if escaped { current.append(c); escaped = false; continue }
            if quoted && c == "\\" { current.append(c); escaped = true; continue }
            if c == "\"" { quoted.toggle() }
            if c == ";" && !quoted { parts.append(current); current = "" }
            else { current.append(c) }
        }
        guard !quoted && !escaped else { return .invalid }
        parts.append(current)
        var seen: Set<String> = [], age: String?, subdomains = false, preload = false
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            let pair = trimmed.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let name = String(pair[0]).trimmingCharacters(in: .whitespaces).lowercased()
            guard isToken(name), seen.insert(name).inserted else { return .invalid }
            let raw = pair.count == 2 ? String(pair[1]).trimmingCharacters(in: .whitespaces) : nil
            if let raw, !isToken(raw) && !isQuoted(raw) { return .invalid }
            switch name {
            case "max-age":
                guard let raw else { return .invalid }
                let digits = raw.hasPrefix("\"") ? String(raw.dropFirst().dropLast()) : raw
                guard !digits.isEmpty, digits.utf8.allSatisfy({ (48...57).contains($0) }) else { return .invalid }
                age = digits
            case "includesubdomains":
                guard raw == nil else { return .invalid }; subdomains = true
            case "preload": preload = true
            default: break
            }
        }
        guard let age else { return .invalid }
        return .policy(Self(maxAgeSeconds: age, includesSubdomains: subdomains, preloadRequested: preload))
    }
    private static func isToken(_ s: String) -> Bool {
        !s.isEmpty && s.utf8.allSatisfy { b in
            (48...57).contains(b) || (65...90).contains(b) || (97...122).contains(b) || "!#$%&'*+-.^_`|~".utf8.contains(b)
        }
    }
    private static func isQuoted(_ s: String) -> Bool {
        let b = Array(s.utf8)
        guard b.count >= 2, b.first == 34, b.last == 34 else { return false }
        var escaped = false
        for c in b.dropFirst().dropLast() {
            if escaped { guard c == 9 || c >= 32 && c != 127 else { return false }; escaped = false }
            else if c == 92 { escaped = true }
            else if c == 34 || c < 32 && c != 9 || c == 127 { return false }
        }
        return !escaped
    }
}
