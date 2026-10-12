import Foundation
import Network
import Darwin
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
                    if error != nil { connection.cancel() }
                    else if !eof { receive(connection) }
                    else if mode != .echo { connection.cancel() }
                    // Keep the echo peer alive until the test has observed proxy
                    // completion; immediate cancellation races final FIN processing.
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

private final class ResetTCPFixture: @unchecked Sendable {
    private let descriptor: Int32
    let port: UInt16
    init() throws {
        let descriptor = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        self.descriptor = descriptor
        guard descriptor >= 0 else { throw POSIXError(.EIO) }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &address) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        guard bound == 0, Darwin.listen(descriptor, 1) == 0 else { Darwin.close(descriptor); throw POSIXError(.EIO) }
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let identified = withUnsafeMutablePointer(to: &address) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(descriptor, $0, &length) } }
        guard identified == 0 else { Darwin.close(descriptor); throw POSIXError(.EIO) }
        port = UInt16(bigEndian: address.sin_port)
    }
    func resetAfterFirstByte() async throws {
        let descriptor = descriptor
        try await Task.detached {
            let peer = Darwin.accept(descriptor, nil, nil)
            guard peer >= 0 else { throw POSIXError(.EIO) }
            defer { Darwin.close(peer) }
            var timeout = timeval(tv_sec: 5, tv_usec: 0)
            _ = setsockopt(peer, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
            var byte: UInt8 = 0
            guard Darwin.recv(peer, &byte, 1, 0) == 1 else { throw POSIXError(.EIO) }
            var reset = linger(l_onoff: 1, l_linger: 0)
            guard setsockopt(peer, SOL_SOCKET, SO_LINGER, &reset, socklen_t(MemoryLayout<linger>.size)) == 0 else { throw POSIXError(.EIO) }
        }.value
    }
    func stop() { Darwin.close(descriptor) }
}

private final class TCPExchange: @unchecked Sendable {
    private let queue = DispatchQueue(label:"ATS local proxy client")
    private let connection: NWConnection
    private var continuation: CheckedContinuation<Data,any Error>?
    private var response = Data()
    private var afterEOF: Data?
    private var becameReady = false
    private let keepOpenAfterResponse: Bool
    init(port: UInt16, keepOpenAfterResponse: Bool = false) { self.keepOpenAfterResponse = keepOpenAfterResponse; connection = NWConnection(host:"127.0.0.1",port:NWEndpoint.Port(rawValue:port)!,using:.tcp) }
    func exchange(_ request:Data,halfClose:Bool = true,afterEOF:Data? = nil) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                self.continuation = continuation
                self.afterEOF = afterEOF
                connection.stateUpdateHandler = { [self] state in
                    switch state {
                    case .ready:
                        becameReady = true
                        // Read concurrently: an echo peer may apply backpressure before
                        // the full upload completes. Waiting to read can deadlock duplex I/O.
                        receive()
                        connection.send(content:request,contentContext:halfClose ? .finalMessage : .defaultMessage,isComplete:true,completion:.contentProcessed { [self] error in if let error { finish(.failure(contextual(error, stage: "client send"))) } })
                    case .failed(let error):
                        // Once reading has begun its completion is authoritative;
                        // state changes must not overtake pending content/FIN delivery.
                        if !becameReady { finish(.failure(contextual(error, stage: "client connect"))) }
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
    func stop() { queue.sync { connection.stateUpdateHandler = nil; connection.cancel() } }
    private func finish(_ result:Result<Data,any Error>) {
        guard let continuation else { return };self.continuation = nil;connection.stateUpdateHandler = nil
        if case .failure = result { connection.cancel() }
        else if !keepOpenAfterResponse { connection.cancel() }
        continuation.resume(with:result)
    }
}

private func proxyPort(_ stream:AsyncStream<LocalProxyEvent>) async throws -> UInt16 {
    for await event in stream {
        if case .listening(let port) = event { return port }
        if case .failed(let error) = event { throw NSError(domain:error,code:1) }
    }
    throw URLError(.cannotConnectToHost)
}
@Suite(.serialized)
struct LocalProxyTests {
    @Test func realTCPResetStillProducesOriginalTransferFailure() async throws {
        let fixture = try ResetTCPFixture(); defer { fixture.stop() }
        let reset = Task { try await fixture.resetAfterFirstByte() }
        let pair = AsyncStream<LocalProxyEvent>.makeStream()
        let proxy = LocalHTTPProxy(idleTimeout: 3, maximumDuration: 5, event: { pair.continuation.yield($0) })
        proxy.start(); defer { proxy.stopAndDrain(); pair.continuation.finish() }
        let port = try await proxyPort(pair.stream)
        var request = Data("CONNECT 127.0.0.1:\(fixture.port) HTTP/1.1\r\nHost: 127.0.0.1:\(fixture.port)\r\n\r\n".utf8)
        request.append(Data(repeating: 0x42, count: 128 * 1024))
        do { _ = try await TCPExchange(port: port).exchange(request) } catch {}
        try await reset.value
        for await event in pair.stream {
            if case .capture(let record) = event, !record.active {
                #expect(record.state == .failed)
                #expect(record.failurePhase != nil)
                #expect(record.transportErrors?.isEmpty == false)
                #expect(record.error != nil)
                break
            }
        }
    }
    @Test func exactRuleActuallyMapsTargetReframesBodyAndRecordsOrigin() async throws {
        let fixture = try TCPFixture(mode: .http)
        let origin = try await fixture.start(); defer { fixture.stop() }
        let original = "http://original.invalid/source"
        let mapped = "http://127.0.0.1:\(origin)/mapped?q=1"
        let rule = try HTTPProxyRewriteRule(matchURL: original, replacementURL: mapped, method: "PUT", headers: ["X-Rewrite":"first"], body: Data("edited".utf8))
        let later = try HTTPProxyRewriteRule(matchURL: original, replacementURL: mapped, headers: ["X-Rewrite":"later"])
        let pair = AsyncStream<LocalProxyEvent>.makeStream()
        let proxy = LocalHTTPProxy(idleTimeout: 3, maximumDuration: 5, rewriteRules: [rule, later], event: { pair.continuation.yield($0) })
        proxy.start(); defer { proxy.stopAndDrain(); pair.continuation.finish() }
        let port = try await proxyPort(pair.stream)
        let input = Data("POST \(original) HTTP/1.1\r\nHost: original.invalid\r\nAuthorization: Bearer old-secret\r\nCookie: old=secret\r\nTransfer-Encoding: chunked\r\n\r\n3\r\nold\r\n0\r\n\r\n".utf8)
        let response = try await TCPExchange(port: port).exchange(input)
        #expect(ProxyWire.responseStatus(response) == 200)
        let received = try #require(try HTTPProxyMessage.parseRequest(fixture.received()))
        #expect(received.method == "PUT")
        #expect(received.url.path == "/mapped"); #expect(received.url.query == "q=1")
        #expect(received.body == Data("edited".utf8))
        #expect(received.headers.contains { $0.name == "X-Rewrite" && $0.value == "first" })
        #expect(!received.headers.contains { ["authorization", "cookie", "transfer-encoding"].contains($0.name.lowercased()) })
        for await event in pair.stream {
            if case .capture(let record) = event, !record.active {
                #expect(record.originalTarget == original); #expect(record.target == mapped)
                #expect(record.rewriteRuleApplied == true); #expect(record.status == 200)
                break
            }
        }
    }
    @Test func oversizedRewrittenHeadersAreRejectedBeforeOriginConnect() async throws {
        let fixture = try TCPFixture(mode: .http)
        let origin = try await fixture.start(); defer { fixture.stop() }
        let target = "http://127.0.0.1:\(origin)/too-large"
        let rule = try HTTPProxyRewriteRule(matchURL: target, headers: ["X-Padding":String(repeating: "x", count: HTTPProxyMessage.headerLimit)])
        let pair = AsyncStream<LocalProxyEvent>.makeStream()
        let proxy = LocalHTTPProxy(idleTimeout: 3, maximumDuration: 5, rewriteRules: [rule], event: { pair.continuation.yield($0) })
        proxy.start(); defer { proxy.stopAndDrain(); pair.continuation.finish() }
        let port = try await proxyPort(pair.stream)
        let response = try await TCPExchange(port: port).exchange(Data("GET \(target) HTTP/1.1\r\nHost: fixture\r\n\r\n".utf8))
        #expect(ProxyWire.responseStatus(response) == 422)
        #expect(fixture.received().isEmpty)
    }
    @Test func httpActuallyForwardsOriginFormAndStripsProxySecret() async throws {
        let fixture = try TCPFixture(mode:.http); let origin = try await fixture.start(); defer { fixture.stop() }
        let pair = AsyncStream<LocalProxyEvent>.makeStream()
        let proxy = LocalHTTPProxy(idleTimeout:3,maximumDuration:5,event:{ pair.continuation.yield($0) });proxy.start();defer { proxy.stopAndDrain();pair.continuation.finish() }
        let port = try await proxyPort(pair.stream)
        let request = Data("GET http://127.0.0.1:\(origin)/one?q=1 HTTP/1.1\r\nHost: wrong.test\r\nProxy-Authorization: secret\r\n\r\n".utf8)
        let response = try await TCPExchange(port:port).exchange(request)
        #expect(String(decoding:response,as:UTF8.self).hasSuffix("proxy fixture"))
        let forwarded = String(decoding:fixture.received(),as:UTF8.self)
        #expect(forwarded.hasPrefix("GET /one?q=1 HTTP/1.1\r\n"));#expect(forwarded.contains("Host: 127.0.0.1:\(origin)"));#expect(!forwarded.contains("secret"))
        for await event in pair.stream { if case .capture(let record) = event, !record.active { #expect(record.status == 200);#expect(record.receivedBytes == response.count);#expect(!record.responsePreview.isEmpty);break } }
    }
    @Test(arguments: 0..<8) func connectRelaysLargeOpaqueBytesAndHalfClose(_ iteration: Int) async throws {
        let fixture = try TCPFixture(mode:.echo);let origin = try await fixture.start();defer { fixture.stop() }
        let pair = AsyncStream<LocalProxyEvent>.makeStream()
        let proxy = LocalHTTPProxy(idleTimeout:3,maximumDuration:5,event:{ pair.continuation.yield($0) });proxy.start();defer { proxy.stopAndDrain();pair.continuation.finish() }
        let port = try await proxyPort(pair.stream)
        let payload = Data((0..<(512*1024)).map { UInt8($0 % 251) })
        var request = Data("CONNECT 127.0.0.1:\(origin) HTTP/1.1\r\nHost: 127.0.0.1:\(origin)\r\n\r\n".utf8);request.append(payload)
        let exchange = TCPExchange(port: port, keepOpenAfterResponse: true); defer { exchange.stop() }
        let response = try await exchange.exchange(request)
        let header = Data("HTTP/1.1 200 Connection Established\r\n\r\n".utf8)
        #expect(response.starts(with:header));#expect(Data(response.dropFirst(header.count)) == payload)
        for await event in pair.stream { if case .capture(let record) = event,!record.active { #expect(record.state == .completed, "Terminal state: \(record.state), error: \(record.error ?? "none"), client read/write \(String(describing: record.clientReadClosed))/\(String(describing: record.clientWriteClosed)), upstream read/write \(String(describing: record.upstreamReadClosed))/\(String(describing: record.upstreamWriteClosed))");#expect(record.sentBytes == payload.count);#expect(record.receivedBytes == payload.count);#expect(record.requestPreview.isEmpty && record.responsePreview.isEmpty);break } }
    }
    @Test func ambiguousFramingRejectedBeforeConnecting() async throws {
        let pair = AsyncStream<LocalProxyEvent>.makeStream();let proxy = LocalHTTPProxy(idleTimeout:3,maximumDuration:5,event:{ pair.continuation.yield($0) });proxy.start();defer { proxy.stopAndDrain();pair.continuation.finish() }
        let port = try await proxyPort(pair.stream)
        let response = try await TCPExchange(port:port).exchange(Data("POST http://example.com/ HTTP/1.1\r\nHost: example.com\r\nContent-Length: 1\r\nTransfer-Encoding: chunked\r\n\r\nx".utf8))
        #expect(ProxyWire.responseStatus(response) == 400)
    }
    @Test func selfLoopRejectedAndIdleConnectionClosed() async throws {
        let pair = AsyncStream<LocalProxyEvent>.makeStream();let proxy = LocalHTTPProxy(idleTimeout:1,maximumDuration:4,event:{ pair.continuation.yield($0) });proxy.start();defer { proxy.stopAndDrain();pair.continuation.finish() }
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
        let pair = AsyncStream<LocalProxyEvent>.makeStream();let proxy = LocalHTTPProxy(idleTimeout:3,maximumDuration:5,event:{ pair.continuation.yield($0) });proxy.start();defer { proxy.stopAndDrain();pair.continuation.finish() }
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
        let pair = AsyncStream<LocalProxyEvent>.makeStream();let proxy = LocalHTTPProxy(idleTimeout:3,maximumDuration:5,event:{ pair.continuation.yield($0) });proxy.start();defer { proxy.stopAndDrain();pair.continuation.finish() }
        let port = try await proxyPort(pair.stream)
        let payload = Data("opaque upgraded frames".utf8)
        var request = Data("GET http://127.0.0.1:\(origin)/ HTTP/1.1\r\nHost: 127.0.0.1:\(origin)\r\nConnection: Upgrade\r\nUpgrade: echo\r\n\r\n".utf8);request.append(payload)
        let response = try await TCPExchange(port:port).exchange(request)
        #expect(ProxyWire.responseStatus(response) == 101);#expect(response.suffix(payload.count) == payload)
    }
    @Test func postBodyReallyReachesOriginWithNormalizedLength() async throws {
        let fixture = try TCPFixture(mode:.http);let origin = try await fixture.start();defer { fixture.stop() }
        let pair = AsyncStream<LocalProxyEvent>.makeStream();let proxy = LocalHTTPProxy(idleTimeout:3,maximumDuration:5,event:{ pair.continuation.yield($0) });proxy.start();defer { proxy.stopAndDrain();pair.continuation.finish() }
        let port = try await proxyPort(pair.stream)
        let payload = Data(repeating:65,count:256*1024)
        var request = Data("POST http://127.0.0.1:\(origin)/upload HTTP/1.1\r\nHost: wrong.test\r\nContent-Length: \(payload.count), \(payload.count)\r\n\r\n".utf8);request.append(payload)
        let response = try await TCPExchange(port:port).exchange(request)
        #expect(ProxyWire.responseStatus(response) == 200)
        let parsed = try #require(try HTTPProxyMessage.parseRequest(fixture.received()))
        #expect(parsed.body == payload);#expect(parsed.headers.filter { $0.name == "Content-Length" }.count == 1)
    }
}
