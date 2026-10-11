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
        let data = request.url?.path == "/echo" ? (request.httpBody ?? task?.originalRequest?.httpBody ?? readBodyStream()) : Data((0..<4096).map { UInt8($0 % 251) })
        let response = HTTPURLResponse(url:request.url!,statusCode:200,httpVersion:"HTTP/1.1",headerFields:["Content-Type":"application/octet-stream"])!
        client?.urlProtocol(self,didReceive:response,cacheStoragePolicy:.notAllowed)
        client?.urlProtocol(self,didLoad:data);client?.urlProtocolDidFinishLoading(self)
    }
    private func readBodyStream() -> Data {
        guard let stream = request.httpBodyStream ?? task?.originalRequest?.httpBodyStream else { return Data() }
        stream.open(); defer { stream.close() }
        var data = Data(); var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable { let count = stream.read(&buffer, maxLength: buffer.count); if count <= 0 { break }; data.append(contentsOf: buffer.prefix(count)) }
        return data
    }
    override func stopLoading() {}
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
    @Test func tooSmallJournalCannotChangeSuccessfulResponse() async throws {
        let recorder = try RecordingClient(byteLimit: 2)
        let session = session(); defer { session.invalidateAndCancel() }
        let (data, _) = try await recorder.data(for: URLRequest(url: URL(string: "https://fixture.invalid/body")!), using: session)
        #expect(data.count == 4096); #expect(await recorder.records().isEmpty)
    }

}
