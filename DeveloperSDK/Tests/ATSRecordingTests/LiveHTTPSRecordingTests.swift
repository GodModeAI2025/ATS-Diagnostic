import Foundation
import Testing
@testable import ATSRecording

@Suite(.enabled(if: ProcessInfo.processInfo.environment["ATS_RECORDING_LIVE"] == "1"))
struct LiveHTTPSRecordingTests {
    private func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        return URLSession(configuration: configuration)
    }
    @Test func liveResponseIsReturnedAndRecorded() async throws {
        let recorder = try RecordingClient(previewLimit: 16)
        let session = session(); defer { session.invalidateAndCancel() }
        let (body,response) = try await recorder.data(for:URLRequest(url:URL(string:"https://example.com/")!),using:session)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        let record = try #require(await recorder.records().first)
        #expect(record.status == 200);#expect(record.responseBytes == body.count)
        #expect(record.responseBodyPreview == Data(body.prefix(16)));#expect(record.errorCode == nil)
        print("SDK_LIVE_PROOF example.com HTTP 200 bytes \(body.count) preview \(record.responseBodyPreview.count)")
    }
    @Test(arguments:["https://expired.badssl.com/","https://wrong.host.badssl.com/"])
    func certificateFailureMatchesTheUnwrappedSession(_ target:String) async throws {
        let session = session();defer { session.invalidateAndCancel() }
        let request = URLRequest(url:URL(string:target)!)
        var baseline: NSError?
        do { _ = try await session.data(for:request);Issue.record("System session unexpectedly accepted target") }
        catch { baseline = error as NSError }
        let original = try #require(baseline)
        #expect(original.domain == NSURLErrorDomain)
        #expect([-1200,-1201,-1202,-1203,-1204,-1205,-1206].contains(original.code))
        let recorder = try RecordingClient()
        do { _ = try await recorder.data(for:request,using:session);Issue.record("Recorder unexpectedly accepted target") }
        catch { #expect((error as NSError).domain == original.domain);#expect((error as NSError).code == original.code) }
        let record = try #require(await recorder.records().first)
        #expect(record.errorDomain == original.domain);#expect(record.errorCode == original.code)
        #expect(record.status == nil);#expect(record.responseBytes == nil);#expect(record.responseSHA256 == nil)
        print("SDK_LIVE_PROOF \(target) original/recorded \(original.domain) \(original.code)")
    }
}
