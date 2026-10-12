import Foundation
import Testing
@testable import ATSDiagnostic

struct ConnectionMetricsTests {
    private func snapshot(count: Int = 2, duration: Double = 0.5) throws -> ConnectionMetrics {
        let transaction: [String: Any] = ["url": "https://example.com", "status": 302,
            "protocolName": "h2", "reusedConnection": false, "proxyConnection": false,
            "fetchType": 1, "tlsProtocol": "0x0304", "waitDuration": 0.1]
        let object: [String: Any] = ["duration": duration, "redirectCount": 1,
            "transactionCount": count, "transactionsTruncated": false,
            "transactions": Array(repeating: transaction, count: count)]
        return try JSONDecoder().decode(ConnectionMetrics.self, from: JSONSerialization.data(withJSONObject: object))
    }
    @Test func preservesIndividualStepsThroughHARWithoutInventingPhases() throws {
        let metrics = try snapshot()
        let record = DiagnosticRecord(url: "https://example.com", method: "GET", status: 200, connectionMetrics: metrics)
        let imported = try #require(HARArchive.importRecords(JSONEncoder().encode(HARArchive(records: [record]))).first)
        let restored = try #require(imported.connectionMetrics)
        #expect(restored.redirectCount == 1)
        #expect(restored.transactions.count == 2)
        #expect(restored.transactions.first?.status == 302)
        #expect(restored.transactions.first?.tlsProtocol == "0x0304")
        #expect(restored.transactions.first?.dnsDuration == nil)
        #expect(restored.transactions.first?.waitDuration == 0.1)
        #expect(imported.dnsDuration == nil)
    }
    @Test func rejectsNegativeOverallDuration() {
        #expect(throws: DecodingError.self) { try snapshot(duration: -1) }
    }
    @Test func boundsImportedTransactionsAndPreservesTotal() throws {
        let metrics = try snapshot(count: 129)
        #expect(metrics.transactionCount == 129)
        #expect(metrics.transactions.count == 128)
        #expect(metrics.transactionsTruncated)
    }
    @Test func malformedMetricsDoNotDiscardOtherwiseValidHAR() throws {
        let record = DiagnosticRecord(url: "https://example.com", method: "GET", status: 200, connectionMetrics: try snapshot())
        var root = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(HARArchive(records: [record]))) as? [String: Any])
        var log = try #require(root["log"] as? [String: Any])
        var entries = try #require(log["entries"] as? [[String: Any]])
        var metadata = try #require(entries[0]["_atsDiagnostic"] as? [String: Any])
        var metrics = try #require(metadata["taskMetrics"] as? [String: Any])
        metrics["duration"] = -1
        metadata["taskMetrics"] = metrics
        entries[0]["_atsDiagnostic"] = metadata
        log["entries"] = entries
        root["log"] = log
        let restored = try #require(HARArchive.importRecords(JSONSerialization.data(withJSONObject: root)).first)
        #expect(restored.status == 200)
        #expect(restored.connectionMetrics == nil)
    }
    @Test func missingOrReversedNativeIntervalsRemainUnknown() {
        #expect(ConnectionMetrics.interval(nil, Date()) == nil)
        #expect(ConnectionMetrics.interval(Date(timeIntervalSince1970: 2), Date(timeIntervalSince1970: 1)) == nil)
        #expect(ConnectionMetrics.interval(Date(timeIntervalSince1970: 1), Date(timeIntervalSince1970: 2)) == 1)
    }
}
