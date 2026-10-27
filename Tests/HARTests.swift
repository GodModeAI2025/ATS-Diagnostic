import Testing
import Foundation
import CoreTransferable
@testable import ATSDiagnostic
struct HARTests {
    @available(iOS 18.2, macCatalyst 18.2, *)
    @Test func transferableFileRoundTripPreservesCapturedEvidence() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let date = Date(timeIntervalSince1970: 1_700_000_000.125)
        let body = "Grüße 🔐\n"
        let success = DiagnosticRecord(date: date, url: "https://example.com/api?a=1&a=2&name=Gr%C3%BC%C3%9Fe", method: "POST", requestHeaders: ["Content-Type": "text/plain; charset=utf-8", "X-Test": "fixture"], requestBody: body, status: 201, responseHeaders: ["Content-Type": "application/octet-stream"], responseBody: "AP+A", responseEncoding: "base64", bytes: 3, duration: 0.125, protocolName: "h2", remoteAddress: "192.0.2.1", dnsDuration: 0.002, connectDuration: 0.025, tlsDuration: 0.02)
        let failure = DiagnosticRecord(date: date, url: "https://expired.badssl.com/", method: "GET", error: "Certificate expired", networkErrors: [ErrorEvidence(domain: NSURLErrorDomain, code: -1202, message: "Certificate expired", sslCode: nil)], responseByteCountKnown: false)
        let archive = HARArchive(records: [success, failure])
        let file = try await archive.export(to: directory, contentType: nil)
        #expect(file.lastPathComponent == "ATS-Diagnostic.har")
        let data = try Data(contentsOf: file)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let log = try #require(json["log"] as? [String: Any])
        #expect(log["version"] as? String == "1.2")
        #expect(archive.log.entries[0].request.bodySize == body.utf8.count)
        #expect(archive.log.entries[0].request.queryString.map(\.value) == ["1", "2", "Grüße"])
        let imported = try HARArchive.importRecords(data)
        #expect(imported.count == 2)
        let restored = imported[0]
        #expect(restored.date == date)
        #expect(restored.url == success.url && restored.method == "POST")
        #expect(restored.requestHeaders == success.requestHeaders && restored.requestBody == body)
        #expect(restored.responseHeaders == success.responseHeaders)
        #expect(restored.responseEncoding == "base64" && Data(base64Encoded: restored.responseBody) == Data([0, 255, 128]))
        #expect(restored.bytes == 3 && restored.status == 201 && restored.duration == 0.125)
        #expect(restored.remoteAddress == success.remoteAddress)
        #expect(restored.dnsDuration == 0.002 && restored.connectDuration == 0.025 && restored.tlsDuration == 0.02)
        #expect(restored.origin == .har && restored.trustValid == nil && restored.certificates.isEmpty)
        #expect(restored.canReplay)
        #expect(imported[1].status == nil && imported[1].responseByteCountKnown == false)
        #expect(imported[1].error == failure.error && imported[1].networkErrors == failure.networkErrors)
        #expect(try HARArchive(records: []).records().isEmpty)
    }
    @Test func preservesReplayData() throws {
        let record = DiagnosticRecord(url: "https://example.com/api?a=1", method: "POST", requestHeaders: ["Content-Type": "application/json"], requestBody: "{\"a\":1}", status: 201, responseBody: "ok", bytes: 2, duration: 0.5)
        let archive = HARArchive(records: [record])
        let decoded = try JSONDecoder().decode(HARArchive.self, from: JSONEncoder().encode(archive))
        #expect(try decoded.records().first?.requestBody == record.requestBody)
        #expect(try decoded.records().first?.status == 201)
        #expect(decoded.log.entries.first?.time == 500)
    }
}

struct ExternalHARTests {
    @Test(arguments: ["{}", #"{"log":{"entries":{}}}"#, #"{"log":{"entries":[{"request":{"url":"https://user:secret@example.com"}}]}}"#, #"{"log":{"entries":[{}]}}"#])
    func rejectsMalformedOrCredentialBearingRequests(_ json: String) {
        #expect(throws: (any Error).self) { try HARArchive.importRecords(Data(json.utf8)) }
    }
    @Test func rejectsExcessiveEntryCount() throws {
        let root = ["log": ["entries": Array(repeating: ["request": ["url": "https://example.com"]], count: 10_001)]]
        let data = try JSONSerialization.data(withJSONObject: root)
        #expect(throws: HARArchive.ImportError.self) { try HARArchive.importRecords(data) }
    }
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
