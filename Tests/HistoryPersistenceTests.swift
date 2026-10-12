import Foundation
import Testing
@testable import ATSDiagnostic

struct HistoryPersistenceTests {
    @Test func lateSnapshotCannotUndoClear() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let writer = HistoryPersistence(file: file)
        let record = DiagnosticRecord(url: "https://example.com/older", method: "GET")
        #expect(try await writer.save([record], revision: 1))
        #expect(try await writer.save([], revision: 3))
        #expect(try await writer.save([record], revision: 2) == false)
        let saved = try JSONDecoder().decode([DiagnosticRecord].self, from: Data(contentsOf: file))
        #expect(saved.isEmpty)
    }
    @MainActor @Test func rapidImportsThenClearFlushOnlyLatestState() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let store = DiagnosticStore(historyFile: file)
        let record = DiagnosticRecord(url: "https://example.com/import", method: "GET")
        let har = try JSONEncoder().encode(HARArchive(records: [record]))
        for _ in 0..<20 { try await store.importHAR(har) }
        await store.clear()
        await store.flushHistory()
        #expect(store.records.isEmpty)
        #expect(try JSONDecoder().decode([DiagnosticRecord].self, from: Data(contentsOf: file)).isEmpty)
        let reloaded = DiagnosticStore(historyFile: file)
        await reloaded.loadHistory()
        #expect(reloaded.records.isEmpty)
    }

    @MainActor @Test func immediateImportWaitsForSavedHistory() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let old = DiagnosticRecord(url: "https://example.com/saved", method: "GET")
        try JSONEncoder().encode([old]).write(to: file)
        let store = DiagnosticStore(historyFile: file)
        let new = DiagnosticRecord(url: "https://example.com/imported", method: "GET")
        try await store.importHAR(JSONEncoder().encode(HARArchive(records: [new])))
        await store.flushHistory()
        #expect(store.records.count == 2)
        #expect(store.records.last?.id == old.id)
        #expect(!store.loadingHistory)
    }
    @MainActor @Test func immediateClearCannotBeUndoneByInitialLoad() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try JSONEncoder().encode([DiagnosticRecord(url: "https://example.com/saved", method: "GET")]).write(to: file)
        let store = DiagnosticStore(historyFile: file)
        await store.clear()
        await store.flushHistory()
        #expect(store.records.isEmpty)
        #expect(try JSONDecoder().decode([DiagnosticRecord].self, from: Data(contentsOf: file)).isEmpty)
    }

    @Test func latestSnapshotRoundTripsCertificateAndBody() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let writer = HistoryPersistence(file: file)
        var record = DiagnosticRecord(url: "https://example.com/new", method: "POST")
        record.responseBody = String(repeating: "body\n", count: 1000)
        record.certificates = [CertificateRecord(id: "fixture", subject: "Fixture", der: Data([0, 1, 255]))]
        try await writer.save([record], revision: 2)
        let saved = try JSONDecoder().decode([DiagnosticRecord].self, from: Data(contentsOf: file))
        #expect(saved.first?.id == record.id)
        #expect(saved.first?.responseBody == record.responseBody)
        #expect(saved.first?.certificates.first?.der == record.certificates.first?.der)
    }
}
