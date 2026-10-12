import Foundation
import Darwin

struct DNSAddress: Identifiable, Sendable {
    enum Family: String, Sendable { case ipv4 = "IPv4", ipv6 = "IPv6" }
    let address: String
    let family: Family
    var id: String { family.rawValue + ":" + address }
}
struct DNSLookupResult: Sendable {
    let host: String
    let addresses: [DNSAddress]
    let duration: Double
    let truncated: Bool
    var text: String { ([host] + addresses.map { "\($0.family.rawValue): \($0.address)" }).joined(separator: "\n") }
}
enum SystemDNSLookup {
    struct Failure: LocalizedError, Sendable {
        let code: Int32
        var errorDescription: String? {
            switch code {
            case EAI_NONAME: "Der Systemresolver hat keine Adresse gefunden. Prüfe den Hostnamen und die DNS-Einstellungen."
            case EAI_AGAIN: "Die Namensauflösung ist vorübergehend nicht verfügbar. Versuche es erneut und prüfe die Netzwerkverbindung."
            default: "Die Namensauflösung ist fehlgeschlagen (Resolver-Code \(code))."
            }
        }
    }
    static func host(from input: String) throws -> String {
        var candidate = input.trimmingCharacters(in: .whitespacesAndNewlines)
        var literal = in6_addr()
        if candidate.withCString({ inet_pton(AF_INET6, $0, &literal) }) == 1 { candidate = "[" + candidate + "]" }
        guard var host = try Endpoint.parse(candidate).host else { throw URLError(.badURL) }
        if host.hasPrefix("[") && host.hasSuffix("]") { host = String(host.dropFirst().dropLast()) }
        return host
    }
    static func resolve(_ input: String) async throws -> DNSLookupResult {
        let host = try host(from: input)
        return try await Task.detached(priority: .userInitiated) { try lookup(host) }.value
    }
    private static func lookup(_ host: String) throws -> DNSLookupResult {
        let began = ContinuousClock.now
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC; hints.ai_socktype = SOCK_STREAM
        var list: UnsafeMutablePointer<addrinfo>?
        let code = host.withCString { getaddrinfo($0, nil, &hints, &list) }
        guard code == 0 else { throw Failure(code: code) }
        defer { if let list { freeaddrinfo(list) } }
        var cursor = list
        var addresses: [DNSAddress] = []
        var seen: Set<String> = []
        var truncated = false
        while let node = cursor {
            let value = node.pointee
            cursor = value.ai_next
            guard let family: DNSAddress.Family = value.ai_family == AF_INET ? .ipv4 : value.ai_family == AF_INET6 ? .ipv6 : nil else { continue }
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = buffer.withUnsafeMutableBufferPointer { getnameinfo(value.ai_addr, value.ai_addrlen, $0.baseAddress, socklen_t($0.count), nil, 0, NI_NUMERICHOST) }
            guard result == 0 else { continue }
            let address = buffer.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
            let entry = DNSAddress(address: address, family: family)
            guard seen.insert(entry.id).inserted else { continue }
            if addresses.count == 64 { truncated = true; break }
            addresses.append(entry)
        }
        guard !addresses.isEmpty else { throw Failure(code: EAI_NONAME) }
        let elapsed = began.duration(to: .now).components
        return DNSLookupResult(host: host, addresses: addresses, duration: Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18, truncated: truncated)
    }
}
