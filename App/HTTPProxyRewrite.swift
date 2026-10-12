import Foundation

/// Exact-URL rewrite; configuration is explicit and has no global side effects.
struct HTTPProxyRewriteRule: Sendable {
    let matchURL: String
    let replacementURL: String?
    let method: String?
    let headers: [String: String]
    let body: Data?
    enum Failure: LocalizedError {
        case target, framingHeader, duplicateHeader, opaqueTransport, bodyLimit
        var errorDescription: String? {
            switch self {
            case .target: "Ein Umschreibungsziel muss eine gültige HTTP- oder HTTPS-URL ohne Zugangsdaten sein."
            case .framingHeader: "Host-, Verbindungs- und Nachrichtenlängen-Header werden vom Proxy verwaltet."
            case .duplicateHeader: "Eine Umschreibung enthält denselben Header-Namen mehrfach."
            case .opaqueTransport: "CONNECT-Tunnel und Upgrade-Verbindungen können hier nicht umgeschrieben werden."
            case .bodyLimit: "Der neue Anfrageinhalt überschreitet das Proxy-Limit von 16 MiB."
            }
        }
    }
    init(matchURL: String, replacementURL: String? = nil, method: String? = nil, headers: [String: String] = [:], body: Data? = nil) throws {
        let normalizedMatch = try Self.target(matchURL)
        if let replacementURL { _ = try Self.target(replacementURL) }
        guard method != "CONNECT" else { throw Failure.opaqueTransport }
        try HTTPRequestFields.validate(method: method ?? "GET", headers: headers)
        let names = headers.keys.map { $0.lowercased() }
        guard Set(names).count == names.count else { throw Failure.duplicateHeader }
        let managed: Set<String> = ["host", "connection", "proxy-connection", "proxy-authorization", "content-length", "transfer-encoding", "trailer", "te", "upgrade", "expect", "keep-alive"]
        guard managed.isDisjoint(with: names) else { throw Failure.framingHeader }
        guard (body?.count ?? 0) <= 16 * 1024 * 1024 else { throw Failure.bodyLimit }
        self.matchURL = normalizedMatch.absoluteString; self.replacementURL = replacementURL
        self.method = method; self.headers = headers; self.body = body
    }
    func applying(to request: ProxyHTTPRequest) throws -> ProxyHTTPRequest {
        guard request.url.absoluteString == matchURL else { return request }
        guard !request.isTunnel, !request.requestsUpgrade else { throw Failure.opaqueTransport }
        let url = try replacementURL.map(Self.target) ?? request.url
        var fields = request.headers
        if Self.origin(url) != Self.origin(request.url) {
            // A target map must not silently transfer the old origin's credentials.
            fields.removeAll { ["authorization", "cookie"].contains($0.name.lowercased()) }
        }
        for name in headers.keys.sorted() {
            fields.removeAll { $0.name.caseInsensitiveCompare(name) == .orderedSame }
            fields.append(HTTPHeader(name: name, value: headers[name]!))
        }
        if let body {
            fields.removeAll { ["content-length", "transfer-encoding", "trailer"].contains($0.name.lowercased()) }
            fields.append(HTTPHeader(name: "Content-Length", value: String(body.count)))
        }
        return ProxyHTTPRequest(method: method ?? request.method, target: url.absoluteString, version: request.version,
                                url: url, headers: fields, body: body ?? request.body, wireBody: body ?? request.wireBody,
                                consumedBytes: request.consumedBytes)
    }
    private static func target(_ text: String) throws -> URL {
        guard let literal = URL(string: text), ["http", "https"].contains(literal.scheme?.lowercased() ?? ""), literal.host != nil else { throw Failure.target }
        let url = try Endpoint.parse(text)
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.user == nil, url.password == nil,
              url.fragment == nil else { throw Failure.target }
        return url
    }
    private static func origin(_ url: URL) -> String {
        "\(url.scheme?.lowercased() ?? "")://\(url.host?.lowercased() ?? ""):\(url.port ?? (url.scheme == "https" ? 443 : 80))"
    }
}
