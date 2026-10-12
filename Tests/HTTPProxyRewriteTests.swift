import Foundation
import Testing
@testable import ATSDiagnostic
struct HTTPProxyRewriteTests {
    private func request() throws -> ProxyHTTPRequest {
        try #require(try HTTPProxyMessage.parseRequest(Data("POST http://example.com/a HTTP/1.1\r\nHost: example.com\r\nAuthorization: Bearer fixture\r\nCookie: a=1\r\nTransfer-Encoding: chunked\r\n\r\n3\r\nold\r\n0\r\n\r\n".utf8)))
    }
    @Test func replacedBodyReframesChunkedRequestAndKeepsOriginal() throws {
        let original = try request()
        let rule = try HTTPProxyRewriteRule(matchURL: original.url.absoluteString, headers: ["X-Test":"new"], body: Data("edited".utf8))
        let rewritten = try rule.applying(to: original)
        let parsed = try #require(try HTTPProxyMessage.parseRequest(rewritten.upstreamBytes()))
        #expect(parsed.body == Data("edited".utf8))
        #expect(parsed.headers.contains { $0.name.lowercased() == "content-length" && $0.value == "6" })
        #expect(!parsed.headers.contains { $0.name.lowercased() == "transfer-encoding" })
        #expect(original.body == Data("old".utf8))
    }
    @Test func targetMapDoesNotTransferOldCredentials() throws {
        let original = try request()
        let rewritten = try HTTPProxyRewriteRule(matchURL: original.url.absoluteString, replacementURL: "https://other.example/b").applying(to: original)
        #expect(rewritten.url.absoluteString == "https://other.example/b")
        #expect(!rewritten.headers.contains { ["authorization","cookie"].contains($0.name.lowercased()) })
        #expect(rewritten.body == original.body)
    }
    @Test func nonMatchPreservesWireAndManagedHeadersCannotBeOverridden() throws {
        let original = try request()
        let rewritten = try HTTPProxyRewriteRule(matchURL: "http://example.com/other", body: Data()).applying(to: original)
        #expect(rewritten.upstreamBytes() == original.upstreamBytes())
        #expect(throws: HTTPProxyRewriteRule.Failure.self) { try HTTPProxyRewriteRule(matchURL: "http://example.com/a", headers: ["Content-Length":"999"]) }
        #expect(throws: HTTPProxyRewriteRule.Failure.self) { try HTTPProxyRewriteRule(matchURL: "http://example.com/a", headers: ["X-Test":"a","x-test":"b"]) }
    }
    @Test func sameOriginMapKeepsCredentialsAndOriginalChunkFraming() throws {
        let original = try request()
        let rewritten = try HTTPProxyRewriteRule(matchURL: original.url.absoluteString, replacementURL: "http://example.com/b").applying(to: original)
        #expect(rewritten.headers.contains { $0.name.lowercased() == "authorization" })
        #expect(rewritten.headers.contains { $0.name.lowercased() == "cookie" })
        #expect(rewritten.wireBody == original.wireBody)
        #expect(try #require(try HTTPProxyMessage.parseRequest(rewritten.upstreamBytes())).body == original.body)
    }
    @Test func opaqueTunnelAndUpgradeCannotBeRewritten() throws {
        let tunnel = try #require(try HTTPProxyMessage.parseRequest(Data("CONNECT example.com:443 HTTP/1.1\r\nHost: example.com:443\r\n\r\n".utf8)))
        let tunnelRule = try HTTPProxyRewriteRule(matchURL: tunnel.url.absoluteString, body: Data())
        #expect(throws: HTTPProxyRewriteRule.Failure.self) { try tunnelRule.applying(to: tunnel) }
        let upgrade = try #require(try HTTPProxyMessage.parseRequest(Data("GET http://example.com/ws HTTP/1.1\r\nHost: example.com\r\nConnection: Upgrade\r\nUpgrade: websocket\r\n\r\n".utf8)))
        let upgradeRule = try HTTPProxyRewriteRule(matchURL: upgrade.url.absoluteString, headers: ["X-Test":"new"])
        #expect(throws: HTTPProxyRewriteRule.Failure.self) { try upgradeRule.applying(to: upgrade) }
        #expect(throws: HTTPProxyRewriteRule.Failure.self) { try HTTPProxyRewriteRule(matchURL: "http://example.com/a", method: "CONNECT") }
    }
    @Test func mappingRequiresExplicitURLWithoutFragmentOrCredentials() {
        for value in ["example.com", "file:///tmp/test", "https://user:secret@example.com", "https://example.com/#fragment"] {
            #expect(throws: (any Error).self) { try HTTPProxyRewriteRule(matchURL: "http://example.com/a", replacementURL: value) }
        }
    }

}
