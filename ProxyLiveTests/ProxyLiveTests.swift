import Foundation
import Network
import Testing
@testable import ATSDiagnostic

private struct ProxyLiveProof: Codable {
    let client: DiagnosticRecord
    let tunnel: ProxyCapture
}
struct ProxyLiveTests {
    @Test(arguments:["https://example.com/","https://expired.badssl.com/","https://wrong.host.badssl.com/"])
    func absoluteHTTPSForwardingValidatesUpstream(_ endpoint:String) async throws {
        let events = AsyncStream<LocalProxyEvent>.makeStream()
        let proxy = LocalHTTPProxy(idleTimeout:10,maximumDuration:30,event:{ events.continuation.yield($0) });proxy.start();defer { proxy.stop();events.continuation.finish() }
        var port: UInt16?
        for await event in events.stream { if case .listening(let value) = event { port = value;break };if case .failed(let error) = event { throw NSError(domain:error,code:1) } }
        let response = try await ProxyAbsoluteClient(port:try #require(port)).get(endpoint)
        #expect(ProxyWire.responseStatus(response) == (endpoint.contains("example.com") ? 200 : 502))
        var capture: ProxyCapture?
        for await event in events.stream { if case .capture(let value) = event,!value.active { capture = value;break } }
        let value = try #require(capture)
        #expect(!value.opaque)
        if endpoint.contains("example.com") { #expect(value.upstreamTLS != nil);#expect(value.error == nil) }
        else { #expect(value.error != nil);#expect(value.receivedBytes == 0) }
        let folder = URL.documentsDirectory.appendingPathComponent("Proxy-Live",isDirectory:true);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let encoder = JSONEncoder();encoder.outputFormatting = [.prettyPrinted,.sortedKeys];encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(value).write(to:folder.appendingPathComponent("direct-" + URL(string:endpoint)!.host! + ".json"),options:[.atomic,.completeFileProtection])
        print("PROXY_DIRECT_PROOF \(folder.path) \(endpoint) status \(ProxyWire.responseStatus(response) ?? 0)")
    }
    @Test(arguments:["https://example.com","https://expired.badssl.com","https://wrong.host.badssl.com"])
    func nativeClientUsesProxyWithoutBypassingCertificateTrust(_ endpoint:String) async throws {
        let events = AsyncStream<LocalProxyEvent>.makeStream()
        let proxy = LocalHTTPProxy(idleTimeout:10,maximumDuration:30,event:{ events.continuation.yield($0) })
        proxy.start();defer { proxy.stop();events.continuation.finish() }
        var port: UInt16?
        for await event in events.stream {
            if case .listening(let bound) = event { port = bound;break }
            if case .failed(let error) = event { throw NSError(domain:error,code:1) }
        }
        let bound = try #require(port)
        let request = URLRequest(url:try #require(URL(string:endpoint)))
        let configuration = URLSessionConfiguration.ephemeral
        var proxyConfiguration = ProxyConfiguration(httpCONNECTProxy:.hostPort(host:"127.0.0.1",port:NWEndpoint.Port(rawValue:bound)!))
        proxyConfiguration.allowFailover = false
        configuration.proxyConfigurations = [proxyConfiguration]
        let client = await DiagnosticEngine(request:request).run(request,configuration:configuration)
        if endpoint.contains("example.com") { #expect(client.status == 200);#expect(client.error == nil);#expect(client.trustValid == true) }
        else { #expect(client.error != nil);#expect(client.trustValid == false);#expect(DiagnosticFailure.explain(client)?.cause == (endpoint.contains("expired") ? .expired : .hostname)) }
        proxy.stop(reason:"Prüfung abgeschlossen")
        var capture: ProxyCapture?
        for await event in events.stream {
            if case .capture(let value) = event, value.method == "CONNECT", !value.active { capture = value;break }
            if case .stopped = event { break }
        }
        let tunnel = try #require(capture)
        #expect(tunnel.target.contains(request.url!.host!))
        #expect(tunnel.sentBytes > 0 && tunnel.receivedBytes > 0)
        #expect(tunnel.requestPreview.isEmpty && tunnel.responsePreview.isEmpty)
        let folder = URL.documentsDirectory.appendingPathComponent("Proxy-Live",isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let encoder = JSONEncoder();encoder.dateEncodingStrategy = .iso8601;encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
        try encoder.encode(ProxyLiveProof(client:client,tunnel:tunnel)).write(to:folder.appendingPathComponent(request.url!.host!+".json"),options:[.atomic,.completeFileProtection])
        print("PROXY_LIVE_PROOF \(folder.path) \(endpoint) HTTP \(client.status ?? 0) trust \(client.trustValid ?? false) sent \(tunnel.sentBytes) received \(tunnel.receivedBytes)")
    }
}

private final class ProxyAbsoluteClient: @unchecked Sendable {
    private let queue = DispatchQueue(label:"ATS direct proxy live client")
    private let connection: NWConnection
    private var continuation: CheckedContinuation<Data,any Error>?
    private var bytes = Data()
    init(port: UInt16) { connection = NWConnection(host:"127.0.0.1",port:NWEndpoint.Port(rawValue:port)!,using:.tcp) }
    func get(_ target:String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                self.continuation = continuation
                connection.stateUpdateHandler = { [self] state in
                    switch state {
                    case .ready: connection.send(content:Data("GET \(target) HTTP/1.1\r\nHost: \(URL(string:target)!.host!)\r\nConnection: close\r\n\r\n".utf8),contentContext:.finalMessage,isComplete:true,completion:.contentProcessed { [self] error in if let error { finish(.failure(error)) } else { receive() } })
                    case .failed(let error): finish(.failure(error))
                    default: break
                    }
                }
                connection.start(queue:queue);queue.asyncAfter(deadline:.now()+35) { [self] in finish(.failure(URLError(.timedOut))) }
            }
        }
    }
    private func receive() {
        connection.receive(minimumIncompleteLength:1,maximumLength:65536) { [self] data,_,eof,error in
            if let data { bytes.append(data) }
            if let error { finish(.failure(error)) } else if eof { finish(.success(bytes)) } else { receive() }
        }
    }
    private func finish(_ result:Result<Data,any Error>) { guard let continuation else { return };self.continuation = nil;connection.stateUpdateHandler = nil;connection.cancel();continuation.resume(with:result) }
}
