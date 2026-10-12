import Foundation
import Testing
@testable import ATSRecording

private final class DelegateFixture: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "delegate.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [:])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("abc".utf8))
        if request.url?.path == "/partial" {
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { [self] in
                client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost))
            }
        }
        else { client?.urlProtocolDidFinishLoading(self) }
    }
    override func stopLoading() {}
}
private final class DelegateHost: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    let results: AsyncStream<(Data, Int?, Int?)>
    private let continuation: AsyncStream<(Data, Int?, Int?)>.Continuation
    private let lock = NSLock()
    private var bodies: [ObjectIdentifier: Data] = [:]
    private let cancelRedirect: Bool
    private var redirects = 0
    var redirectCount: Int { lock.withLock { redirects } }
    init(cancelRedirect: Bool = false) {
        self.cancelRedirect = cancelRedirect
        let pair = AsyncStream<(Data, Int?, Int?)>.makeStream()
        results = pair.stream; continuation = pair.continuation
        super.init()
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        lock.withLock { redirects += 1 }
        completionHandler(cancelRedirect ? nil : request)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.withLock { bodies[ObjectIdentifier(dataTask), default: Data()].append(data) }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        let data = lock.withLock { bodies.removeValue(forKey: ObjectIdentifier(task)) ?? Data() }
        continuation.yield((data, (error as NSError?)?.code, (task.response as? HTTPURLResponse)?.statusCode))
    }
}
struct RecordingSessionDelegateTests {
    @Test func sharedObserverSeparatesIdenticalTaskNumbersAcrossSessions() async throws {
        let recorder = try RecordingClient()
        let observation = try await recorder.observe()
        let host = DelegateHost()
        let observer = RecordingSessionDelegate(recorder: recorder, forwardingTo: host)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DelegateFixture.self]
        let first = URLSession(configuration: config, delegate: observer, delegateQueue: nil)
        let second = URLSession(configuration: config, delegate: observer, delegateQueue: nil)
        defer { first.invalidateAndCancel(); second.invalidateAndCancel() }
        let one = first.dataTask(with: URL(string: "https://delegate.invalid/one")!)
        let two = second.dataTask(with: URL(string: "https://delegate.invalid/two")!)
        #expect(one.taskIdentifier == two.taskIdentifier)
        one.resume(); two.resume()
        var results = host.results.makeAsyncIterator()
        for _ in 0..<2 { #expect(try #require(await results.next()).0 == Data("abc".utf8)) }
        var recorded = 0
        for await event in observation.events {
            if case .recorded = event.kind { recorded += 1 }
            if recorded == 2 { break }
        }
        await observation.cancel()
        let entries = await recorder.records()
        #expect(entries.count == 2)
        #expect(Set(entries.map(\.url)) == ["https://delegate.invalid/one", "https://delegate.invalid/two"])
        #expect(entries.allSatisfy { $0.responseBytes == 3 && $0.responseComplete == true })
    }
    @Test(arguments: [false, true])
    func delegateReceivesUnchangedBodyAndOriginalFailure(partial: Bool) async throws {
        let recorder = try RecordingClient(previewLimit: 2)
        let observation = try await recorder.observe()
        let host = DelegateHost()
        let delegate = RecordingSessionDelegate(recorder: recorder, forwardingTo: host, previewLimit: 2)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DelegateFixture.self]
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let task = session.dataTask(with: URL(string: "https://delegate.invalid/\(partial ? "partial" : "body")")!)
        task.resume()
        var hostEvents = host.results.makeAsyncIterator()
        let received = try #require(await hostEvents.next())
        #expect(received.0.isEmpty || received.0 == Data("abc".utf8))
        if !partial { #expect(received.0 == Data("abc".utf8)) }
        #expect(received.1 == (partial ? URLError.networkConnectionLost.rawValue : nil))
        for await event in observation.events { if case .recorded = event.kind { break } }
        await observation.cancel()
        let record = try #require(await recorder.records().first)
        #expect(record.responseBodyPreview == Data(received.0.prefix(2)))
        #expect(record.responseBytes == (received.0.isEmpty ? nil : received.0.count))
        #expect(record.responseComplete == !partial)
        #expect(record.errorCode == received.1)
        #expect((record.responseSHA256 != nil) == !partial)
    }
}


@Suite(.enabled(if: ProcessInfo.processInfo.environment["ATS_RECORDING_LIVE"] == "1"))
struct RecordingSessionDelegateLiveTests {
    @Test(arguments: ["https://example.com/", "https://expired.badssl.com/", "https://wrong.host.badssl.com/"])
    func nativeHTTPSPreservesBodyOrOriginalTrustFailure(_ url: String) async throws {
        let recorder = try RecordingClient(previewLimit: 16)
        let observation = try await recorder.observe()
        let host = DelegateHost()
        let observer = RecordingSessionDelegate(recorder: recorder, forwardingTo: host)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15; config.timeoutIntervalForResource = 20
        let session = URLSession(configuration: config, delegate: observer, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        session.dataTask(with: URL(string: url)!).resume()
        var iterator = host.results.makeAsyncIterator()
        let received = try #require(await iterator.next())
        for await event in observation.events { if case .recorded = event.kind { break } }
        await observation.cancel()
        let record = try #require(await recorder.records().first)
        #expect(record.errorCode == received.1)
        #expect(record.status == received.2)
        if url.contains("example.com") {
            #expect(received.2 == 200); #expect(!received.0.isEmpty)
            #expect(record.responseBytes == received.0.count)
            #expect(record.responseBodyPreview == Data(received.0.prefix(16)))
            #expect(record.responseSHA256 != nil)
        } else {
            let code = try #require(received.1)
            #expect([-1200,-1201,-1202,-1203,-1204,-1205,-1206].contains(code))
            #expect(record.responseSHA256 == nil)
        }
    }
    @Test func hostCanRejectRedirectThroughObserver() async throws {
        let recorder = try RecordingClient()
        let observation = try await recorder.observe()
        let host = DelegateHost(cancelRedirect: true)
        let observer = RecordingSessionDelegate(recorder: recorder, forwardingTo: host)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15; config.timeoutIntervalForResource = 20
        let session = URLSession(configuration: config, delegate: observer, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        session.dataTask(with: URL(string: "https://enbw.com/")!).resume()
        var iterator = host.results.makeAsyncIterator()
        let received = try #require(await iterator.next())
        #expect(host.redirectCount == 1)
        #expect((300...399).contains(try #require(received.2)))
        for await event in observation.events { if case .recorded = event.kind { break } }
        await observation.cancel()
        #expect(await recorder.records().first?.status == received.2)
    }
}
