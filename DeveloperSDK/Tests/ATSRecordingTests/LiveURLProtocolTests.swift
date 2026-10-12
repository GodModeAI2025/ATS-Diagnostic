import Foundation
import Testing
import CryptoKit
@testable import ATSRecording

private let liveProtocolRecorder = try! RecordingClient(previewLimit: 16)
private final class NativeRecordingProtocol: RecordingURLProtocol, @unchecked Sendable {
    static let context: RecordingProtocolContext = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        return try! RecordingProtocolContext(recorder: liveProtocolRecorder, configuration: configuration, previewLimit: 16)
    }()
    override class var recordingContext: RecordingProtocolContext? { context }
}
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["ATS_RECORDING_LIVE"] == "1"))
struct LiveURLProtocolTests {
    @Test(arguments: ["https://example.com/", "https://enbw.com/"])
    func nativeHTTPResponseAndRedirectMetrics(_ target: String) async throws {
        await liveProtocolRecorder.clear()
        let session = try NativeRecordingProtocol.context.makeSession(protocolClass: NativeRecordingProtocol.self)
        defer { session.invalidateAndCancel() }
        let (body, response) = try await session.data(from: URL(string: target)!)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        let record = try #require(await waitForRecord())
        #expect(record.responseBytes == body.count); #expect(record.responseBodyPreview == body.prefix(16))
        #expect(record.responseSHA256 == SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined())
        #expect(record.errorCode == nil); #expect(record.url == target)
        let metrics = try #require(record.metrics)
        #expect(metrics.transactionCount >= 1)
        if target.contains("enbw.com") { #expect(metrics.redirectCount >= 1) }
        print("SDK_PROTOCOL_NATIVE \(target) status200 bytes\(body.count) redirects\(metrics.redirectCount)")
    }
    @Test(arguments: ["https://expired.badssl.com/", "https://wrong.host.badssl.com/"])
    func nativeCertificateRejectionIsPreserved(_ target: String) async throws {
        await liveProtocolRecorder.clear()
        let plain = URLSession(configuration: .ephemeral)
        let session = try NativeRecordingProtocol.context.makeSession(protocolClass: NativeRecordingProtocol.self)
        defer { plain.invalidateAndCancel(); session.invalidateAndCancel() }
        var baseline: NSError?
        do { _ = try await plain.data(from: URL(string: target)!); Issue.record("Baseline unexpectedly trusted target") }
        catch { baseline = error as NSError }
        #expect(try #require(baseline).domain == NSURLErrorDomain)
        var returned: NSError?
        do { _ = try await session.data(from: URL(string: target)!); Issue.record("Recording unexpectedly trusted target") }
        catch { returned = error as NSError }
        let failure = try #require(returned)
        #expect(failure.domain == NSURLErrorDomain)
        #expect([-1200, -1201, -1202, -1203, -1204, -1205, -1206].contains(failure.code))
        let record = try #require(await waitForRecord())
        #expect(record.errorDomain == failure.domain); #expect(record.errorCode == failure.code)
        #expect(record.responseSHA256 == nil); #expect(record.responseBytes == nil)
        print("SDK_PROTOCOL_NATIVE \(target) system rejection\(failure.code) preserved")
    }
    private func waitForRecord() async throws -> RecordedExchange? {
        for _ in 0..<100 {
            if let record = await liveProtocolRecorder.records().first { return record }
            try await Task.sleep(for: .milliseconds(10))
        }
        return nil
    }
}
