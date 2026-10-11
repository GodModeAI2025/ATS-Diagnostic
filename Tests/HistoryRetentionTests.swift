import Foundation
import Testing
@testable import ATSDiagnostic

struct HistoryRetentionTests {
    @Test func countLimitRetainsNewest() throws {
        let records = (0..<3).map { DiagnosticRecord(url:"https://example.com/\($0)",method:"GET") }
        #expect(try HistoryRetention.retain(records,countLimit:2).map(\.id) == records.prefix(2).map(\.id))
    }
    @Test func actualEncodedBytesIncludeCertificatesAndEscapedBodies() throws {
        var first = DiagnosticRecord(url:"https://example.com/new",method:"GET")
        first.responseBody = String(repeating:"\"\\\n",count:100)
        first.certificates = [CertificateRecord(id:"certificate",subject:"Fixture",der:Data(repeating:255,count:128))]
        let second = DiagnosticRecord(url:"https://example.com/old",method:"GET")
        let limit = try JSONEncoder().encode([first]).count
        let retained = try HistoryRetention.retain([first,second],countLimit:10,byteLimit:limit)
        #expect(retained.map(\.id) == [first.id])
        #expect(try JSONEncoder().encode(retained).count <= limit)
    }
    @Test func exactArrayBoundaryIncludesComma() throws {
        let records = [DiagnosticRecord(url:"https://example.com/1",method:"GET"),DiagnosticRecord(url:"https://example.com/2",method:"GET")]
        let size = try JSONEncoder().encode(records).count
        #expect(try HistoryRetention.retain(records,countLimit:10,byteLimit:size).count == 2)
        #expect(try HistoryRetention.retain(records,countLimit:10,byteLimit:size-1).count == 1)
    }
    @Test func oversizedNewestDoesNotKeepAnOlderPrefix() throws {
        let records = [DiagnosticRecord(url:"https://example.com/new",method:"GET"),DiagnosticRecord(url:"https://example.com/old",method:"GET")]
        #expect(try HistoryRetention.retain(records,countLimit:10,byteLimit:2).isEmpty)
        #expect(try HistoryRetention.retain(records,countLimit:0).isEmpty)
    }
}
