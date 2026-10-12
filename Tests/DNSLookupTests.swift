import Foundation
import Testing
@testable import ATSDiagnostic

struct DNSLookupTests {
    @Test func numericIPv4IsReturnedBySystemResolver() async throws {
        let result = try await SystemDNSLookup.resolve("https://127.0.0.1/path")
        #expect(result.host == "127.0.0.1")
        #expect(result.addresses.contains { $0.family == .ipv4 && $0.address == "127.0.0.1" })
        #expect(result.duration >= 0)
    }
    @Test func rawIPv6LiteralIsSupported() async throws {
        let result = try await SystemDNSLookup.resolve("::1")
        #expect(result.host == "::1")
        #expect(result.addresses.contains { $0.family == .ipv6 && $0.address == "::1" })
    }
    @Test func credentialsAndNonNetworkURLsAreRejectedBeforeLookup() {
        #expect(throws: URLError.self) { try SystemDNSLookup.host(from: "https://user:password@example.com") }
        #expect(throws: URLError.self) { try SystemDNSLookup.host(from: "file:///private/test") }
    }
}
