import Foundation

/// Opt-in observer for delegate-delivered data tasks in a host-created URLSession.
/// Completion-handler/async bodies are not delivered here; use RecordingClient for those.
public final class RecordingSessionDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private struct Context {
        let request: URLRequest
        let date = Date()
        let began = ContinuousClock.now
        var body: RecordingResponseAccumulator
        var sawData = false
        var metrics: RecordedTaskMetrics?
    }
    private let recorder: RecordingClient
    private let target: (any URLSessionDelegate)?
    private let previewLimit: Int
    private let lock = NSLock()
    private var omitted = 0
    public var omittedTaskCount: Int { lock.withLock { omitted } }
    private var contexts: [ObjectIdentifier: Context] = [:]
    public init(recorder: RecordingClient, forwardingTo target: (any URLSessionDelegate)? = nil, previewLimit: Int = 64 * 1024) {
        self.recorder = recorder; self.target = target
        self.previewLimit = max(0, min(previewLimit, 16 * 1024 * 1024))
        super.init()
    }
    public override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || target?.responds(to: selector) == true
    }
    public override func forwardingTarget(for selector: Selector!) -> Any? {
        if target?.responds(to: selector) == true { return target }
        return super.forwardingTarget(for: selector)
    }
    public func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        if task is URLSessionDataTask, !(task is URLSessionUploadTask), let request = task.originalRequest {
            lock.withLock {
                // Body retention across active tasks is capped separately from the journal.
                if contexts.count < 64 {
                    contexts[ObjectIdentifier(task)] = Context(request: request, body: RecordingResponseAccumulator(previewLimit: min(previewLimit, 64 * 1024)))
                } else if omitted < Int.max { omitted += 1 }
            }
        }
        (target as? any URLSessionTaskDelegate)?.urlSession?(session, didCreateTask: task)
    }
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.withLock {
            if var context = contexts[ObjectIdentifier(dataTask)] {
                context.body.receive(data); context.sawData = true
                contexts[ObjectIdentifier(dataTask)] = context
            }
        }
        (target as? any URLSessionDataDelegate)?.urlSession?(session, dataTask: dataTask, didReceive: data)
    }
    public func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        let captured = RecordedTaskMetrics(metrics)
        lock.withLock { contexts[ObjectIdentifier(task)]?.metrics = captured }
        (target as? any URLSessionTaskDelegate)?.urlSession?(session, task: task, didFinishCollecting: metrics)
    }
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        let context = lock.withLock { contexts.removeValue(forKey: ObjectIdentifier(task)) }
        (target as? any URLSessionTaskDelegate)?.urlSession?(session, task: task, didCompleteWithError: error)
        guard let context else { return }
        let response = task.response as? HTTPURLResponse
        let bodyless = context.request.httpMethod == "HEAD" || response?.statusCode == 204 || response?.statusCode == 304
        let observed = context.sawData || (bodyless && error == nil)
        let body = context.body.snapshot(transportSucceeded: error == nil && observed)
        let failure = error as NSError?
        Task {
            await recorder.recordDelegateTask(request: context.request, response: response, date: context.date,
                began: context.began, body: body, observed: observed, error: failure, metrics: context.metrics)
        }
    }
}
