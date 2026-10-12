import Foundation
import Testing
@testable import ATSRecording

private final class MetricsHostDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var redirects = 0
    private var completions = 0
    var counts: (Int,Int) { lock.withLock { (redirects,completions) } }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        lock.withLock { redirects += 1 }
        completionHandler(nil)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.withLock { completions += 1 }
    }
}
struct RecordingMetricsTests {
    @Test func missingAndInvalidIntervalsStayUnknown() {
        let now = Date()
        #expect(RecordedTaskMetrics.interval(nil, now) == nil)
        #expect(RecordedTaskMetrics.interval(now, now.addingTimeInterval(-1)) == nil)
        #expect(RecordedTaskMetrics.interval(now, now.addingTimeInterval(0.5)) == 0.5)
    }
    @Test func hostRedirectAndCompletionCallbacksAreForwarded() {
        let host = MetricsHostDelegate()
        let observer = RecordingMetricsDelegate(target: host)
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let task = session.dataTask(with: URL(string:"https://fixture.invalid/")!)
        let response = HTTPURLResponse(url: URL(string:"https://fixture.invalid/")!,statusCode:302,httpVersion:"HTTP/1.1",headerFields:nil)!
        let next = URLRequest(url:URL(string:"https://fixture.invalid/next")!)
        let delegate: any URLSessionTaskDelegate = observer
        delegate.urlSession?(session, task:task, willPerformHTTPRedirection:response, newRequest:next) { request in
            #expect(request == nil)
        }
        delegate.urlSession?(session, task:task, didCompleteWithError:URLError(.cancelled))
        #expect(host.counts.0 == 1)
        #expect(host.counts.1 == 1)
        #expect(observer.snapshot() == nil)
    }
}
@Suite(.enabled(if: ProcessInfo.processInfo.environment["ATS_RECORDING_LIVE"] == "1"))
struct LiveRecordingMetricsTests {
    @Test func realHTTPSMetricsAndCompleteResponse() async throws {
        let session = URLSession(configuration:.ephemeral)
        defer { session.invalidateAndCancel() }
        let recorder = try RecordingClient(previewLimit:8)
        let (body,response) = try await recorder.dataWithMetrics(for:URLRequest(url:URL(string:"https://example.com/")!),using:session)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        let record = try #require(await recorder.records().first)
        let metrics = try #require(record.metrics)
        #expect(metrics.duration >= 0)
        #expect(metrics.transactionCount > 0)
        #expect(metrics.transactions.last?.status == 200)
        #expect(metrics.transactions.last?.url == response.url?.absoluteString)
        #expect(record.responseBytes == body.count)
        #expect(record.responseComplete == true)
        let exported = try await recorder.harData()
        let har = try JSONSerialization.jsonObject(with: exported) as! [String:Any]
        let entries = (har["log"] as! [String:Any])["entries"] as! [[String:Any]]
        #expect((entries[0]["_atsDiagnostic"] as? [String:Any])?["taskMetrics"] != nil)
    }
    @Test func liveHostRedirectDecisionIsPreserved() async throws {
        let host = MetricsHostDelegate()
        let session = URLSession(configuration: .ephemeral, delegate: host, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let recorder = try RecordingClient()
        let (_, response) = try await recorder.dataWithMetrics(for: URLRequest(url: URL(string: "https://enbw.com/")!), using: session)
        let status = try #require((response as? HTTPURLResponse)?.statusCode)
        #expect((300...399).contains(status))
        #expect(host.counts.0 == 1)
        #expect(response.url?.host == "enbw.com")
        let record = try #require(await recorder.records().first)
        #expect(record.metrics?.transactions.last?.status == status)
    }
    @Test(arguments:["https://expired.badssl.com/","https://wrong.host.badssl.com/"])
    func metricsKeepOriginalCertificateRejection(_ target: String) async throws {
        let session = URLSession(configuration:.ephemeral)
        defer { session.invalidateAndCancel() }
        let recorder = try RecordingClient()
        var returned: NSError?
        do { _ = try await recorder.dataWithMetrics(for:URLRequest(url:URL(string:target)!),using:session);Issue.record("Invalid certificate accepted") }
        catch { returned = error as NSError }
        let original = try #require(returned)
        #expect(original.domain == NSURLErrorDomain)
        #expect([-1200,-1201,-1202,-1203,-1204,-1205,-1206].contains(original.code))
        let record = try #require(await recorder.records().first)
        #expect(record.errorCode == original.code)
        #expect(record.errorDomain == original.domain)
        #expect(record.responseComplete == false)
        #expect(record.responseSHA256 == nil)
    }
}
