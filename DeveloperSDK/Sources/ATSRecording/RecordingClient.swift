import Foundation
import CryptoKit

public struct RecordedExchange: Codable, Sendable, Identifiable {
    public let id: UUID
    public let date: Date
    public let url: String
    public let method: String
    public let requestHeaders: [String: String]
    public let requestBodyPreview: Data
    public let requestBodyBytes: Int?
    public let status: Int?
    public let responseHeaders: [String: String]
    public let responseBodyPreview: Data
    public let responseBytes: Int?
    public let responseSHA256: String?
    public let duration: Double
    public let errorDomain: String?
    public let errorCode: Int?
    public let errorDescription: String?
    public var requestPreviewTruncated: Bool { requestBodyBytes.map { $0 > requestBodyPreview.count } ?? true }
    public var responsePreviewTruncated: Bool { responseBytes.map { $0 > responseBodyPreview.count } ?? true }
}

public struct RecordingEvent: Sendable {
    public enum Kind: Sendable { case initial, recorded(UUID), recordingOmitted(UUID), cleared }
    public let revision: UInt64
    public let kind: Kind
}
public struct RecordingObservation: Sendable {
    fileprivate let id: UUID
    public let events: AsyncStream<RecordingEvent>
    fileprivate weak var owner: RecordingClient?
    public func cancel() async { await owner?.stopObserving(id) }
}

/// Opt-in recording around an existing URLSession. The caller receives the complete,
/// unchanged response; only the journal preview is bounded. No trust handler is installed.
public actor RecordingClient {
    public enum ConfigurationError: Error { case invalidLimits }
    public enum ObservationError: Error { case tooManyObservers }
    private let countLimit: Int
    private let previewLimit: Int
    private let byteLimit: Int
    private var journal: [(record: RecordedExchange, encoded: Data)] = []
    private var encodedBytes = 2
    private var revision: UInt64 = 0
    private var observers: [UUID: AsyncStream<RecordingEvent>.Continuation] = [:]

    public init(countLimit: Int = 200, previewLimit: Int = 64 * 1024, byteLimit: Int = 64 * 1024 * 1024) throws {
        guard (1...1000).contains(countLimit), (0...16 * 1024 * 1024).contains(previewLimit), (2...512 * 1024 * 1024).contains(byteLimit) else { throw ConfigurationError.invalidLimits }
        self.countLimit = countLimit; self.previewLimit = previewLimit; self.byteLimit = byteLimit
    }

    public func data(for request: URLRequest, using session: URLSession) async throws -> (Data, URLResponse) {
        let began = ContinuousClock.now
        let date = Date()
        do {
            // Use the supplied session directly: cookies, redirects, caching, proxy,
            // ATS and the caller's authentication delegate retain their normal behavior.
            let (data, response) = try await session.data(for: request)
            let http = response as? HTTPURLResponse
            let record = makeRecord(request: request, date: date, began: began, data: data, response: http, error: nil)
            try? append(record)
            return (data, response)
        } catch {
            // Journal storage must not replace the original transport error.
            let record = makeRecord(request: request, date: date, began: began, data: nil, response: nil, error: error as NSError)
            try? append(record)
            throw error
        }
    }

    /// Uses the supplied session directly; the explicit upload body is authoritative.
    public func upload(for request: URLRequest, from body: Data, using session: URLSession) async throws -> (Data, URLResponse) {
        let began = ContinuousClock.now
        let date = Date()
        var recordedRequest = request
        recordedRequest.httpBodyStream = nil
        recordedRequest.httpBody = body
        do {
            let (data, response) = try await session.upload(for: request, from: body)
            try? append(makeRecord(request: recordedRequest, date: date, began: began, data: data, response: response as? HTTPURLResponse, error: nil))
            return (data, response)
        } catch {
            try? append(makeRecord(request: recordedRequest, date: date, began: began, data: nil, response: nil, error: error as NSError))
            throw error
        }
    }

    public func records() -> [RecordedExchange] { journal.map(\.record) }
    public func clear() { journal.removeAll(); encodedBytes = 2; publish(.cleared) }
    /// Buffered metadata-only events; revision gaps require a records() reload.
    public func observe() throws -> RecordingObservation {
        guard observers.count < 16 else { throw ObservationError.tooManyObservers }
        let id = UUID()
        let pair = AsyncStream<RecordingEvent>.makeStream(bufferingPolicy: .bufferingNewest(32))
        observers[id] = pair.continuation
        pair.continuation.onTermination = { [weak self] _ in Task { await self?.stopObserving(id) } }
        pair.continuation.yield(RecordingEvent(revision: revision, kind: .initial))
        return RecordingObservation(id: id, events: pair.stream, owner: self)
    }
    fileprivate func stopObserving(_ id: UUID) { observers.removeValue(forKey: id)?.finish() }
    private func publish(_ kind: RecordingEvent.Kind) {
        revision += 1
        let event = RecordingEvent(revision: revision, kind: kind)
        var terminated: [UUID] = []
        for (id, continuation) in observers { if case .terminated = continuation.yield(event) { terminated.append(id) } }
        for id in terminated { observers.removeValue(forKey: id) }
    }
    deinit { for continuation in observers.values { continuation.finish() } }
    public func jsonData() -> Data {
        var result = Data([0x5b])
        for (index, item) in journal.enumerated() { if index > 0 { result.append(0x2c) }; result.append(item.encoded) }
        result.append(0x5d); return result
    }

    private func append(_ record: RecordedExchange) throws {
        let encoded = try JSONEncoder().encode(record)
        guard encoded.count + 2 <= byteLimit else { publish(.recordingOmitted(record.id)); return }
        journal.insert((record, encoded), at: 0)
        encodedBytes += encoded.count + (journal.count > 1 ? 1 : 0)
        while journal.count > countLimit || encodedBytes > byteLimit {
            let removed = journal.removeLast()
            encodedBytes -= removed.encoded.count + (journal.isEmpty ? 0 : 1)
        }
        publish(.recorded(record.id))
    }
    private func preview(_ data: Data?) -> Data {
        guard let data, !data.isEmpty, previewLimit > 0 else { return Data() }
        return data.withUnsafeBytes { buffer in Data(bytes: buffer.baseAddress!, count: min(buffer.count, previewLimit)) }
    }
    private func makeRecord(request: URLRequest, date: Date, began: ContinuousClock.Instant, data: Data?, response: HTTPURLResponse?, error: NSError?) -> RecordedExchange {
        let time = began.duration(to: .now).components
        let headers = response?.allHeaderFields.reduce(into: [String: String]()) { result, item in result[String(describing: item.key)] = String(describing: item.value) } ?? [:]
        let body = request.httpBody
        return RecordedExchange(id: UUID(), date: date, url: request.url?.absoluteString ?? "", method: request.httpMethod ?? "GET", requestHeaders: request.allHTTPHeaderFields ?? [:], requestBodyPreview: preview(body), requestBodyBytes: body?.count ?? (request.httpBodyStream == nil ? 0 : nil), status: response?.statusCode, responseHeaders: headers, responseBodyPreview: preview(data), responseBytes: data?.count, responseSHA256: data.map { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() }, duration: Double(time.seconds) + Double(time.attoseconds) / 1e18, errorDomain: error?.domain, errorCode: error?.code, errorDescription: error?.localizedDescription)
    }
}
