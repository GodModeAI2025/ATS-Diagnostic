import Foundation
import Testing
import CryptoKit
@testable import ATSRecording

private final class ProtocolOrigin: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "protocol-origin.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    private let stopLock = NSLock()
    private var stopped = false
    override func startLoading() {
        if request.url?.path == "/failure" {
            client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost)); return
        }
        let bytes = request.url?.path == "/echo" ? (request.httpBody ?? task?.originalRequest?.httpBody ?? Data()) : Data((0..<150_017).map { UInt8($0 % 251) })
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: ["X-Origin": "unchanged"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        for offset in stride(from: 0, to: bytes.count, by: 4096) {
            client?.urlProtocol(self, didLoad: bytes.subdata(in: offset..<min(offset + 4096, bytes.count)))
        }
        if request.url?.path == "/partial" {
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { [self] in
                if !stopLock.withLock({ stopped }) { client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost)) }
            }
        }
        else if request.url?.path != "/slow" { client?.urlProtocolDidFinishLoading(self) }
    }
    override func stopLoading() { stopLock.withLock { stopped = true } }
}
private let protocolRecorder = try! RecordingClient(previewLimit: 3)
private final class HostRecordingProtocol: RecordingURLProtocol, @unchecked Sendable {
    static let context: RecordingProtocolContext = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ProtocolOrigin.self]
        return try! RecordingProtocolContext(recorder: protocolRecorder, configuration: configuration, previewLimit: 3)
    }()
    override class var recordingContext: RecordingProtocolContext? { context }
}

private let isolatedRecorder = try! RecordingClient(previewLimit: 0)
private final class IsolatedRecordingProtocol: RecordingURLProtocol, @unchecked Sendable {
    static let context: RecordingProtocolContext = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ProtocolOrigin.self]
        return try! RecordingProtocolContext(recorder: isolatedRecorder, configuration: configuration, previewLimit: 0)
    }()
    override class var recordingContext: RecordingProtocolContext? { context }
}

@Suite(.serialized)
struct RecordingURLProtocolTests {
    @Test func automaticAsyncDataPreservesEveryByteAndBoundsJournal() async throws {
        await protocolRecorder.clear()
        let session = try HostRecordingProtocol.context.makeSession(protocolClass: HostRecordingProtocol.self)
        defer { session.invalidateAndCancel() }
        let (data, response) = try await session.data(from: URL(string: "https://protocol-origin.invalid/large")!)
        #expect(data == Data((0..<150_017).map { UInt8($0 % 251) }))
        #expect((response as? HTTPURLResponse)?.value(forHTTPHeaderField: "X-Origin") == "unchanged")
        let record = try #require(await waitForRecord())
        #expect(record.responseBytes == data.count)
        #expect(record.responseBodyPreview == data.prefix(3))
        #expect(record.responseSHA256 == SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
        #expect(record.responseComplete == true)
        #expect(await protocolRecorder.records().count == 1)
    }
    @Test func automaticCompletionHandlerPreservesOriginalFailure() async throws {
        await protocolRecorder.clear()
        let session = try HostRecordingProtocol.context.makeSession(protocolClass: HostRecordingProtocol.self)
        defer { session.invalidateAndCancel() }
        let error: NSError? = await withCheckedContinuation { continuation in
            session.dataTask(with: URL(string: "https://protocol-origin.invalid/failure")!) { _, _, error in
                continuation.resume(returning: error as NSError?)
            }.resume()
        }
        #expect(error?.domain == NSURLErrorDomain)
        #expect(error?.code == URLError.networkConnectionLost.rawValue)
        let record = try #require(await waitForRecord())
        #expect(record.errorDomain == error?.domain); #expect(record.errorCode == error?.code)
        #expect(record.responseSHA256 == nil); #expect(record.responseComplete == false)
    }
    @Test func automaticPostPreservesRequestBodyAndHeaders() async throws {
        await protocolRecorder.clear()
        let session = try HostRecordingProtocol.context.makeSession(protocolClass: HostRecordingProtocol.self)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: URL(string: "https://protocol-origin.invalid/echo")!)
        request.httpMethod = "POST"; request.httpBody = Data("original body".utf8)
        request.setValue("original", forHTTPHeaderField: "X-Custom")
        let (data, _) = try await session.data(for: request)
        #expect(data == request.httpBody)
        let record = try #require(await waitForRecord())
        #expect(record.requestBodyBytes == request.httpBody?.count)
        #expect(record.requestBodyPreview == Data("ori".utf8))
        #expect(record.requestHeaders["X-Custom"] == "original")
    }
    @Test func partialTransportFailureKeepsObservedBytesWithoutCompleteHash() async throws {
        await protocolRecorder.clear()
        let session = try HostRecordingProtocol.context.makeSession(protocolClass: HostRecordingProtocol.self)
        defer { session.invalidateAndCancel() }
        do {
            _ = try await session.data(from: URL(string: "https://protocol-origin.invalid/partial")!)
            Issue.record("Expected original network failure")
        } catch { #expect((error as NSError).code == URLError.networkConnectionLost.rawValue) }
        let record = try #require(await waitForRecord())
        #expect(record.responseBytes == 150_017); #expect(record.responseBodyPreview.count == 3)
        #expect(record.responseComplete == false); #expect(record.responseSHA256 == nil)
    }
    @Test func streamCancellationKeepsPartialEvidenceAndFinishesOnce() async throws {
        await protocolRecorder.clear()
        let session = try HostRecordingProtocol.context.makeSession(protocolClass: HostRecordingProtocol.self)
        defer { session.invalidateAndCancel() }
        let (bytes, _) = try await session.bytes(from: URL(string: "https://protocol-origin.invalid/slow")!)
        var iterator = bytes.makeAsyncIterator()
        #expect(try await iterator.next() != nil)
        bytes.task.cancel()
        let record = try #require(await waitForRecord())
        #expect(record.errorCode == URLError.cancelled.rawValue)
        #expect(record.responseComplete == false); #expect(record.responseSHA256 == nil)
        #expect((record.responseBytes ?? 0) > 0); #expect(record.responseBodyPreview.count == 3)
        #expect(await protocolRecorder.records().count == 1)
    }
    @Test func distinctProtocolContextsKeepJournalsSeparate() async throws {
        await protocolRecorder.clear(); await isolatedRecorder.clear()
        let session = try IsolatedRecordingProtocol.context.makeSession(protocolClass: IsolatedRecordingProtocol.self)
        defer { session.invalidateAndCancel() }
        let (body, _) = try await session.data(from: URL(string: "https://protocol-origin.invalid/isolated")!)
        var captured: RecordedExchange?
        for _ in 0..<100 {
            captured = await isolatedRecorder.records().first
            if captured != nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let record = try #require(captured)
        #expect(record.responseBytes == body.count); #expect(record.responseBodyPreview.isEmpty)
        #expect(await protocolRecorder.records().isEmpty)
    }
    @Test func configurationRequiresMatchingContextAndKeepsOriginalUntouched() throws {
        let original = URLSessionConfiguration.ephemeral
        original.protocolClasses = [ProtocolOrigin.self]
        let other = try RecordingProtocolContext(recorder: protocolRecorder, configuration: original)
        #expect(throws: RecordingProtocolContext.ConfigurationError.self) {
            _ = try other.makeSession(protocolClass: HostRecordingProtocol.self)
        }
        #expect(original.protocolClasses?.count == 1)
        #expect(HostRecordingProtocol.canInit(with: URLRequest(url: URL(string: "file:///tmp/test")!)) == false)
    }
    private func waitForRecord() async throws -> RecordedExchange? {
        for _ in 0..<100 {
            if let record = await protocolRecorder.records().first { return record }
            try await Task.sleep(for: .milliseconds(10))
        }
        return nil
    }
}
