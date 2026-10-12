import Foundation
import CryptoKit

/// Single-pass observation of the bytes consumed from the host's URLSession.
/// A journal record is finalized at EOF or an iterator transport error.
public struct RecordingByteStream: AsyncSequence, Sendable {
    public typealias Element = UInt8
    public enum ConsumptionError: Error { case alreadyConsumed }
    private let bytes: URLSession.AsyncBytes
    private let claim = StreamClaim()
    private let owner: RecordingClient
    private let request: URLRequest
    private let response: URLResponse
    private let date: Date
    private let began: ContinuousClock.Instant
    private let previewLimit: Int
    public var task: URLSessionDataTask { bytes.task }

    init(bytes: URLSession.AsyncBytes, owner: RecordingClient, request: URLRequest, response: URLResponse, date: Date, began: ContinuousClock.Instant, previewLimit: Int) {
        self.bytes = bytes; self.owner = owner; self.request = request
        self.response = response; self.date = date; self.began = began
        self.previewLimit = previewLimit
    }
    public func makeAsyncIterator() -> Iterator {
        Iterator(raw: bytes.makeAsyncIterator(), allowed: claim.take(), owner: owner, request: request, response: response, date: date, began: began, previewLimit: previewLimit)
    }
    public struct Iterator: AsyncIteratorProtocol {
        private var raw: URLSession.AsyncBytes.Iterator
        private let allowed: Bool
        private let owner: RecordingClient
        private let request: URLRequest
        private let response: URLResponse
        private let date: Date
        private let began: ContinuousClock.Instant
        private let previewLimit: Int
        private var preview = Data()
        private var hashChunk = Data()
        private var hasher = SHA256()
        private var count = 0
        private var ended = false
        fileprivate init(raw: URLSession.AsyncBytes.Iterator, allowed: Bool, owner: RecordingClient, request: URLRequest, response: URLResponse, date: Date, began: ContinuousClock.Instant, previewLimit: Int) {
            self.raw = raw; self.allowed = allowed; self.owner = owner
            self.request = request; self.response = response; self.date = date
            self.began = began; self.previewLimit = previewLimit
        }
        public mutating func next() async throws -> UInt8? {
            guard allowed else { throw ConsumptionError.alreadyConsumed }
            guard !ended else { return nil }
            do {
                if let byte = try await raw.next() {
                    count += 1
                    if preview.count < previewLimit { preview.append(byte) }
                    hashChunk.append(byte)
                    if hashChunk.count == 64 * 1024 {
                        hasher.update(data: hashChunk); hashChunk.removeAll(keepingCapacity: true)
                    }
                    return byte
                }
                ended = true
                hasher.update(data: hashChunk); hashChunk.removeAll()
                let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
                await owner.recordStream(request: request, response: response, date: date, began: began, preview: preview, count: count, hash: digest, error: nil)
                return nil
            } catch {
                ended = true
                await owner.recordStream(request: request, response: response, date: date, began: began, preview: preview, count: count, hash: nil, error: error as NSError)
                throw error
            }
        }
    }
}
private final class StreamClaim: @unchecked Sendable {
    private let lock = NSLock()
    private var consumed = false
    func take() -> Bool { lock.withLock { guard !consumed else { return false }; consumed = true; return true } }
}
