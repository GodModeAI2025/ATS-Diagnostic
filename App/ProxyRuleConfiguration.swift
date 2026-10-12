import Foundation

struct ProxyRuleConfiguration: Identifiable, Sendable {
    enum BodyMode: String, CaseIterable { case unchanged = "Unverändert", text = "UTF-8-Text", base64 = "Base64" }
    var id = UUID()
    var enabled = true
    var matchURL = ""
    var replacementURL = ""
    var method = ""
    var headerText = ""
    var bodyMode = BodyMode.unchanged
    var bodyText = ""
    func rule() throws -> HTTPProxyRewriteRule {
        let headers = try HTTPRequestFields.parseHeaders(headerText)
        let lines = headerText.split(whereSeparator: \.isNewline).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard headers.count == lines.count else { throw HTTPProxyRewriteRule.Failure.duplicateHeader }
        let body: Data?
        switch bodyMode {
        case .unchanged: body = nil
        case .text: body = Data(bodyText.utf8)
        case .base64:
            guard let decoded = Data(base64Encoded: bodyText) else { throw ConfigurationError.base64 }
            body = decoded
        }
        return try HTTPProxyRewriteRule(matchURL: matchURL.trimmingCharacters(in: .whitespacesAndNewlines),
            replacementURL: replacementURL.isEmpty ? nil : replacementURL,
            method: method.isEmpty ? nil : method, headers: headers, body: body)
    }
    enum ConfigurationError: LocalizedError {
        case base64
        var errorDescription: String? { "Der neue Body ist kein gültiger Base64-Inhalt." }
    }
}
