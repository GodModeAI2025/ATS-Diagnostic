import Testing
import Foundation
@testable import ATSDiagnostic
struct HARTests {
    @Test func preservesReplayData() throws {
        let record = DiagnosticRecord(url: "https://example.com/api?a=1", method: "POST", requestHeaders: ["Content-Type": "application/json"], requestBody: "{\"a\":1}", status: 201, responseBody: "ok", bytes: 2, duration: 0.5)
        let archive = HARArchive(records: [record])
        let decoded = try JSONDecoder().decode(HARArchive.self, from: JSONEncoder().encode(archive))
        #expect(decoded.records().first?.requestBody == record.requestBody)
        #expect(decoded.records().first?.status == 201)
        #expect(decoded.log.entries.first?.time == 500)
    }
}
