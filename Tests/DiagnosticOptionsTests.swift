import Foundation
import Testing
import CryptoKit
@testable import ATSDiagnostic

struct DiagnosticOptionsTests {
    @Test func rejectsUnboundedOrNonFiniteValues() {
        for value in [Double.nan, .infinity, -1, 0, 301] {
            #expect(throws: (any Error).self) { try DiagnosticOptions(requestTimeout:value).validate() }
        }
        #expect(throws: (any Error).self) { try DiagnosticOptions(resourceTimeout:3601).validate() }
        #expect(throws: (any Error).self) { try DiagnosticOptions(bodyPreviewBytes:-1).validate() }
        #expect(throws: (any Error).self) { try DiagnosticOptions(bodyPreviewBytes:16 * 1024 * 1024 + 1).validate() }
    }
    @Test func resourceDeadlineCanBeShorterThanIdleDeadline() throws {
        try DiagnosticOptions(requestTimeout:60,resourceTimeout:5).validate()
    }
    @Test func invalidPersistedValuesFallBackToStandard() throws {
        let data = Data(#"{"requestTimeout":0,"resourceTimeout":30,"bodyPreviewBytes":0}"#.utf8)
        #expect(try JSONDecoder().decode(DiagnosticOptions.self,from:data).validated == .standard)
    }
    @Test func configurationAndActualRequestUseSelectedLimits() throws {
        let configuration = URLSessionConfiguration.ephemeral
        let initial = URLRequest(url:try #require(URL(string:"https://example.com")))
        let configured = DiagnosticOptions(requestTimeout:7,resourceTimeout:120).configure(configuration,request:initial)
        #expect(configured.timeoutInterval == 7)
        #expect(configuration.timeoutIntervalForRequest == 7)
        #expect(configuration.timeoutIntervalForResource == 120)
        #expect(configuration.urlCredentialStorage == nil)
        #expect(configuration.urlCache == nil)
    }
    @Test func smallPreviewDoesNotChangeCompleteResponseHash() async throws {
        let request = URLRequest(url:try #require(URL(string:"https://integrity-fixture.test/download")))
        let options = DiagnosticOptions(requestTimeout:7,resourceTimeout:120,bodyPreviewBytes:64)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [IntegrityFixtureProtocol.self]
        let record = await DiagnosticEngine(request:request,options:options).run(request,configuration:configuration)
        #expect(record.diagnosticOptions == options)
        #expect(record.responseBody.utf8.count == 64)
        #expect(record.bytes == IntegrityFixtureProtocol.payload.count)
        #expect(record.responseSHA256 == SHA256.hash(data:IntegrityFixtureProtocol.payload).map { String(format:"%02x",$0) }.joined())
    }
    @Test func previewCanBeDisabledWithoutLosingHashOrByteCount() async throws {
        let request = URLRequest(url:try #require(URL(string:"https://integrity-fixture.test/download")))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [IntegrityFixtureProtocol.self]
        let record = await DiagnosticEngine(request:request,options:DiagnosticOptions(bodyPreviewBytes:0)).run(request,configuration:configuration)
        #expect(record.responseBody.isEmpty)
        #expect(record.bytes == IntegrityFixtureProtocol.payload.count)
        #expect(record.responseSHA256 == SHA256.hash(data:IntegrityFixtureProtocol.payload).map { String(format:"%02x",$0) }.joined())
    }
    @Test func historicalRecordsWithoutOptionsStillDecode() throws {
        let record = DiagnosticRecord(url:"https://example.com",method:"GET")
        var json = try #require(JSONSerialization.jsonObject(with:JSONEncoder().encode(record)) as? [String:Any])
        json.removeValue(forKey:"diagnosticOptions")
        let decoded = try JSONDecoder().decode(DiagnosticRecord.self,from:JSONSerialization.data(withJSONObject:json))
        #expect(decoded.diagnosticOptions == nil)
    }
}
