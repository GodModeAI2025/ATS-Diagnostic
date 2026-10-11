import Foundation
import Testing
@testable import ATSDiagnostic

private final class SDKHARResourceScope: NSObject {}
struct SDKHARImportTests {
    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle(for: SDKHARResourceScope.self).url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }
    @Test func actualSDKSuccessKeepsPreviewAndReportedHash() throws {
        let record = try #require(HARArchive.importRecords(fixture("SDK-Live-Example")).first)
        #expect(record.origin == .developerSDK); #expect(record.status == 200)
        #expect(record.responseEncoding == "base64"); #expect(Data(base64Encoded: record.responseBody)?.count == 16)
        #expect(record.bytes > 16); #expect(record.responseByteCountKnown == true)
        #expect(record.responseSHA256?.count == 64); #expect(record.trustValid == nil); #expect(record.certificates.isEmpty)
        #expect(record.canReplay); #expect(record.protocolName == nil)
    }
    @Test(arguments: ["SDK-Live-expired.badssl.com", "SDK-Live-wrong.host.badssl.com"])
    func actualSDKFailuresRetainErrorsWithoutInventingResponseBytes(_ name: String) throws {
        let record = try #require(HARArchive.importRecords(fixture(name)).first)
        #expect(record.origin == .developerSDK); #expect(record.status == nil)
        #expect(record.networkErrors?.first?.domain == NSURLErrorDomain)
        let root = try #require(JSONSerialization.jsonObject(with: fixture(name)) as? [String: Any])
        let log = try #require(root["log"] as? [String: Any])
        let entry = try #require((log["entries"] as? [[String: Any]])?.first)
        let metadata = try #require(entry["_atsDiagnostic"] as? [String: Any])
        #expect(record.networkErrors?.first?.code == metadata["errorCode"] as? Int); #expect(record.error != nil)
        #expect(record.responseByteCountKnown == false); #expect(record.responseSHA256 == nil)
        #expect(record.trustValid == nil); #expect(TrafficStatistics([record]).failures == 1)
    }
    @Test func incompleteSDKRequestCannotReplayEvenAfterAppReExport() throws {
        let record = try #require(HARArchive.importRecords(fixture("SDK-Post-Partial")).first)
        #expect(!record.canReplay); #expect(record.requestBody.isEmpty)
        #expect(record.importedRequestBodyPreview == Data("com".utf8)); #expect(record.importedRequestBodyBytes == 13)
        let importedAgain = try #require(HARArchive(records: [record]).records().first)
        #expect(!importedAgain.canReplay); #expect(importedAgain.origin == .developerSDK)
        #expect(importedAgain.importedRequestBodyPreview == record.importedRequestBodyPreview)
        #expect(importedAgain.importedRequestBodyBytes == 13); #expect(importedAgain.protocolName == nil)
    }
    @Test func importedClaimsNeverBecomeSystemTrustResults() throws {
        let data = Data(#"{"log":{"entries":[{"request":{"url":"https://example.com","method":"GET"},"response":{"status":200,"content":{"size":0}},"_atsDiagnostic":{"source":"ATSRecording","trustValid":true,"certificateTransparency":true,"responseSHA256":"not-a-hash"}}]}}"#.utf8)
        let record = try #require(HARArchive.importRecords(data).first)
        #expect(record.origin == .developerSDK); #expect(record.trustValid == nil)
        #expect(record.certificateTransparency == nil); #expect(record.responseSHA256 == nil)
    }
    @Test func incompleteBodyCannotBeEnabledByImportMetadata() throws {
        let data = Data(#"{"log":{"entries":[{"request":{"url":"https://example.com","method":"POST","bodySize":13},"response":{"status":200,"content":{"size":0}},"_atsDiagnostic":{"source":"ATSRecording","requestBodyUnavailable":false}}]}}"#.utf8)
        let record = try #require(HARArchive.importRecords(data).first)
        #expect(!record.canReplay); #expect(record.requestBody.isEmpty)
    }

}
