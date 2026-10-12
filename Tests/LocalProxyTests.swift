import Foundation
import Network
import Testing
@testable import ATSDiagnostic

private final class TCPFixture: @unchecked Sendable {
    enum Mode: Sendable, Equatable { case http, echo, upgrade, serverHalfClose }
    private let queue = DispatchQueue(label:"ATS local proxy fixture")
    private let listener: NWListener
    private var connections: [NWConnection] = []
    private var requestData = Data()
    private var starting: CheckedContinuation<UInt16,any Error>?
    private var upgraded = false
    let mode: Mode
    init(mode: Mode) throws {
        self.mode = mode
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host:"127.0.0.1",port:.any)
        listener = try NWListener(using:parameters,on:.any)
    }
    func start() async throws -> UInt16 {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                starting = continuation
                listener.stateUpdateHandler = { [self] state in
                    guard let starting else { return }
                    switch state {
                    case .ready: self.starting = nil; starting.resume(returning:listener.port!.rawValue)
                    case .failed(let error): self.starting = nil; starting.resume(throwing:error)
                    default: break
                    }
                }
                listener.newConnectionHandler = { [self] connection in
                    connections.append(connection);connection.start(queue:queue)
                    if mode == .serverHalfClose { connection.send(content:Data("server greeting".utf8),contentContext:.finalMessage,isComplete:true,completion:.contentProcessed { [self] _ in receive(connection) }) }
                    else { receive(connection) }
                }
                listener.start(queue:queue)
                queue.asyncAfter(deadline:.now()+5) { [self] in if let starting { self.starting = nil; starting.resume(throwing:URLError(.timedOut)) } }
            }
        }
    }
    private func receive(_ connection:NWConnection) {
        connection.receive(minimumIncompleteLength:1,maximumLength:65536) { [self] data,_,eof,error in
            if error != nil { connection.cancel(); return }
            let bytes = data ?? Data(); requestData.append(bytes)
            if mode == .serverHalfClose { if eof { connection.cancel() } else { receive(connection) } }
            else if mode == .echo || upgraded {
                connection.send(content:bytes.isEmpty ? nil : bytes,contentContext:eof ? .finalMessage : .defaultMessage,isComplete:true,completion:.contentProcessed { [self] error in
                    if eof || error != nil { connection.cancel() } else { receive(connection) }
                })
            } else if (try? HTTPProxyMessage.parseRequest(requestData)) != nil {
                if mode == .upgrade {
                    upgraded = true
                    connection.send(content:Data("HTTP/1.1 101 Switching Protocols\r\nConnection: Upgrade\r\nUpgrade: echo\r\n\r\n".utf8),completion:.contentProcessed { [self] _ in receive(connection) });return
                }
                connection.send(content:Data("HTTP/1.1 200 OK\r\nContent-Length: 13\r\nConnection: close\r\n\r\nproxy fixture".utf8),contentContext:.finalMessage,isComplete:true,completion:.contentProcessed { _ in connection.cancel() })
            } else if eof { connection.cancel() } else { receive(connection) }
        }
    }
    func received() -> Data { queue.sync { requestData } }
    func stop() { queue.sync { listener.stateUpdateHandler = nil;listener.newConnectionHandler = nil;listener.cancel();for connection in connections { connection.cancel() };connections = [] } }
}

private final class TCPExchange: @unchecked Sendable {
    private let queue = DispatchQueue(label:"ATS local proxy client")
    private let connection: NWConnection
    private var continuation: CheckedContinuation<Data,any Error>?
    private var response = Data()
    private var afterEOF: Data?
    init(port: UInt16) { connection = NWConnection(host:"127.0.0.1",port:NWEndpoint.Port(rawValue:port)!,using:.tcp) }
    func exchange(_ request:Data,halfClose:Bool = true,afterEOF:Data? = nil) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                self.continuation = continuation
                self.afterEOF = afterEOF
                connection.stateUpdateHandler = { [self] state in
                    switch state {
                    case .ready:
                        // Read concurrently: an echo peer may apply backpressure before
                        // the full upload completes. Waiting to read can deadlock duplex I/O.
                        receive()
                        connection.send(content:request,contentContext:halfClose ? .finalMessage : .defaultMessage,isComplete:true,completion:.contentProcessed { [self] error in if let error { finish(.failure(contextual(error, stage: "client send"))) } })
                    case .failed(let error): finish(.failure(contextual(error, stage: "client connect")))
                    default: break
                    }
                }
                connection.start(queue:queue)
                queue.asyncAfter(deadline:.now()+8) { [self] in finish(.failure(URLError(.timedOut))) }
            }
        }
    }
    private func receive() {
        connection.receive(minimumIncompleteLength:1,maximumLength:65536) { [self] data,_,eof,error in
            if let data { response.append(data) }
            if let error { finish(.failure(contextual(error, stage: "client receive"))) } else if eof {
                if let afterEOF { self.afterEOF = nil;connection.send(content:afterEOF,contentContext:.finalMessage,isComplete:true,completion:.contentProcessed { [self] error in if let error { finish(.failure(error)) } else { finish(.success(response)) } }) }
                else { finish(.success(response)) }
            } else { receive() }
        }
    }
    private func contextual(_ error: NWError, stage: String) -> NSError {
        let original = error as NSError
        return NSError(domain: original.domain, code: original.code, userInfo: [NSLocalizedDescriptionKey: "\(stage): \(error)", NSUnderlyingErrorKey: error])
    }
    private func finish(_ result:Result<Data,any Error>) {
        guard let continuation else { return };self.continuation = nil;connection.stateUpdateHandler = nil;connection.cancel();continuation.resume(with:result)
    }
}

private func proxyPort(_ stream:AsyncStream<LocalProxyEvent>) async throws -> UInt16 {
    for await event in stream {
        if case .listening(let port) = event { return port }
        if case .failed(let error) = event { throw NSError(domain:error,code:1) }
    }
    throw URLError(.cannotConnectToHost)
}
struct LocalProxyTests {
    @Test func httpActuallyForwardsOriginFormAndStripsProxySecret() async throws {
        let fixture = try TCPFixture(mode:.http); let origin = try await fixture.start(); defer { fixture.stop() }
        let pair = AsyncStream<LocalProxyEvent>.makeStream()
        let proxy = LocalHTTPProxy(idleTimeout:3,maximumDuration:5,event:{ pair.continuation.yield($0) });proxy.start();defer { proxy.stop();pair.continuation.finish() }
        let port = try await proxyPort(pair.stream)
        let request = Data("GET http://127.0.0.1:\(origin)/one?q=1 HTTP/1.1\r\nHost: wrong.test\r\nProxy-Authorization: secret\r\n\r\n".utf8)
        let response = try await TCPExchange(port:port).exchange(request)
        #expect(String(decoding:response,as:UTF8.self).hasSuffix("proxy fixture"))
        let forwarded = String(decoding:fixture.received(),as:UTF8.self)
        #expect(forwarded.hasPrefix("GET /one?q=1 HTTP/1.1\r\n"));#expect(forwarded.contains("Host: 127.0.0.1:\(origin)"));#expect(!forwarded.contains("secret"))
        for await event in pair.stream { if case .capture(let record) = event, !record.active { #expect(record.status == 200);#expect(record.receivedBytes == response.count);#expect(!record.responsePreview.isEmpty);break } }
    }
    @Test func connectRelaysLargeOpaqueBytesAndHalfClose() async throws {
        let fixture = try TCPFixture(mode:.echo);let origin = try await fixture.start();defer { fixture.stop() }
        let pair = AsyncStream<LocalProxyEvent>.makeStream()
        let proxy = LocalHTTPProxy(idleTimeout:3,maximumDuration:5,event:{ pair.continuation.yield($0) });proxy.start();defer { proxy.stop();pair.continuation.finish() }
        let port = try await proxyPort(pair.stream)
        let payload = Data((0..<(512*1024)).map { UInt8($0 % 251) })
        var request = Data("CONNECT 127.0.0.1:\(origin) HTTP/1.1\r\nHost: 127.0.0.1:\(origin)\r\n\r\n".utf8);request.append(payload)
        let response = try await TCPExchange(port:port).exchange(request)
        let header = Data("HTTP/1.1 200 Connection Established\r\n\r\n".utf8)
        #expect(response.starts(with:header));#expect(Data(response.dropFirst(header.count)) == payload)
        for await event in pair.stream { if case .capture(let record) = event,!record.active { #expect(record.state == .completed, "Terminal state: \(record.state), error: \(record.error ?? "none")");#expect(record.sentBytes == payload.count);#expect(record.receivedBytes == payload.count);#expect(record.requestPreview.isEmpty && record.responsePreview.isEmpty);break } }
    }
    @Test func ambiguousFramingRejectedBeforeConnecting() async throws {
        let pair = AsyncStream<LocalProxyEvent>.makeStream();let proxy = LocalHTTPProxy(idleTimeout:3,maximumDuration:5,event:{ pair.continuation.yield($0) });proxy.start();defer { proxy.stop();pair.continuation.finish() }
        let port = try await proxyPort(pair.stream)
        let response = try await TCPExchange(port:port).exchange(Data("POST http://example.com/ HTTP/1.1\r\nHost: example.com\r\nContent-Length: 1\r\nTransfer-Encoding: chunked\r\n\r\nx".utf8))
        #expect(ProxyWire.responseStatus(response) == 400)
    }
    @Test func selfLoopRejectedAndIdleConnectionClosed() async throws {
        let pair = AsyncStream<LocalProxyEvent>.makeStream();let proxy = LocalHTTPProxy(idleTimeout:1,maximumDuration:4,event:{ pair.continuation.yield($0) });proxy.start();defer { proxy.stop();pair.continuation.finish() }
        let port = try await proxyPort(pair.stream)
        let loop = try await TCPExchange(port:port).exchange(Data("CONNECT 127.0.0.1:\(port) HTTP/1.1\r\nHost: 127.0.0.1:\(port)\r\n\r\n".utf8))
        #expect(ProxyWire.responseStatus(loop) == 508)
        let idle = try await TCPExchange(port:port).exchange(Data("GET ".utf8),halfClose:false)
        #expect(ProxyWire.responseStatus(idle) == 504)
    }
    @Test func interimResponseDoesNotHideFinalStatus() { #expect(ProxyWire.responseStatus(Data("HTTP/1.1 103 Early Hints\r\nLink: x\r\n\r\nHTTP/1.1 200 OK\r\n\r\n".utf8)) == 200) }
    @Test func upgradeHeadersArePreservedButProxyAuthIsNot() throws {
        let request = try #require(try HTTPProxyMessage.parseRequest(Data("GET http://example.com/chat HTTP/1.1\r\nHost: example.com\r\nConnection: Upgrade\r\nUpgrade: websocket\r\nProxy-Authorization: hidden\r\n\r\n".utf8)))
        let wire = String(decoding:request.upstreamBytes(),as:UTF8.self)
        #expect(wire.contains("Connection: Upgrade"));#expect(wire.contains("Upgrade: websocket"));#expect(!wire.contains("hidden"))
    }
    @Test func serverHalfCloseDoesNotDiscardLaterClientBytes() async throws {
        let fixture = try TCPFixture(mode:.serverHalfClose);let origin = try await fixture.start();defer { fixture.stop() }
        let pair = AsyncStream<LocalProxyEvent>.makeStream();let proxy = LocalHTTPProxy(idleTimeout:3,maximumDuration:5,event:{ pair.continuation.yield($0) });proxy.start();defer { proxy.stop();pair.continuation.finish() }
        let port = try await proxyPort(pair.stream)
        let request = Data("CONNECT 127.0.0.1:\(origin) HTTP/1.1\r\nHost: 127.0.0.1:\(origin)\r\n\r\n".utf8)
        let late = Data("client sends after server EOF".utf8)
        let response = try await TCPExchange(port:port).exchange(request,halfClose:false,afterEOF:late)
        #expect(String(decoding:response,as:UTF8.self).hasSuffix("server greeting"))
        for _ in 0..<100 { if fixture.received() == late { break };try await Task.sleep(for:.milliseconds(10)) }
        #expect(fixture.received() == late)
    }
    @Test func upgradeBecomesBidirectionalStream() async throws {
        let fixture = try TCPFixture(mode:.upgrade);let origin = try await fixture.start();defer { fixture.stop() }
        let pair = AsyncStream<LocalProxyEvent>.makeStream();let proxy = LocalHTTPProxy(idleTimeout:3,maximumDuration:5,event:{ pair.continuation.yield($0) });proxy.start();defer { proxy.stop();pair.continuation.finish() }
        let port = try await proxyPort(pair.stream)
        let payload = Data("opaque upgraded frames".utf8)
        var request = Data("GET http://127.0.0.1:\(origin)/ HTTP/1.1\r\nHost: 127.0.0.1:\(origin)\r\nConnection: Upgrade\r\nUpgrade: echo\r\n\r\n".utf8);request.append(payload)
        let response = try await TCPExchange(port:port).exchange(request)
        #expect(ProxyWire.responseStatus(response) == 101);#expect(response.suffix(payload.count) == payload)
    }
    @Test func postBodyReallyReachesOriginWithNormalizedLength() async throws {
        let fixture = try TCPFixture(mode:.http);let origin = try await fixture.start();defer { fixture.stop() }
        let pair = AsyncStream<LocalProxyEvent>.makeStream();let proxy = LocalHTTPProxy(idleTimeout:3,maximumDuration:5,event:{ pair.continuation.yield($0) });proxy.start();defer { proxy.stop();pair.continuation.finish() }
        let port = try await proxyPort(pair.stream)
        let payload = Data(repeating:65,count:256*1024)
        var request = Data("POST http://127.0.0.1:\(origin)/upload HTTP/1.1\r\nHost: wrong.test\r\nContent-Length: \(payload.count), \(payload.count)\r\n\r\n".utf8);request.append(payload)
        let response = try await TCPExchange(port:port).exchange(request)
        #expect(ProxyWire.responseStatus(response) == 200)
        let parsed = try #require(try HTTPProxyMessage.parseRequest(fixture.received()))
        #expect(parsed.body == payload);#expect(parsed.headers.filter { $0.name == "Content-Length" }.count == 1)
    }
}
