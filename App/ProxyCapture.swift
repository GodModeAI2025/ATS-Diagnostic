import Foundation

struct ProxyCapture: Identifiable, Codable, Sendable, Equatable {
    enum State: String, Codable, Sendable { case receiving, connecting, forwarding, tunnel, upgraded, completed, failed, stopped }
    var id = UUID()
    var date = Date()
    var revision = 0
    var method = ""
    var target = ""
    var originalTarget: String?
    var rewriteRuleApplied: Bool?
    var state = State.receiving
    var sentBytes = 0
    var receivedBytes = 0
    var duration: Double = 0
    var status: Int?
    var error: String?
    var requestPreview = Data()
    var responsePreview = Data()
    var upstreamTLS: String?
    var upstreamCipher: String?
    var upstreamTrustErrors: [ErrorEvidence]?
    var active: Bool { [.receiving,.connecting,.forwarding,.tunnel,.upgraded].contains(state) }
    var opaque: Bool { method == "CONNECT" }
    var stateText: String {
        switch state {
        case .receiving: "Anfrage empfangen"
        case .connecting: "Ziel verbinden"
        case .forwarding: "HTTP übertragen"
        case .tunnel: "TCP-Tunnel aktiv"
        case .upgraded: "Protokollwechsel · Datenstrom aktiv"
        case .completed: "Übertragung beendet"
        case .failed: "Übertragung fehlgeschlagen"
        case .stopped: "Vom Proxy beendet"
        }
    }
}

enum ProxyWire {
    static let previewLimit = 64 * 1024
    static let requestLimit = 16 * 1024 * 1024
    static func host(_ url: URL) -> String { (url.host ?? "").trimmingCharacters(in:CharacterSet(charactersIn:"[]")) }
    static func responseStatus(_ bytes: Data) -> Int? {
        var remaining = bytes
        for _ in 0..<16 {
            guard let end = remaining.range(of:Data("\r\n".utf8)), let line = String(data:remaining[..<end.lowerBound],encoding:.isoLatin1) else { return nil }
            let parts = line.split(separator:" ",maxSplits:2)
            guard parts.count >= 2, ["HTTP/1.0","HTTP/1.1"].contains(parts[0]), parts[1].count == 3, let status = Int(parts[1]), (100...599).contains(status) else { return nil }
            if status == 101 || status >= 200 { return status }
            guard let separator = remaining.range(of:Data("\r\n\r\n".utf8)) else { return nil }
            remaining = Data(remaining[separator.upperBound...])
        }
        return nil
    }
    static func expectation(_ bytes: Data) throws -> String? {
        guard let end = bytes.range(of:Data("\r\n\r\n".utf8)), let text = String(data:bytes[..<end.lowerBound],encoding:.isoLatin1) else { return nil }
        let values = try HTTPProxyMessage.parseHeaders(Array(text.components(separatedBy:"\r\n").dropFirst())).filter { $0.name.lowercased() == "expect" }.map(\.value)
        guard values.count <= 1 else { throw HTTPProxyMessage.ParseError.malformed }
        return values.first?.lowercased()
    }
    static func errorResponse(_ status: Int, message: String) -> Data {
        let body = Data((message + "\n").utf8)
        var data = Data("HTTP/1.1 \(status) Proxy Error\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8)
        data.append(body); return data
    }
}
