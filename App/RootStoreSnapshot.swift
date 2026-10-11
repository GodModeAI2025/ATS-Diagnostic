import Foundation
import CryptoKit

struct RootStoreSnapshot: Decodable, Sendable {
    let retrievedAt: String
    let stores: [Store]
    struct Store: Decodable, Identifiable, Sendable {
        var id: String { name }
        let name: String
        let source: String
        let certificates: [String: Root]
    }
    struct Root: Decodable, Sendable {
        let name: String
        let constraints: String
    }
    static let bundled: RootStoreSnapshot? = Bundle.main.url(forResource: "RootStoreSnapshot", withExtension: "json").flatMap { try? JSONDecoder().decode(Self.self, from: Data(contentsOf: $0)) }
    static func fingerprint(_ der: Data) -> String { SHA256.hash(data: der).map { String(format: "%02x", $0) }.joined() }
}
