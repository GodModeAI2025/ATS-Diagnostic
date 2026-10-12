import Foundation

/// Immutable transport settings and an independently bounded journal observer.
/// A host subclass supplies one stable context; no process-wide registration is used.
public final class RecordingProtocolContext: @unchecked Sendable {
    public enum ConfigurationError: Error { case backgroundSession, mismatchedProtocol }
    let recorder: RecordingClient
    let previewLimit: Int
    private let configuration: URLSessionConfiguration
    private let lock = NSLock()
    private var active = 0
    private var omitted = 0
    public var omittedCaptureCount: Int { lock.withLock { omitted } }

    public init(recorder: RecordingClient, configuration: URLSessionConfiguration = .ephemeral, previewLimit: Int = 64 * 1024) throws {
        guard configuration.identifier == nil else { throw ConfigurationError.backgroundSession }
        self.recorder = recorder
        self.previewLimit = max(0, min(previewLimit, 64 * 1024))
        self.configuration = configuration.copy() as! URLSessionConfiguration
        self.configuration.protocolClasses = configuration.protocolClasses?.filter { !($0 is RecordingURLProtocol.Type) }
    }

    /// New sessions automatically record supported HTTP data loads, including async
    /// and completion-handler calls. Existing sessions are not modified.
    /// Use the existing-session wrappers for host-specific authentication delegates.
    public func makeSession(protocolClass: RecordingURLProtocol.Type) throws -> URLSession {
        guard protocolClass.recordingContext === self else { throw ConfigurationError.mismatchedProtocol }
        let copy = forwardingConfiguration()
        copy.protocolClasses = [protocolClass] + (copy.protocolClasses ?? [])
        return URLSession(configuration: copy)
    }
    func forwardingConfiguration() -> URLSessionConfiguration { configuration.copy() as! URLSessionConfiguration }
    func beginCapture() -> Bool {
        lock.withLock {
            guard active < 64 else { if omitted < Int.max { omitted += 1 }; return false }
            active += 1; return true
        }
    }
    func endCapture() { lock.withLock { active -= 1 } }
}

/// Subclass in the host and override recordingContext with a stable static context.
/// The forwarding session uses normal system trust; no accept-all handler exists.
open class RecordingURLProtocol: URLProtocol, URLSessionDataDelegate, @unchecked Sendable {
    open class var recordingContext: RecordingProtocolContext? { nil }
    open override class func canInit(with request: URLRequest) -> Bool {
        guard recordingContext != nil, request.httpBodyStream == nil,
              let scheme = request.url?.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
    open override class func canInit(with task: URLSessionTask) -> Bool {
        guard !(task is URLSessionUploadTask), let request = task.originalRequest else { return false }
        return canInit(with: request)
    }
    open override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    private let stateLock = NSRecursiveLock()
    private var forwardingSession: URLSession?
    private var forwardingTask: URLSessionDataTask?
    private var context: RecordingProtocolContext?
    private var accumulator: RecordingResponseAccumulator?
    private var recordingRequest: URLRequest?
    private var response: HTTPURLResponse?
    private var metrics: RecordedTaskMetrics?
    private var terminal = false
    private let date = Date()
    private let began = ContinuousClock.now

    open override func startLoading() {
        stateLock.withLock {
            guard !terminal, forwardingSession == nil else { return }
            guard let value = type(of: self).recordingContext else {
                terminal = true
                client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL)); return
            }
            context = value
            if value.beginCapture() { accumulator = RecordingResponseAccumulator(previewLimit: value.previewLimit) }
            let queue = OperationQueue(); queue.maxConcurrentOperationCount = 1
            let session = URLSession(configuration: value.forwardingConfiguration(), delegate: self, delegateQueue: queue)
            forwardingSession = session
            // Foundation exposes a Data-backed POST as a stream in URLProtocol.request.
            // Recover the original Data without consuming the one-shot stream.
            var forwarded = request
            if let body = task?.originalRequest?.httpBody {
                forwarded.httpBodyStream = nil
                forwarded.httpBody = body
            }
            recordingRequest = forwarded
            let transfer = session.dataTask(with: forwarded)
            forwardingTask = transfer
            transfer.resume()
        }
    }
    open override func stopLoading() {
        stateLock.withLock {
            guard !terminal else { return }
            finish(error: URLError(.cancelled) as NSError, success: false)
            forwardingTask?.cancel()
            forwardingSession?.invalidateAndCancel()
            forwardingSession = nil; forwardingTask = nil
        }
    }
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
        stateLock.withLock {
            guard !terminal else { completionHandler(.cancel); return }
            self.response = response as? HTTPURLResponse
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            completionHandler(.allow)
        }
    }
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        stateLock.withLock {
            guard !terminal else { return }
            accumulator?.receive(data)
            client?.urlProtocol(self, didLoad: data)
        }
    }
    public func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        stateLock.withLock { if !terminal { self.metrics = RecordedTaskMetrics(metrics) } }
    }
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        stateLock.withLock {
            guard !terminal else { return }
            finish(error: error as NSError?, success: error == nil)
            if let error { client?.urlProtocol(self, didFailWithError: error) }
            else { client?.urlProtocolDidFinishLoading(self) }
            session.finishTasksAndInvalidate()
            forwardingSession = nil; forwardingTask = nil
        }
    }
    private func finish(error: NSError?, success: Bool) {
        terminal = true
        guard let context, let accumulator else { return }
        let body = accumulator.snapshot(transportSucceeded: success)
        let response = self.response, metrics = self.metrics, request = recordingRequest ?? self.request
        let date = self.date, began = self.began
        context.endCapture()
        self.accumulator = nil
        Task {
            await context.recorder.recordDelegateTask(request: request, response: response, date: date, began: began,
                body: body, observed: success || body.observedBytes != 0, error: error, metrics: metrics)
        }
    }
}
