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
private final class ProtocolPolicyDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let rejectRedirect: Bool
    let cancelAuthentication: Bool
    private let lock = NSLock()
    private var redirects = 0
    private var challenges = 0
    private var metrics = 0
    private var completions = 0
    private var completionError: Int?
    var redirectCount: Int { lock.withLock { redirects } }
    var challengeCount: Int { lock.withLock { challenges } }
    var metricsCount: Int { lock.withLock { metrics } }
    var completionCount: Int { lock.withLock { completions } }
    var lastCompletionError: Int? { lock.withLock { completionError } }
    init(rejectRedirect: Bool, cancelAuthentication: Bool) {
        self.rejectRedirect = rejectRedirect; self.cancelAuthentication = cancelAuthentication
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        lock.withLock { redirects += 1 }
        completionHandler(rejectRedirect ? nil : request)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        lock.withLock { self.metrics += 1 }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        lock.withLock { completions += 1; completionError = (error as NSError?)?.code }
    }
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        lock.withLock { challenges += 1 }
        completionHandler(cancelAuthentication ? .cancelAuthenticationChallenge : .performDefaultHandling, nil)
    }
}
private final class RedirectPolicyRecordingProtocol: RecordingURLProtocol, @unchecked Sendable {
    static let recorder = try! RecordingClient()
    static let policy = ProtocolPolicyDelegate(rejectRedirect: true, cancelAuthentication: false)
    static let context = try! RecordingProtocolContext(recorder: recorder, transportDelegate: policy)
    override class var recordingContext: RecordingProtocolContext? { context }
}
private final class AuthenticationPolicyRecordingProtocol: RecordingURLProtocol, @unchecked Sendable {
    static let recorder = try! RecordingClient()
    static let policy = ProtocolPolicyDelegate(rejectRedirect: false, cancelAuthentication: true)
    static let context = try! RecordingProtocolContext(recorder: recorder, transportDelegate: policy)
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
    @Test func nativeTransportDelegateCanRejectRedirectWithoutLosingResponse() async throws {
        let recorder = RedirectPolicyRecordingProtocol.recorder
        await recorder.clear()
        let session = try RedirectPolicyRecordingProtocol.context.makeSession(protocolClass: RedirectPolicyRecordingProtocol.self)
        defer { session.invalidateAndCancel() }
        let (_, response) = try await session.data(from: URL(string: "https://enbw.com/")!)
        #expect((response as? HTTPURLResponse)?.statusCode == 301)
        #expect(RedirectPolicyRecordingProtocol.policy.redirectCount > 0)
        let record = try #require(await waitForRecord(in: recorder))
        #expect(record.status == 301); #expect(record.errorCode == nil)
        #expect(record.metrics?.redirectCount == 0)
        try await waitForCompletion(of: RedirectPolicyRecordingProtocol.policy)
        #expect(RedirectPolicyRecordingProtocol.policy.metricsCount == 1)
        #expect(RedirectPolicyRecordingProtocol.policy.completionCount == 1)
        #expect(RedirectPolicyRecordingProtocol.policy.lastCompletionError == nil)
    }
    @Test func nativeTransportDelegateCanCancelAuthenticationWithoutOverride() async throws {
        let recorder = AuthenticationPolicyRecordingProtocol.recorder
        await recorder.clear()
        let session = try AuthenticationPolicyRecordingProtocol.context.makeSession(protocolClass: AuthenticationPolicyRecordingProtocol.self)
        defer { session.invalidateAndCancel() }
        var returned: NSError?
        do {
            _ = try await session.data(from: URL(string: "https://example.com/")!)
            Issue.record("Transport delegate cancellation was ignored")
        } catch { returned = error as NSError }
        let failure = try #require(returned)
        #expect(failure.domain == NSURLErrorDomain); #expect(failure.code == URLError.cancelled.rawValue)
        #expect(AuthenticationPolicyRecordingProtocol.policy.challengeCount > 0)
        let record = try #require(await waitForRecord(in: recorder))
        #expect(record.errorDomain == failure.domain); #expect(record.errorCode == failure.code)
        #expect(record.responseComplete == false); #expect(record.responseSHA256 == nil)
        try await waitForCompletion(of: AuthenticationPolicyRecordingProtocol.policy)
        #expect(AuthenticationPolicyRecordingProtocol.policy.completionCount == 1)
        #expect(AuthenticationPolicyRecordingProtocol.policy.lastCompletionError == failure.code)
    }
    private func waitForCompletion(of policy: ProtocolPolicyDelegate) async throws {
        for _ in 0..<100 {
            if policy.completionCount > 0 { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Missing original transport completion callback")
    }
    private func waitForRecord(in recorder: RecordingClient = liveProtocolRecorder) async throws -> RecordedExchange? {
        for _ in 0..<100 {
            if let record = await recorder.records().first { return record }
            try await Task.sleep(for: .milliseconds(10))
        }
        return nil
    }
}
