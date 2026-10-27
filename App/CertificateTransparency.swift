import Foundation
import CryptoKit

struct SignedCertificateTimestamp: Identifiable, Sendable {
    let id: String
    let logID: String
    let timestamp: Date
    let signatureAlgorithm: String
    let signature: Data
    let extensions: Data
}
enum CertificateTransparency {
    static let oid = "1.3.6.1.4.1.11129.2.4.2"
    enum ParseError: Error { case invalid }
    static func embedded(in certificate: Data) throws -> [SignedCertificateTimestamp] {
        guard let root = try ASN1Node.decode(certificate).first else { throw ParseError.invalid }
        for container in root.children.first?.children ?? [] where container.tag == 0xa3 {
            for ext in container.children.first?.children ?? [] where ext.children.first?.oid == oid {
                guard let outerValue = ext.children.last, outerValue.tag == 4,
                      let inner = try ASN1Node.decode(outerValue.value).first, inner.tag == 4 else { throw ParseError.invalid }
                return try parseList(inner.value)
            }
        }
        return []
    }
    static func parseList(_ data: Data) throws -> [SignedCertificateTimestamp] {
        var reader = Reader(bytes: Array(data))
        let length = try reader.number(2)
        guard length > 0, length == reader.remaining else { throw ParseError.invalid }
        var items: [SignedCertificateTimestamp] = []
        while reader.remaining > 0 {
            let size = Int(try reader.number(2))
            let raw = try reader.take(size)
            var item = Reader(bytes: raw)
            guard try item.number(1) == 0 else { throw ParseError.invalid }
            let log = Data(try item.take(32)).map { String(format: "%02x", $0) }.joined()
            let timestamp = Date(timeIntervalSince1970: Double(try item.number(8)) / 1000)
            let extensionLength = Int(try item.number(2))
            let extensions = Data(try item.take(extensionLength))
            let hash = try item.number(1), algorithm = try item.number(1)
            let signatureLength = Int(try item.number(2))
            guard signatureLength > 0 else { throw ParseError.invalid }
            let signature = Data(try item.take(signatureLength))
            guard item.remaining == 0 else { throw ParseError.invalid }
            let hashName = [UInt64(4): "SHA-256", 5: "SHA-384", 6: "SHA-512"][hash] ?? "Hash \(hash)"
            let algorithmName = [UInt64(1): "RSA", 3: "ECDSA"][algorithm] ?? "Algorithm \(algorithm)"
            let identity = SHA256.hash(data: Data(raw)).map { String(format: "%02x", $0) }.joined()
            items.append(SignedCertificateTimestamp(id: identity + "-" + String(items.count), logID: log, timestamp: timestamp, signatureAlgorithm: "\(hashName) · \(algorithmName)", signature: signature, extensions: extensions))
        }
        return items
    }
    private struct Reader {
        let bytes: [UInt8]
        var position = 0
        var remaining: Int { bytes.count - position }
        mutating func take(_ count: Int) throws -> [UInt8] {
            guard count >= 0, count <= remaining else { throw ParseError.invalid }
            defer { position += count }
            return Array(bytes[position..<position + count])
        }
        mutating func number(_ count: Int) throws -> UInt64 {
            try take(count).reduce(0) { ($0 << 8) | UInt64($1) }
        }
    }
}
struct CTLogSnapshot: Decodable, Sendable {
    let date: String
    let version: String
    let logs: [String: Log]
    struct Log: Decodable, Sendable {
        let name: String
        let operatorName: String
        let state: String
        let url: String
    }
    static let bundled: CTLogSnapshot? = Bundle.main.url(forResource: "CTLogSnapshot", withExtension: "json").flatMap { try? JSONDecoder().decode(Self.self, from: Data(contentsOf: $0)) }
}

/// A dated Apple directory lookup, separate from cryptographic SCT verification.
struct AppleCTLogSnapshot: Decodable, Sendable {
    let sourceURL: String
    let retrievedAt: String
    let version: String
    let logs: [Log]
    struct Log: Decodable, Sendable {
        let logID: String
        let name: String
        let operatorName: String
        let state: String
        let stateTimestamp: String
        let publicKey: String
        let api: String
        func statusExplanation(at timestamp: Date) -> String {
            switch state {
            case "usable", "qualified", "readonly": return "Currently qualified according to Apple’s directory. The SCT signature and other policy conditions have not been checked."
            case "retired":
                guard let retirement = ISO8601DateFormatter().date(from: stateTimestamp) else { return "Retired; retirement time could not be read." }
                return timestamp < retirement ? "SCT issued before retirement; it may count as historically qualified. Further checks are required." : "SCT issued at or after retirement; it does not count as historically qualified."
            case "pending": return "Inclusion is pending; this log does not count as qualified."
            case "rejected": return "Rejected by Apple; this log does not count as qualified."
            default: return "Unknown status; qualification is not confirmed."
            }
        }
    }
    func log(id: String) -> Log? { logs.first { $0.logID == id } }
    static let bundled: Self? = Bundle.main.url(forResource: "AppleCTLogSnapshot", withExtension: "json").flatMap { try? JSONDecoder().decode(Self.self, from: Data(contentsOf: $0)) }
}

struct SystemCTPresentation: Sendable {
    let value: Bool?
    var title: String {
        switch value {
        case true: "System CT qualified"
        case false: "System CT qualification not confirmed"
        case nil: "System CT result not reported"
        }
    }
    var explanation: String {
        switch value {
        case true: "Apple’s trust engine confirmed that this connection meets its CT policy."
        case false: "Apple reported a negative CT qualification value. This alone does not prove a rejected connection: CT may not be required for this certificate. Check the separate system trust result and original error."
        case nil: "An absent CT result does not prove a CT failure. Roots and private certificates may not require CT."
        }
    }
}
