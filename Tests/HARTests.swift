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

struct ExternalHARTests {
    @Test func acceptsBrowserCookiesAndOptionalBodies() throws {
        let json = #"{"log":{"version":"1.2","entries":[{"startedDateTime":"2026-10-11T17:00:00.123Z","time":150,"request":{"url":"https://example.com","method":"GET","headers":[],"cookies":[{"name":"test","value":"cookie"}]},"response":{"status":204,"headers":[],"content":{"size":0,"mimeType":"text/plain"},"cookies":[]},"cache":{"beforeRequest":{"lastAccess":"ignored"}},"timings":{"dns":12,"ssl":-1}}]}}"#
        let records = try HARArchive.importRecords(Data(json.utf8))
        #expect(records.first?.responseBody == "")
        #expect(records.first?.duration == 0.15)
        #expect(records.first?.dnsDuration == 0.012)
        #expect(records.first?.tlsDuration == nil)
    }
    @Test func preservesBinaryEncoding() throws {
        let record = DiagnosticRecord(url: "https://example.com", method: "GET", status: 200, responseBody: "AQID", responseEncoding: "base64", bytes: 3)
        let imported = try HARArchive.importRecords(JSONEncoder().encode(HARArchive(records: [record])))
        #expect(imported.first?.responseEncoding == "base64")
        #expect(imported.first?.responseBody == "AQID")
    }
}
