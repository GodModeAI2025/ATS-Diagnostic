import Foundation
import Testing
@testable import ATSDiagnostic
struct ProxyRulePersistenceTests {
    @Test func persistsOrderIdentityBinaryModeAndEnabledStateWithoutStaleOverwrite() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("rules.json")
        let store = ProxyRulePersistence(file: file)
        #expect(try await store.load().isEmpty)
        var first = ProxyRuleConfiguration(); first.matchURL = "https://example.com/a"
        first.bodyMode = .base64; first.bodyText = "AAH/"; first.headerText = "X-Test: original"
        var second = ProxyRuleConfiguration(); second.matchURL = "https://example.com/b"; second.enabled = false
        #expect(try await store.save([second, first], revision: 2))
        #expect(try await !store.save([first], revision: 1))
        let fresh = ProxyRulePersistence(file: file)
        let loaded = try await fresh.load()
        #expect(loaded.map(\.id) == [second.id, first.id])
        #expect(!loaded[0].enabled)
        #expect(loaded[1].bodyMode == .base64)
        #expect(loaded[1].bodyText == "AAH/")
        #expect(loaded[1].headerText == "X-Test: original")
    }
    @Test func invalidOrDuplicateProfilesNeverReplaceExistingFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("rules.json")
        let store = ProxyRulePersistence(file: file)
        var rule = ProxyRuleConfiguration(); rule.matchURL = "https://example.com/a"
        try await store.save([rule], revision: 1)
        do { try await store.save([rule, rule], revision: 2); Issue.record("Duplicate IDs accepted") }
        catch { #expect(error is ProxyRulePersistence.Failure) }
        #expect(try await store.load().count == 1)
        var invalid = rule; invalid.matchURL = "file:///tmp/fixture"
        do { try await store.save([invalid], revision: 3); Issue.record("Invalid rule accepted") }
        catch {}
        #expect(try await store.load().first?.id == rule.id)
    }
    @Test @MainActor func monitorReloadPreservesLatestEditAndDeletion() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("rules.json")
        let monitor = ProxyMonitor(persistence: ProxyRulePersistence(file: file))
        await monitor.loadRules()
        var rule = ProxyRuleConfiguration(); rule.matchURL = "https://example.com/a"
        rule.headerText = "X-Test: original"
        try monitor.saveRewriteConfiguration(rule)
        rule.enabled = false; rule.headerText = "X-Test: edited"
        try monitor.saveRewriteConfiguration(rule)
        await monitor.flushRules()
        let reopened = ProxyMonitor(persistence: ProxyRulePersistence(file: file))
        await reopened.loadRules()
        #expect(!reopened.rulesLoading); #expect(!reopened.rulesLoadFailed)
        let restored = try #require(reopened.rewriteConfigurations.first)
        #expect(restored.id == rule.id); #expect(!restored.enabled)
        #expect(restored.headerText == "X-Test: edited")
        reopened.removeRewriteConfigurations(at: IndexSet(integer: 0))
        await reopened.flushRules()
        let afterDeletion = ProxyMonitor(persistence: ProxyRulePersistence(file: file))
        await afterDeletion.loadRules()
        #expect(afterDeletion.rewriteConfigurations.isEmpty)
    }
    @Test @MainActor func writeFailureRemainsVisibleAndDoesNotReplaceBlockingFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let blocking = directory.appendingPathComponent("blocked")
        let sentinel = Data("fixture".utf8); try sentinel.write(to: blocking)
        let monitor = ProxyMonitor(persistence: ProxyRulePersistence(file: blocking.appendingPathComponent("rules.json")))
        await monitor.loadRules()
        var rule = ProxyRuleConfiguration(); rule.matchURL = "https://example.com/a"
        try monitor.saveRewriteConfiguration(rule)
        await monitor.flushRules()
        #expect(monitor.rulesPersistenceError?.contains("nicht gespeichert") == true)
        #expect(try Data(contentsOf: blocking) == sentinel)
    }

}
