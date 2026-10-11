import Foundation
import Testing
@testable import ATSDiagnostic
struct HTTPProxyMessageTests {
    @Test func incompleteHeaderWaits() throws { #expect(try HTTPProxyMessage.parseRequest(Data("GET http://example.com/ HTTP/1.1\r\nHost: example.com\r\n".utf8)) == nil) }
    @Test func parsesChunkedWithTrailers() throws {
        let data = Data("POST http://example.com/api HTTP/1.1\r\nHost: example.com\r\nTransfer-Encoding: chunked\r\n\r\n4\r\ntest\r\n0\r\nX-Checksum: ok\r\n\r\n".utf8)
        let request = try #require(try HTTPProxyMessage.parseRequest(data))
        #expect(request.body == Data("test".utf8)); #expect(request.consumedBytes == data.count)
    }
    @Test func rejectsAmbiguousFraming() { #expect(throws: HTTPProxyMessage.ParseError.self) { try HTTPProxyMessage.parseRequest(Data("POST http://example.com HTTP/1.1\r\nHost: example.com\r\nContent-Length: 5\r\nTransfer-Encoding: chunked\r\n\r\n".utf8)) } }
    @Test func rejectsConflictingDuplicateLengths() { #expect(throws: HTTPProxyMessage.ParseError.self) { try HTTPProxyMessage.parseRequest(Data("POST / HTTP/1.1\r\nHost: example.com\r\nContent-Length: 1\r\nContent-Length: 2\r\n\r\nab".utf8)) } }
    @Test func acceptsMatchingDuplicateLengths() throws { #expect(try HTTPProxyMessage.parseRequest(Data("POST / HTTP/1.1\r\nHost: example.com\r\nContent-Length: 2, 2\r\n\r\nab".utf8))?.body == Data("ab".utf8)) }
    @Test func preservesPipelinedBytes() throws { let header = "GET / HTTP/1.1\r\nHost: example.com\r\n\r\n"; let request = try #require(try HTTPProxyMessage.parseRequest(Data((header + header).utf8))); #expect(request.consumedBytes == header.utf8.count) }
    @Test func supportsIPv6Connect() throws { let request = try #require(try HTTPProxyMessage.parseRequest(Data("CONNECT [::1]:443 HTTP/1.1\r\nHost: [::1]:443\r\n\r\n".utf8))); #expect(request.isTunnel); #expect(request.url.port == 443) }
    @Test func removesProxyCredentialsFromUpstream() throws {
        let request = try #require(try HTTPProxyMessage.parseRequest(Data("GET http://example.com/a?q=1 HTTP/1.1\r\nHost: other.example\r\nProxy-Authorization: secret\r\nConnection: X-Hop\r\nX-Hop: value\r\n\r\n".utf8)))
        let upstream = String(decoding: request.upstreamBytes(), as: UTF8.self)
        #expect(upstream.hasPrefix("GET /a?q=1 HTTP/1.1\r\n")); #expect(upstream.contains("Host: example.com")); #expect(!upstream.contains("secret")); #expect(!upstream.contains("X-Hop"))
    }
    @Test func rejectsOversizedChunkWithoutAllocation() { #expect(throws: HTTPProxyMessage.ParseError.self) { try HTTPProxyMessage.decodeChunks(Data("ffffffffffffffff\r\n".utf8), bodyLimit: 1024) } }
    @Test func rejectsWhitespaceBeforeHeaderColon() { #expect(throws: HTTPProxyMessage.ParseError.self) { try HTTPProxyMessage.parseHeaders(["Host : example.com"]) } }
}

struct HTTPProxyFramingSafetyTests {
    @Test func rejectsConnectionNominatedLength() {
        #expect(throws: HTTPProxyMessage.ParseError.self) { try HTTPProxyMessage.parseRequest(Data("POST / HTTP/1.1\r\nHost: example.com\r\nContent-Length: 2\r\nConnection: Content-Length\r\n\r\nab".utf8)) }
    }
    @Test func rejectsControlCharacterInChunkExtension() {
        #expect(throws: HTTPProxyMessage.ParseError.self) { try HTTPProxyMessage.decodeChunks(Data("2;x=one\ntwo\r\nab\r\n0\r\n\r\n".utf8), bodyLimit: 100) }
    }
    @Test func rejectsTrailerFramingOverride() {
        #expect(throws: HTTPProxyMessage.ParseError.self) { try HTTPProxyMessage.decodeChunks(Data("0\r\nContent-Length: 4\r\n\r\n".utf8), bodyLimit: 100) }
    }
}
