import Testing
import Foundation
import CryptoKit
@testable import ATSDiagnostic

final class IntegrityFixtureProtocol: URLProtocol, @unchecked Sendable {
    static let finalURL = URL(string: "https://cdn-fixture.test/download")!
    static let payload = Data(repeating: 0x61, count: 3 * 1024 * 1024)
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "integrity-fixture.test" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let response = HTTPURLResponse(url: Self.finalURL, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["Content-Length": String(Self.payload.count)]) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        for offset in stride(from: 0, to: Self.payload.count, by: 65536) { client?.urlProtocol(self, didLoad: Self.payload.subdata(in: offset..<min(offset + 65536, Self.payload.count))) }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
struct StreamingIntegrityTests {
    @Test func hashesEntireResponseBeyondPreviewLimit() async throws {
        let request = URLRequest(url: try #require(URL(string: "https://integrity-fixture.test/download")))
        let expected = SHA256.hash(data: IntegrityFixtureProtocol.payload).map { String(format: "%02x", $0) }.joined()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [IntegrityFixtureProtocol.self]
        let record = await DiagnosticEngine(request: request, expectedSHA256: expected).run(request, configuration: configuration)
        #expect(record.url == request.url?.absoluteString)
        #expect(record.finalURL == IntegrityFixtureProtocol.finalURL.absoluteString)
        #expect(record.bytes == 3 * 1024 * 1024)
        #expect(record.responseBody.utf8.count == 2 * 1024 * 1024)
        #expect(record.responseSHA256 == expected)
        #expect(record.integrityMatches == true)
    }
}
