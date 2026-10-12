import Foundation
import Testing
import CryptoKit
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
        try writeHARFixture(try await recorder.harData(), name: "SDK-Live-Example")
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
        var returnedError: NSError?
        do { _ = try await recorder.data(for:request,using:session);Issue.record("Recorder unexpectedly accepted target") }
        catch { returnedError = error as NSError }
        let returned = try #require(returnedError)
        #expect(returned.domain == original.domain)
        #expect([-1200,-1201,-1202,-1203,-1204,-1205,-1206].contains(returned.code))
        let record = try #require(await recorder.records().first)
        #expect(record.errorDomain == original.domain);#expect(record.errorCode == returned.code)
        #expect(record.status == nil);#expect(record.responseBytes == nil);#expect(record.responseSHA256 == nil)
        try writeHARFixture(try await recorder.harData(), name: "SDK-Live-" + (URL(string: target)?.host ?? "unknown"))
        print("SDK_LIVE_PROOF \(target) baseline \(original.code); returned/recorded \(returned.domain) \(returned.code)")
    }
    @MainActor @Test func liveStreamingResponseKeepsEveryByteAndFullHash() async throws {
        let recorder = try RecordingClient(previewLimit: 16)
        let session = session(); defer { session.invalidateAndCancel() }
        let (stream, response) = try await recorder.bytes(for: URLRequest(url: URL(string: "https://example.com/")!), using: session)
        var body = Data()
        for try await byte in stream { body.append(byte) }
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        let record = try #require(await recorder.records().first)
        #expect(record.responseBytes == body.count)
        #expect(record.responseBodyPreview == body.prefix(16))
        #expect(record.responseSHA256 == SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined())
        #expect(record.errorCode == nil)
        try writeHARFixture(try await recorder.harData(), name: "SDK-Stream-Live-Example")
        print("SDK_STREAM_LIVE_PROOF example.com HTTP 200 bytes \(body.count) full SHA256 matched")
    }
    @Test(arguments: ["https://expired.badssl.com/", "https://wrong.host.badssl.com/"])
    func streamingCertificateFailurePreservesDefaultSessionRejection(_ target: String) async throws {
        let session = session(); defer { session.invalidateAndCancel() }
        let request = URLRequest(url: URL(string: target)!)
        var baseline: NSError?
        do {
            let (bytes, _) = try await session.bytes(for: request)
            for try await _ in bytes {}
            Issue.record("System stream unexpectedly accepted target")
        } catch { baseline = error as NSError }
        let original = try #require(baseline)
        #expect(original.domain == NSURLErrorDomain)
        #expect([-1200, -1201, -1202, -1203, -1204, -1205, -1206].contains(original.code))
        let recorder = try RecordingClient()
        var returnedError: NSError?
        do {
            let (stream, _) = try await recorder.bytes(for: request, using: session)
            for try await _ in stream {}
            Issue.record("Recorded stream unexpectedly accepted target")
        } catch { returnedError = error as NSError }
        let returned = try #require(returnedError)
        #expect(returned.domain == original.domain)
        #expect([-1200, -1201, -1202, -1203, -1204, -1205, -1206].contains(returned.code))
        let record = try #require(await recorder.records().first)
        #expect(record.errorDomain == returned.domain); #expect(record.errorCode == returned.code)
        #expect(record.status == nil); #expect(record.responseBytes == nil); #expect(record.responseSHA256 == nil)
        try writeHARFixture(try await recorder.harData(), name: "SDK-Stream-Live-" + (URL(string: target)?.host ?? "unknown"))
        print("SDK_STREAM_LIVE_PROOF \(target) baseline \(original.code); returned/recorded \(returned.domain) \(returned.code)")
    }

}
