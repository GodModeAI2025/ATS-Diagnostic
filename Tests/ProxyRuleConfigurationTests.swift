import Foundation
import Testing
@testable import ATSDiagnostic
struct ProxyRuleConfigurationTests {
    @Test func binaryBase64BodyAndExplicitEmptyBodyRemainDistinct() throws {
        let original = try #require(try HTTPProxyMessage.parseRequest(Data("POST http://example.com/a HTTP/1.1\r\nHost: example.com\r\nContent-Length: 3\r\n\r\nold".utf8)))
        var value = ProxyRuleConfiguration(); value.matchURL = original.url.absoluteString
        #expect(try value.rule().applying(to: original).body == original.body)
        value.bodyMode = .base64; value.bodyText = "AAH/"
        let binary = try value.rule().applying(to: original)
        #expect(try #require(try HTTPProxyMessage.parseRequest(binary.upstreamBytes())).body == Data([0,1,255]))
        value.bodyMode = .text; value.bodyText = ""
        #expect(try value.rule().applying(to: original).body.isEmpty)
        value.bodyMode = .base64; value.bodyText = "invalid!"
        #expect(throws: ProxyRuleConfiguration.ConfigurationError.self) { try value.rule() }
    }
    @Test @MainActor func editGuardsPreserveOrderAndPreventChangesWhileRunning() throws {
        let monitor = ProxyMonitor()
        var first = ProxyRuleConfiguration(); first.matchURL = "http://example.com/a"
        var second = ProxyRuleConfiguration(); second.matchURL = "http://example.com/b"
        try monitor.saveRewriteConfiguration(first); try monitor.saveRewriteConfiguration(second)
        monitor.moveRewriteConfigurations(from: IndexSet(integer: 0), to: 2)
        #expect(monitor.rewriteConfigurations.map(\.id) == [second.id, first.id])
        monitor.starting = true
        #expect(throws: ProxyMonitor.RuleEditError.self) { try monitor.saveRewriteConfiguration(first) }
        monitor.removeRewriteConfigurations(at: IndexSet(integer: 0))
        monitor.moveRewriteConfigurations(from: IndexSet(integer: 0), to: 2)
        #expect(monitor.rewriteConfigurations.map(\.id) == [second.id, first.id])
    }
}
