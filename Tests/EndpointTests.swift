import Testing
import Foundation
@testable import ATSDiagnostic
struct EndpointTests {
    @Test func defaultsToHTTPS() throws { #expect(try Endpoint.parse("example.com/path").absoluteString == "https://example.com/path") }
    @Test func rejectsCredentials() { #expect(throws: URLError.self) { try Endpoint.parse("https://user:pass@example.com") } }
    @Test func rejectsOtherSchemes() { #expect(throws: URLError.self) { try Endpoint.parse("file:///private/test") } }
    @Test func shellQuoteProtectsApostrophes() { #expect(DiagnosticRecord.quote("a'b") == "'a'\\''b'") }
}
