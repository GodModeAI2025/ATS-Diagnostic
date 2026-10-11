import Testing
import Foundation
@testable import ATSDiagnostic
struct BadSSLLiveTests {
    @Test @MainActor func allPublishedBadSSLCases() async throws {
        let suite = BadSSLSuite()
        await suite.run()
        #expect(suite.results.count == BadSSLCase.catalog.count)
        #expect(BadSSLCase.catalog.count == 73)
        let control = try #require(suite.results.first { $0.test.id == "badssl.com" })
        #expect(control.record.status == 200);#expect(control.record.error == nil)
        let expired = try #require(suite.results.first { $0.test.id == "expired.badssl.com" })
        #expect(DiagnosticFailure.explain(expired.record)?.cause == .expired)
        let wrongHost = try #require(suite.results.first { $0.test.id == "wrong.host.badssl.com" })
        #expect(DiagnosticFailure.explain(wrongHost.record)?.cause == .hostname)
        let revoked = try #require(suite.results.first { $0.test.id == "revoked.badssl.com" })
        #expect(revoked.record.revocationAssessment?.status == .revoked)
        #expect(revoked.record.error == nil) // Preserve the distinct observed standard transport result.

        let encoder = JSONEncoder();encoder.outputFormatting = [.prettyPrinted,.sortedKeys];encoder.dateEncodingStrategy = .iso8601
        let folder = URL.documentsDirectory.appendingPathComponent("BadSSL-Live",isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        try encoder.encode(suite.results).write(to:folder.appendingPathComponent("results.json"))
        try suite.report.write(to:folder.appendingPathComponent("report.txt"),atomically:true,encoding:.utf8)
        print("BADSSL_REPORT_PATH " + folder.path)
        for result in suite.results { print("BADSSL_RESULT \(result.test.id) \(result.verdict) \(result.summary)") }
        #expect(suite.results.allSatisfy { $0.record.error == nil || DiagnosticFailure.explain($0.record) != nil })
    }
}
