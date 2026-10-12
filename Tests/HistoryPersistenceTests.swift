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
        for _ in 0..<20 { try store.importHAR(har) }
        store.clear()
        await store.flushHistory()
        #expect(store.records.isEmpty)
        #expect(try JSONDecoder().decode([DiagnosticRecord].self, from: Data(contentsOf: file)).isEmpty)
        let reloaded = DiagnosticStore(historyFile: file)
        #expect(reloaded.records.isEmpty)
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
