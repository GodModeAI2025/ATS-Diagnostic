import Foundation
import CryptoKit

/// Single-pass observation of bytes consumed from the host's URLSession.
public struct RecordingByteStream: AsyncSequence, Sendable {
    public typealias Element = UInt8
    public enum ConsumptionError: Error { case alreadyConsumed }
    private let bytes: URLSession.AsyncBytes
    private let context: StreamContext
    public var task: URLSessionDataTask { bytes.task }
    init(bytes: URLSession.AsyncBytes, owner: RecordingClient, request: URLRequest, response: URLResponse, date: Date, began: ContinuousClock.Instant, previewLimit: Int, metricsObserver: RecordingMetricsDelegate? = nil) {
        self.bytes = bytes
        context = StreamContext(owner: owner, request: request, response: response, date: date, began: began, previewLimit: previewLimit, metricsObserver: metricsObserver)
    }
    public func makeAsyncIterator() -> Iterator {
        Iterator(raw: bytes.makeAsyncIterator(), allowed: context.claim(), context: context)
    }
    /// Ends observation without cancelling transport or claiming a complete response.
    public func finishRecording() async { await context.finish(complete: false, error: nil) }
    public struct Iterator: AsyncIteratorProtocol {
        private var raw: URLSession.AsyncBytes.Iterator
        private let allowed: Bool
        private let context: StreamContext
        private var ended = false
        fileprivate init(raw: URLSession.AsyncBytes.Iterator, allowed: Bool, context: StreamContext) {
            self.raw = raw; self.allowed = allowed; self.context = context
        }
        public mutating func next() async throws -> UInt8? {
            guard allowed else { throw ConsumptionError.alreadyConsumed }
            guard !ended else { return nil }
            do {
                if let byte = try await raw.next() { context.observe(byte); return byte }
                ended = true
                await context.finish(complete: true, error: nil)
                return nil
            } catch {
                ended = true
                await context.finish(complete: false, error: error as NSError)
                throw error
            }
        }
    }
}
/// All mutable accumulation and finalization state is protected by this lock.
private final class StreamContext: @unchecked Sendable {
    private let lock = NSLock()
    private let owner: RecordingClient
    private let request: URLRequest
    private let response: URLResponse
    private let date: Date
    private let began: ContinuousClock.Instant
    private let previewLimit: Int
    private let metricsObserver: RecordingMetricsDelegate?
    private var consumed = false
    private var preview = Data()
    private var hashChunk = Data()
    private var hasher = SHA256()
    private var count = 0
    private var finishing: Task<Void, Never>?
    init(owner: RecordingClient, request: URLRequest, response: URLResponse, date: Date, began: ContinuousClock.Instant, previewLimit: Int, metricsObserver: RecordingMetricsDelegate? = nil) {
        self.owner = owner; self.request = request; self.response = response
        self.date = date; self.began = began; self.previewLimit = previewLimit; self.metricsObserver = metricsObserver
    }
    func claim() -> Bool { lock.withLock { guard !consumed else { return false }; consumed = true; return true } }
    func observe(_ byte: UInt8) {
        lock.withLock {
            guard finishing == nil else { return }
            count += 1
            if preview.count < previewLimit { preview.append(byte) }
            hashChunk.append(byte)
            if hashChunk.count == 64 * 1024 { hasher.update(data: hashChunk); hashChunk.removeAll(keepingCapacity: true) }
        }
    }
    func finish(complete: Bool, error: NSError?) async {
        let work = lock.withLock {
            if let finishing { return finishing }
            hasher.update(data: hashChunk); hashChunk.removeAll()
            let digest = complete && error == nil ? hasher.finalize().map { String(format: "%02x", $0) }.joined() : nil
            let work = Task { [owner, request, response, date, began, preview, count, metricsObserver] in
                await owner.recordStream(request: request, response: response, date: date, began: began, preview: preview, count: count, hash: digest, error: error, metrics: metricsObserver?.snapshot())
            }
            finishing = work
            return work
        }
        await work.value
    }
}
