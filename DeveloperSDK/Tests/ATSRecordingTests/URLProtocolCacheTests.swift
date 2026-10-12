import Foundation
import Testing
@testable import ATSRecording

private final class CachedRecordingProtocol: RecordingURLProtocol, @unchecked Sendable {
    static let recorder = try! RecordingClient()
    static let url = URL(string: "https://cache-origin.invalid/seed")!
    static let bytes = Data("cached response".utf8)
    static let cache = URLCache(memoryCapacity: 1024 * 1024, diskCapacity: 0)
    static var configuration: URLSessionConfiguration {
        let value = URLSessionConfiguration.ephemeral
        value.urlCache = cache
        value.requestCachePolicy = .returnCacheDataDontLoad
        return value
    }
    static let context = try! RecordingProtocolContext(recorder: recorder, configuration: configuration)
    override class var recordingContext: RecordingProtocolContext? { context }
}
@Suite(.serialized)
struct URLProtocolCacheTests {
    @Test(arguments: [URLRequest.CachePolicy.returnCacheDataDontLoad, .useProtocolCachePolicy])
    func cacheHitsKeepResponseAndProduceIndividualJournalEntries(_ policy: URLRequest.CachePolicy) async throws {
        let request = URLRequest(url: CachedRecordingProtocol.url, cachePolicy: policy)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/plain", "Cache-Control": "max-age=600", "Date": httpDate()])!
        let cache = CachedRecordingProtocol.cache
        cache.storeCachedResponse(CachedURLResponse(response: response, data: CachedRecordingProtocol.bytes), for: request)
        defer { cache.removeAllCachedResponses() }
        let baseline = URLSession(configuration: CachedRecordingProtocol.configuration)
        defer { baseline.invalidateAndCancel() }
        let (plainBody, _) = try await baseline.data(for: request)
        #expect(plainBody == CachedRecordingProtocol.bytes)
        await CachedRecordingProtocol.recorder.clear()
        let recorded = try CachedRecordingProtocol.context.makeSession(protocolClass: CachedRecordingProtocol.self)
        defer { recorded.invalidateAndCancel() }
        for _ in 0..<2 {
            let (body, result) = try await recorded.data(for: request)
            #expect(body == plainBody); #expect((result as? HTTPURLResponse)?.statusCode == 200)
        }
        var entries: [RecordedExchange] = []
        for _ in 0..<100 {
            entries = await CachedRecordingProtocol.recorder.records()
            if entries.count == 2 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(entries.count == 2)
        for entry in entries {
            #expect(entry.responseBytes == plainBody.count)
            #expect(entry.responseBodyPreview == plainBody)
            #expect(entry.responseComplete == true); #expect(entry.errorCode == nil)
            #expect(entry.metrics?.transactions.contains { $0.fetchType == URLSessionTaskMetrics.ResourceFetchType.localCache.rawValue } == true)
        }
    }
    @Test func explicitCacheBypassKeepsTheActualNetworkFailure() async throws {
        let cachedRequest = URLRequest(url: CachedRecordingProtocol.url)
        let response = HTTPURLResponse(url: cachedRequest.url!, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: ["Cache-Control": "max-age=600", "Date": httpDate()])!
        let cache = CachedRecordingProtocol.cache
        cache.storeCachedResponse(CachedURLResponse(response: response, data: CachedRecordingProtocol.bytes), for: cachedRequest)
        defer { cache.removeAllCachedResponses() }
        let request = URLRequest(url: CachedRecordingProtocol.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 5)
        let baseline = URLSession(configuration: CachedRecordingProtocol.configuration)
        let recorded = try CachedRecordingProtocol.context.makeSession(protocolClass: CachedRecordingProtocol.self)
        defer { baseline.invalidateAndCancel(); recorded.invalidateAndCancel() }
        var baselineError: NSError?
        do { _ = try await baseline.data(for: request); Issue.record("Baseline ignored explicit cache bypass") }
        catch { baselineError = error as NSError }
        #expect(try #require(baselineError).domain == NSURLErrorDomain)
        await CachedRecordingProtocol.recorder.clear()
        var actualError: NSError?
        do { _ = try await recorded.data(for: request); Issue.record("Recorder ignored explicit cache bypass") }
        catch { actualError = error as NSError }
        let failure = try #require(actualError)
        #expect(failure.domain == baselineError?.domain); #expect(failure.code == baselineError?.code)
        var entry: RecordedExchange?
        for _ in 0..<100 {
            entry = await CachedRecordingProtocol.recorder.records().first
            if entry != nil { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let record = try #require(entry)
        #expect(record.errorDomain == failure.domain); #expect(record.errorCode == failure.code)
        #expect(record.status == nil); #expect(record.responseSHA256 == nil)
        #expect(record.responseComplete == false)
    }
    private func httpDate() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return formatter.string(from: Date())
    }

}
