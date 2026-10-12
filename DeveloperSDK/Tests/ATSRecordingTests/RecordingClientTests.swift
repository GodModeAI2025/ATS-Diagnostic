import Foundation
import Testing
import CryptoKit
@testable import ATSRecording

private final class FixtureProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "fixture.invalid" }
    override class func canInit(with task: URLSessionTask) -> Bool { task.originalRequest.map { canInit(with: $0) } ?? false }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        if request.url?.path == "/failure" { client?.urlProtocol(self,didFailWithError:URLError(.cannotConnectToHost));return }
        let data = request.url?.path == "/echo" ? ((request.httpBodyStream ?? task?.originalRequest?.httpBodyStream) != nil ? readBodyStream() : (request.httpBody ?? task?.originalRequest?.httpBody ?? Data())) : Data((0..<(request.url?.path == "/large" ? 150_017 : 4096)).map { UInt8($0 % 251) })
        let response = HTTPURLResponse(url:request.url!,statusCode:200,httpVersion:"HTTP/1.1",headerFields:["Content-Type":"application/octet-stream"])!
        client?.urlProtocol(self,didReceive:response,cacheStoragePolicy:.notAllowed)
        client?.urlProtocol(self,didLoad:data)
        if request.url?.path == "/partial" {
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { [self] in
                if !stopLock.withLock({ stopped }) { client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost)) }
            }
        } else { client?.urlProtocolDidFinishLoading(self) }
    }
    private func readBodyStream() -> Data {
        guard let stream = request.httpBodyStream ?? task?.originalRequest?.httpBodyStream else { return Data() }
        stream.open(); defer { stream.close() }
        var data = Data(); var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable { let count = stream.read(&buffer, maxLength: buffer.count); if count <= 0 { break }; data.append(contentsOf: buffer.prefix(count)) }
        return data
    }
    private let stopLock = NSLock()
    private var stopped = false
    override func stopLoading() { stopLock.withLock { stopped = true } }
}
private func session() -> URLSession { let config = URLSessionConfiguration.ephemeral;config.protocolClasses = [FixtureProtocol.self];return URLSession(configuration:config) }
struct RecordingClientTests {
    @Test func fullResponseSurvivesZeroPreview() async throws {
        let recorder = try RecordingClient(previewLimit:0)
        let session = session();defer { session.invalidateAndCancel() }
        let (data,response) = try await recorder.data(for:URLRequest(url:URL(string:"https://fixture.invalid/body")!),using:session)
        #expect(data.count == 4096);#expect((response as? HTTPURLResponse)?.statusCode == 200)
        let record = try #require(await recorder.records().first)
        #expect(record.responseBodyPreview.isEmpty);#expect(record.responseBytes == 4096);#expect(record.responsePreviewTruncated)
        #expect(record.responseSHA256 == SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined())
    }
    @Test func originalFailureIsPreservedAndRecorded() async throws {
        let recorder = try RecordingClient();let session = session();defer { session.invalidateAndCancel() }
        do { _ = try await recorder.data(for:URLRequest(url:URL(string:"https://fixture.invalid/failure")!),using:session);Issue.record("Expected failure") }
        catch { #expect((error as NSError).code == URLError.cannotConnectToHost.rawValue) }
        let record = try #require(await recorder.records().first)
        #expect(record.errorCode == URLError.cannotConnectToHost.rawValue);#expect(record.status == nil);#expect(record.responseSHA256 == nil);#expect(record.responseBytes == nil)
    }
    @Test func countAndEncodedBudgetAreRespected() async throws {
        let recorder = try RecordingClient(countLimit:2,previewLimit:8,byteLimit:8192)
        let session = session();defer { session.invalidateAndCancel() }
        for index in 0..<3 { _ = try await recorder.data(for:URLRequest(url:URL(string:"https://fixture.invalid/\(index)")!),using:session) }
        let records = await recorder.records();#expect(records.count == 2);#expect(records.first?.url.hasSuffix("/2") == true)
        let exported = await recorder.jsonData();#expect(exported.count <= 8192)
        #expect(try JSONDecoder().decode([RecordedExchange].self,from:exported).count == 2)
        await recorder.clear();#expect(await recorder.jsonData() == Data("[]".utf8))
    }
    @Test func originalPostBodyAndHeadersReachTheSession() async throws {
        let recorder = try RecordingClient(previewLimit: 3)
        let session = session(); defer { session.invalidateAndCancel() }
        var request = URLRequest(url: URL(string: "https://fixture.invalid/echo")!)
        request.httpMethod = "POST"; request.httpBody = Data("complete body".utf8)
        request.setValue("original", forHTTPHeaderField: "X-Fixture")
        let (data, _) = try await recorder.data(for: request, using: session)
        #expect(data == request.httpBody)
        let record = try #require(await recorder.records().first)
        #expect(record.method == "POST"); #expect(record.requestHeaders["X-Fixture"] == "original")
        #expect(record.requestBodyPreview == Data("com".utf8)); #expect(record.requestPreviewTruncated)
    }
    @Test func uploadRecordsExplicitBodyAndPreservesResponse() async throws {
        let recorder = try RecordingClient(previewLimit: 3)
        let session = session(); defer { session.invalidateAndCancel() }
        var request = URLRequest(url: URL(string: "https://fixture.invalid/echo")!)
        request.httpMethod = "POST"; request.httpBody = Data("ignored".utf8)
        let body = Data("uploaded body".utf8)
        let (data, response) = try await recorder.upload(for: request, from: body, using: session)
        #expect(data == body); #expect((response as? HTTPURLResponse)?.statusCode == 200)
        let record = try #require(await recorder.records().first)
        #expect(record.requestBodyBytes == body.count)
        #expect(record.requestBodyPreview == Data("upl".utf8))
        #expect(record.responseBytes == body.count)
        #expect(record.responseSHA256 == SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined())
    }
    @Test func uploadFailurePreservesTransportError() async throws {
        let recorder = try RecordingClient()
        let session = session(); defer { session.invalidateAndCancel() }
        var request = URLRequest(url: URL(string: "https://fixture.invalid/failure")!)
        request.httpMethod = "POST"
        do {
            _ = try await recorder.upload(for: request, from: Data("body".utf8), using: session)
            Issue.record("Expected upload failure")
        } catch { #expect((error as NSError).code == URLError.cannotConnectToHost.rawValue) }
        let record = try #require(await recorder.records().first)
        #expect(record.requestBodyBytes == 4); #expect(record.responseBytes == nil)
        #expect(record.responseSHA256 == nil)
        #expect(record.errorCode == URLError.cannotConnectToHost.rawValue)
    }

    @Test func downloadPreservesFileAndHashesBeyondPreview() async throws {
        let recorder = try RecordingClient(previewLimit: 3)
        let session = session(); defer { session.invalidateAndCancel() }
        let (url, response) = try await recorder.download(for: URLRequest(url: URL(string: "https://fixture.invalid/large")!), using: session)
        defer { try? FileManager.default.removeItem(at: url) }
        let body = try Data(contentsOf: url)
        #expect(body.count == 150_017); #expect((response as? HTTPURLResponse)?.statusCode == 200)
        let record = try #require(await recorder.records().first)
        #expect(record.responseBodyPreview == body.prefix(3))
        #expect(record.responseBytes == 150_017); #expect(record.responsePreviewTruncated)
        #expect(record.responseSHA256 == SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined())
    }

    @Test func downloadWithZeroPreviewKeepsFullFileAndDigest() async throws {
        let recorder = try RecordingClient(previewLimit: 0)
        let session = session(); defer { session.invalidateAndCancel() }
        let (url, _) = try await recorder.download(for: URLRequest(url: URL(string: "https://fixture.invalid/body")!), using: session)
        defer { try? FileManager.default.removeItem(at: url) }
        let body = try Data(contentsOf: url)
        let record = try #require(await recorder.records().first)
        #expect(record.responseBodyPreview.isEmpty); #expect(record.responseBytes == body.count)
        #expect(record.responseSHA256 == SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined())
    }
    @Test func downloadFailurePreservesOriginalError() async throws {
        let recorder = try RecordingClient()
        let session = session(); defer { session.invalidateAndCancel() }
        do {
            _ = try await recorder.download(for: URLRequest(url: URL(string: "https://fixture.invalid/failure")!), using: session)
            Issue.record("Expected download failure")
        } catch { #expect((error as NSError).code == URLError.cannotConnectToHost.rawValue) }
        let record = try #require(await recorder.records().first)
        #expect(record.errorCode == URLError.cannotConnectToHost.rawValue)
        #expect(record.responseBytes == nil); #expect(record.responseSHA256 == nil)
    }

    @Test func fileUploadKeepsBodyFileBackedAndMarksJournalUnavailable() async throws {
        let recorder = try RecordingClient(previewLimit: 3)
        let session = session(); defer { session.invalidateAndCancel() }
        let body = Data((0..<150_017).map { UInt8($0 % 251) })
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try body.write(to: file); defer { try? FileManager.default.removeItem(at: file) }
        var request = URLRequest(url: URL(string: "https://fixture.invalid/echo")!)
        request.httpMethod = "POST"; request.httpBody = Data("ignored".utf8)
        let (responseBody, _) = try await recorder.upload(for: request, fromFile: file, using: session)
        #expect(responseBody == body); #expect(try Data(contentsOf: file) == body)
        let record = try #require(await recorder.records().first)
        #expect(record.requestBodyBytes == nil); #expect(record.requestBodyPreview.isEmpty)
        #expect(record.requestPreviewTruncated); #expect(record.responseBytes == body.count)
        #expect(record.responseSHA256 == SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined())
        let har = try await recorder.harData()
        let root = try #require(try JSONSerialization.jsonObject(with: har) as? [String: Any])
        let log = try #require(root["log"] as? [String: Any])
        let entry = try #require((log["entries"] as? [[String: Any]])?.first)
        let metadata = try #require(entry["_atsDiagnostic"] as? [String: Any])
        #expect(metadata["requestBodyUnavailable"] as? Bool == true)
    }

    @Test func streamingPreservesEveryByteAndFullMultiChunkHash() async throws {
        let recorder = try RecordingClient(previewLimit: 3)
        let session = session(); defer { session.invalidateAndCancel() }
        let (stream, response) = try await recorder.bytes(for: URLRequest(url: URL(string: "https://fixture.invalid/large")!), using: session)
        #expect(await recorder.records().isEmpty)
        var body = Data()
        for try await byte in stream { body.append(byte) }
        #expect(body == Data((0..<150_017).map { UInt8($0 % 251) }))
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        let record = try #require(await recorder.records().first)
        #expect(record.responseBytes == body.count); #expect(record.responseBodyPreview == body.prefix(3))
        #expect(record.responseSHA256 == SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined())
        var duplicate = stream.makeAsyncIterator()
        await #expect(throws: RecordingByteStream.ConsumptionError.self) { try await duplicate.next() }
        #expect(await recorder.records().count == 1)
    }
    @MainActor @Test func streamingZeroPreviewStillCountsAndHashesFullBody() async throws {
        let recorder = try RecordingClient(previewLimit: 0)
        let session = session(); defer { session.invalidateAndCancel() }
        let (stream, _) = try await recorder.bytes(for: URLRequest(url: URL(string: "https://fixture.invalid/body")!), using: session)
        var body = Data()
        for try await byte in stream { body.append(byte) }
        let record = try #require(await recorder.records().first)
        #expect(record.responseBodyPreview.isEmpty); #expect(record.responseBytes == 4096)
        #expect(record.responseSHA256 == SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined())
    }
    @Test func streamingFailureRecordsObservedPartialBytesWithoutCompleteHash() async throws {
        let recorder = try RecordingClient(previewLimit: 3)
        let session = session(); defer { session.invalidateAndCancel() }
        let (stream, _) = try await recorder.bytes(for: URLRequest(url: URL(string: "https://fixture.invalid/partial")!), using: session)
        var observed = 0
        do {
            for try await _ in stream { observed += 1 }
            Issue.record("Expected stream failure")
        } catch { #expect((error as NSError).code == URLError.networkConnectionLost.rawValue) }
        let record = try #require(await recorder.records().first)
        #expect(observed > 0); #expect(record.responseBytes == observed)
        #expect(record.responseBodyPreview.count == min(observed, 3))
        #expect(record.responseSHA256 == nil)
        #expect(record.errorCode == URLError.networkConnectionLost.rawValue)
    }
    @Test func streamingInitialFailureRetainsUnknownResponse() async throws {
        let recorder = try RecordingClient()
        let session = session(); defer { session.invalidateAndCancel() }
        do {
            _ = try await recorder.bytes(for: URLRequest(url: URL(string: "https://fixture.invalid/failure")!), using: session)
            Issue.record("Expected initial failure")
        } catch { #expect((error as NSError).code == URLError.cannotConnectToHost.rawValue) }
        let record = try #require(await recorder.records().first)
        #expect(record.responseBytes == nil); #expect(record.status == nil)
        #expect(record.responseSHA256 == nil)
    }

    @Test func tooSmallJournalCannotChangeSuccessfulResponse() async throws {
        let recorder = try RecordingClient(byteLimit: 2)
        let session = session(); defer { session.invalidateAndCancel() }
        let (data, _) = try await recorder.data(for: URLRequest(url: URL(string: "https://fixture.invalid/body")!), using: session)
        #expect(data.count == 4096); #expect(await recorder.records().isEmpty)
    }

    @Test func harMarksPartialRequestsAndUnknownProtocol() async throws {
        let recorder = try RecordingClient(previewLimit: 3)
        let session = session(); defer { session.invalidateAndCancel() }
        var request = URLRequest(url: URL(string: "https://fixture.invalid/echo")!)
        request.httpMethod = "POST"; request.httpBody = Data("complete body".utf8)
        _ = try await recorder.data(for: request, using: session)
        let data = try await recorder.harData()
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let log = try #require(root["log"] as? [String: Any])
        let entry = try #require((log["entries"] as? [[String: Any]])?.first)
        let recordedRequest = try #require(entry["request"] as? [String: Any])
        let metadata = try #require(entry["_atsDiagnostic"] as? [String: Any])
        #expect(recordedRequest["httpVersion"] as? String == "")
        #expect(recordedRequest["bodySize"] as? Int == 13); #expect(recordedRequest["postData"] == nil)
        #expect(metadata["requestBodyUnavailable"] as? Bool == true)
        #expect(metadata["requestBodyPreviewBase64"] as? String == Data("com".utf8).base64EncodedString())
        try writeHARFixture(data, name: "SDK-Post-Partial")
    }

    @Test func observationsReportRecordingAndClearThenFinish() async throws {
        let recorder = try RecordingClient()
        let observation = try await recorder.observe()
        var iterator = observation.events.makeAsyncIterator()
        let initial = try #require(await iterator.next()); #expect(initial.revision == 0)
        let session = session(); defer { session.invalidateAndCancel() }
        _ = try await recorder.data(for: URLRequest(url: URL(string: "https://fixture.invalid/events")!), using: session)
        let event = try #require(await iterator.next())
        let record = try #require(await recorder.records().first)
        if case .recorded(let id) = event.kind { #expect(id == record.id) } else { Issue.record("Expected recorded event") }
        #expect(event.revision == 1)
        await recorder.clear()
        let clear = try #require(await iterator.next())
        if case .cleared = clear.kind {} else { Issue.record("Expected cleared event") }
        #expect(clear.revision == 2)
        await observation.cancel(); #expect(await iterator.next() == nil)
    }
    @Test func slowObserverCanDetectGapsAndReloadCurrentJournal() async throws {
        let recorder = try RecordingClient()
        let observation = try await recorder.observe()
        var iterator = observation.events.makeAsyncIterator(); _ = await iterator.next()
        for _ in 0..<65 { await recorder.clear() }
        let session = session(); defer { session.invalidateAndCancel() }
        _ = try await recorder.data(for: URLRequest(url: URL(string: "https://fixture.invalid/current")!), using: session)
        let event = try #require(await iterator.next()); #expect(event.revision > 1)
        #expect(await recorder.records().first?.url.hasSuffix("/current") == true)
        await observation.cancel()
    }
    @Test func observerLimitCanBeReleasedExplicitly() async throws {
        let recorder = try RecordingClient()
        var observations: [RecordingObservation] = []
        for _ in 0..<16 { observations.append(try await recorder.observe()) }
        await #expect(throws: RecordingClient.ObservationError.self) { try await recorder.observe() }
        await observations.removeLast().cancel()
        let replacement = try await recorder.observe(); await replacement.cancel()
        for observation in observations { await observation.cancel() }
    }

    @Test func observationDoesNotRetainItsProducer() async throws {
        let (observation, weakOwner) = try await detachedObservation()
        await Task.yield()
        #expect(weakOwner.value == nil)
        var iterator = observation.events.makeAsyncIterator()
        _ = await iterator.next()
        #expect(await iterator.next() == nil)
    }

}

func writeHARFixture(_ data: Data, name: String) throws {
    guard let path = ProcessInfo.processInfo.environment["ATS_RECORDING_FIXTURES"] else { return }
    let directory = URL(fileURLWithPath: path, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try data.write(to: directory.appendingPathComponent(name + ".json"), options: .atomic)
}

private final class WeakRecordingOwner: @unchecked Sendable {
    weak var value: RecordingClient?
    init(_ value: RecordingClient) { self.value = value }
}
private func detachedObservation() async throws -> (RecordingObservation, WeakRecordingOwner) {
    let client = try RecordingClient()
    return (try await client.observe(), WeakRecordingOwner(client))
}
