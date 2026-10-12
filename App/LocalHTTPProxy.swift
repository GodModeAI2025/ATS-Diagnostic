import Foundation
import Network
import Security

enum LocalProxyEvent: Sendable { case listening(UInt16), failed(String), stopped, capture(ProxyCapture) }

final class LocalHTTPProxy: @unchecked Sendable {
    private let queue = DispatchQueue(label:"ATS Diagnostic local proxy")
    private let event: @Sendable (LocalProxyEvent) -> Void
    private var listener: NWListener?
    private var workers: [UUID: ProxyRelay] = [:]
    private var stopping = false
    private var startupWork: DispatchWorkItem?
    private let idleTimeout: Double
    private let maximumDuration: Double
    private let rewriteRules: [HTTPProxyRewriteRule]
    init(idleTimeout: Double = 60, maximumDuration: Double = 3600, rewriteRules: [HTTPProxyRewriteRule] = [], event: @escaping @Sendable (LocalProxyEvent) -> Void) {
        self.idleTimeout = max(1,min(idleTimeout,3600)); self.maximumDuration = max(1,min(maximumDuration,86400)); self.rewriteRules = rewriteRules; self.event = event
    }
    func start(port: UInt16 = 0) {
        queue.async { [self] in
            guard listener == nil, !stopping else { return }
            do {
                let parameters = NWParameters.tcp
                parameters.requiredLocalEndpoint = .hostPort(host:"127.0.0.1",port:NWEndpoint.Port(rawValue:port)!)
                let listener = try NWListener(using:parameters,on:NWEndpoint.Port(rawValue:port)!)
                self.listener = listener
                listener.stateUpdateHandler = { [weak self] state in
                    guard let self else { return }
                    switch state {
                    case .ready: startupWork?.cancel(); if let port = self.listener?.port { event(.listening(port.rawValue)) }
                    case .failed(let error): event(.failed(error.localizedDescription)); shutdown(reason:"Listener fehlgeschlagen")
                    default: break
                    }
                }
                listener.newConnectionHandler = { [weak self] connection in
                    guard let self, !stopping else { connection.cancel(); return }
                    guard workers.count < 8 else {
                        connection.start(queue:queue)
                        connection.send(content:ProxyWire.errorResponse(503,message:"Alle acht Proxy-Verbindungen sind belegt."),completion:.contentProcessed { _ in connection.cancel() }); return
                    }
                    let worker = ProxyRelay(client:connection,proxyPort:self.listener?.port?.rawValue ?? port,queue:queue,idleTimeout:idleTimeout,maximumDuration:maximumDuration,rewriteRules:rewriteRules,event:event,closed:{ [weak self] id in self?.workers.removeValue(forKey:id) })
                    workers[worker.id] = worker; worker.start()
                }
                listener.start(queue:queue)
                let timeout = DispatchWorkItem { [weak self] in guard let self else { return };event(.failed("Der lokale Proxy konnte nicht innerhalb von 10 Sekunden starten."));shutdown(reason:"Startzeitlimit") }
                startupWork = timeout;queue.asyncAfter(deadline:.now()+10,execute:timeout)
            } catch { event(.failed(error.localizedDescription)) }
        }
    }
    func stop(reason: String = "Proxy gestoppt") { queue.async { [self] in shutdown(reason:reason) } }
    /// Used by synchronous fixture teardown; do not call from the proxy queue.
    func stopAndDrain(reason: String = "Proxy gestoppt") { queue.sync { shutdown(reason: reason) } }
    deinit {
        listener?.cancel()
        let active = Array(workers.values)
        queue.async { for worker in active { worker.stop(reason:"Proxy freigegeben") } }
    }
    private func shutdown(reason: String) {
        guard !stopping else { return }; stopping = true
        startupWork?.cancel(); startupWork = nil
        listener?.stateUpdateHandler = nil; listener?.newConnectionHandler = nil; listener?.cancel(); listener = nil
        let active = Array(workers.values)
        for worker in active { worker.stop(reason:reason) }
        workers.removeAll(); event(.stopped)
    }
}

private final class ProxyRelay: @unchecked Sendable {
    var id: UUID { record.id }
    private var record = ProxyCapture()
    private let client: NWConnection
    private var upstream: NWConnection?
    private let proxyPort: UInt16
    private let queue: DispatchQueue
    private let idleTimeout: Double
    private let maximumDuration: Double
    private let rewriteRules: [HTTPProxyRewriteRule]
    private let event: @Sendable (LocalProxyEvent) -> Void
    private let closed: (UUID) -> Void
    private var input = Data()
    private var wantsUpgrade = false
    private var pendingUpgrade = Data()
    private var finished = false
    private var rejecting = false
    private var sentControlResponse = false
    private var receivedClientEOF = false
    private var receivedUpstreamEOF = false
    private var clientWriteClosed = false
    private var upstreamWriteClosed = false
    private var acknowledgedContinue = false
    private var readingClientStream = false
    private var idleWork: DispatchWorkItem?
    private var lifetimeWork: DispatchWorkItem?
    private var headerWork: DispatchWorkItem?
    private let clock = ContinuousClock()
    private var began: ContinuousClock.Instant?
    private var lastProgress: ContinuousClock.Instant?
    init(client: NWConnection,proxyPort:UInt16,queue:DispatchQueue,idleTimeout:Double,maximumDuration:Double,rewriteRules:[HTTPProxyRewriteRule],event:@escaping @Sendable(LocalProxyEvent)->Void,closed:@escaping(UUID)->Void) {
        self.client = client; self.proxyPort = proxyPort; self.queue = queue; self.idleTimeout = idleTimeout; self.maximumDuration = maximumDuration; self.rewriteRules = rewriteRules; self.event = event; self.closed = closed
    }
    func start() {
        began = clock.now; emit(force:true)
        client.stateUpdateHandler = { [weak self] state in if case .failed(let error) = state { self?.connectionStateFailed(error, phase: "Client-Verbindung") } }
        client.start(queue:queue)
        let lifetime = DispatchWorkItem { [weak self] in self?.reject(504,"Das Gesamtzeitlimit der Proxy-Verbindung ist erreicht.") }
        lifetimeWork = lifetime; queue.asyncAfter(deadline:.now()+maximumDuration,execute:lifetime)
        let header = DispatchWorkItem { [weak self] in self?.reject(408,"Die Anfrage-Header wurden nicht innerhalb von 15 Sekunden vollständig empfangen.") }
        headerWork = header; queue.asyncAfter(deadline:.now()+15,execute:header)
        refreshIdle(); receiveRequest()
    }
    func stop(reason:String) { finish(state:.stopped,message:reason) }
    private func receiveRequest() {
        guard !finished else { return }
        client.receive(minimumIncompleteLength:1,maximumLength:64*1024) { [weak self] data,context,complete,error in
            let eof = complete && context?.isFinal == true
            guard let self, !finished else { return }
            if let error { failTransfer(error, phase: "Empfang vom Client"); return }
            if let data, !data.isEmpty {
                refreshIdle(); input.append(data)
                guard input.count <= 2*ProxyWire.requestLimit + HTTPProxyMessage.headerLimit else { reject(413,"Die Anfrage überschreitet das Pufferlimit."); return }
                do {
                    let parsed = try HTTPProxyMessage.parseRequest(input,bodyLimit:ProxyWire.requestLimit)
                    if input.range(of:Data("\r\n\r\n".utf8)) != nil { headerWork?.cancel(); headerWork = nil }
                    if let expectation = try ProxyWire.expectation(input) {
                        guard expectation == "100-continue" else { reject(417,"Diese Expect-Anforderung wird nicht unterstützt."); return }
                        if parsed == nil, !acknowledgedContinue { acknowledgedContinue = true; client.send(content:Data("HTTP/1.1 100 Continue\r\n\r\n".utf8),completion:.contentProcessed { [weak self] error in if let error { self?.failTransfer(error, phase: "100-Continue-Antwort senden") } }) }
                    }
                    if let parsed { receivedClientEOF = eof; connect(parsed); return }
                } catch let error as HTTPProxyMessage.ParseError {
                    let status = error == .bodyTooLarge ? 413 : error == .headerTooLarge ? 431 : 400
                    reject(status,error == .bodyTooLarge ? "Der Anfragekörper ist größer als 16 MiB." : "Die HTTP-Anfrage ist unvollständig, ungültig oder mehrdeutig gerahmt."); return
                } catch { reject(400,"Ungültige HTTP-Anfrage."); return }
            }
            if eof { reject(400,"Die Verbindung endete vor einer vollständigen HTTP-Anfrage.") } else { receiveRequest() }
        }
    }
    private func connect(_ received: ProxyHTTPRequest) {
        record.method = received.method; record.target = received.url.absoluteString
        let request: ProxyHTTPRequest
        do {
            if let rule = rewriteRules.first(where: { $0.matchURL == received.url.absoluteString }) {
                request = try rule.applying(to: received)
                record.originalTarget = received.url.absoluteString
                record.rewriteRuleApplied = true
            } else { request = received }
        } catch { reject(422, error.localizedDescription); return }

        wantsUpgrade = request.requestsUpgrade
        let host = ProxyWire.host(request.url), port = UInt16(request.url.port ?? (request.url.scheme == "https" ? 443 : 80))
        guard !host.isEmpty else { reject(400,"Kein gültiges Ziel."); return }
        if port == proxyPort && (["localhost","127.0.0.1","::1"].contains(host.lowercased()) || IPv4Address(host)?.isLoopback == true) { reject(508,"Das Proxy-Ziel verweist auf diesen Proxy selbst."); return }
        let extra = Data(input.dropFirst(request.consumedBytes))
        guard request.isTunnel || request.requestsUpgrade || extra.isEmpty else { reject(400,"Mehrere gepipelinete HTTP-Anfragen pro Verbindung werden noch nicht unterstützt."); return }
        pendingUpgrade = extra; input = Data()
        record.method = request.method; record.target = request.url.absoluteString; record.state = .connecting
        if !request.isTunnel { record.requestPreview = Data(request.upstreamBytes().prefix(ProxyWire.previewLimit)) }
        emit(force:true)
        let parameters: NWParameters
        if !request.isTunnel && request.url.scheme == "https" {
            let options = NWProtocolTLS.Options()
            sec_protocol_options_set_min_tls_protocol_version(options.securityProtocolOptions,.TLSv12)
            sec_protocol_options_set_tls_server_name(options.securityProtocolOptions,host)
            sec_protocol_options_set_verify_block(options.securityProtocolOptions,{ [weak self] _,trust,complete in
                let reference = sec_trust_copy_ref(trust).takeRetainedValue()
                SecTrustSetPolicies(reference,SecPolicyCreateSSL(true,host as CFString))
                var error: CFError?
                let valid = SecTrustEvaluateWithError(reference,&error)
                complete(valid)
                if !valid, let self, !finished {
                    record.upstreamTrustErrors = error.map { ErrorEvidence.capture($0 as Error) }
                    let diagnostic = DiagnosticRecord(url:request.url.absoluteString,method:request.method,trustValid:false,trustErrors:record.upstreamTrustErrors)
                    reject(502,DiagnosticFailure.explain(diagnostic)?.title ?? "Die Server-Zertifikatsprüfung ist fehlgeschlagen.")
                }
            },queue)
            parameters = NWParameters(tls:options,tcp:NWProtocolTCP.Options())
        } else { parameters = .tcp }
        let connection = NWConnection(host:NWEndpoint.Host(host),port:NWEndpoint.Port(rawValue:port)!,using:parameters)
        upstream = connection
        connection.stateUpdateHandler = { [weak self] state in
            guard let self, !finished else { return }
            switch state {
            case .ready:
                if let endpoint = connection.currentPath?.remoteEndpoint, case .hostPort(let resolvedHost,let resolvedPort) = endpoint, resolvedPort.rawValue == proxyPort {
                    switch resolvedHost {
                    case .ipv4(let address) where address.isLoopback: reject(508,"Das aufgelöste Ziel verweist auf diesen Proxy selbst."); return
                    case .ipv6(let address) where address.isLoopback: reject(508,"Das aufgelöste Ziel verweist auf diesen Proxy selbst."); return
                    default: break
                    }
                }
                if let metadata = connection.metadata(definition:NWProtocolTLS.definition) as? NWProtocolTLS.Metadata {
                    record.upstreamTLS = String(format:"0x%04x",sec_protocol_metadata_get_negotiated_tls_protocol_version(metadata.securityProtocolMetadata).rawValue)
                    record.upstreamCipher = String(format:"0x%04x",sec_protocol_metadata_get_negotiated_tls_ciphersuite(metadata.securityProtocolMetadata).rawValue)
                }
                connection.stateUpdateHandler = { [weak self] state in if case .failed(let error) = state { self?.connectionStateFailed(error, phase: "Ziel-Verbindung") } }
                established(request)
            case .failed(let error): reject(502,"Das Ziel konnte nicht verbunden werden: \(error.localizedDescription)")
            default: break
            }
        }
        connection.start(queue:queue)
    }
    private func established(_ request: ProxyHTTPRequest) {
        refreshIdle()
        if request.isTunnel {
            record.state = .tunnel; record.status = 200; sentControlResponse = true; emit(force:true)
            client.send(content:Data("HTTP/1.1 200 Connection Established\r\n\r\n".utf8),completion:.contentProcessed { [weak self] error in
                guard let self, !finished else { return }; if let error { failTransfer(error, phase: "CONNECT-Antwort senden"); return }
                let first = pendingUpgrade; pendingUpgrade = Data()
                sendUpstream(first,eof:receivedClientEOF) { [weak self] in self?.startClientStream() }
                receiveUpstream()
            })
        } else {
            record.state = .forwarding; emit(force:true)
            sendUpstream(request.upstreamBytes(),eof:false) { [weak self] in self?.receiveUpstream() }
        }
    }
    private func sendUpstream(_ data:Data,eof:Bool,then:@escaping @Sendable()->Void) {
        guard !finished, let upstream else { return }
        if data.isEmpty && !eof { then(); return }
        upstream.send(content:data.isEmpty ? nil : data,contentContext:eof ? .finalMessage : .defaultMessage,isComplete:true,completion:.contentProcessed { [weak self] error in
            guard let self, !finished else { return }; if let error { failTransfer(error, phase: "Senden an das Ziel") } else { record.sentBytes += data.count; if eof { upstreamWriteClosed = true }; emit(); then() }
        })
    }
    private func startClientStream() {
        guard !readingClientStream, !receivedClientEOF, !finished else { return }; readingClientStream = true; receiveClientStream()
    }
    private func receiveClientStream() {
        guard !finished else { return }
        client.receive(minimumIncompleteLength:1,maximumLength:64*1024) { [weak self] data,context,complete,error in
            let eof = complete && context?.isFinal == true
            guard let self, !finished else { return }; if let error { failTransfer(error, phase: "Empfang vom Client"); return }
            if let data, !data.isEmpty { refreshIdle() }
            receivedClientEOF = eof
            sendUpstream(data ?? Data(),eof:eof) { [weak self] in
                guard let self else { return }; if eof { if clientWriteClosed && upstreamWriteClosed { finish(state:.completed) } } else { receiveClientStream() }
            }
        }
    }
    private func receiveUpstream() {
        guard !finished, let upstream else { return }
        upstream.receive(minimumIncompleteLength:1,maximumLength:64*1024) { [weak self] data,context,complete,error in
            let eof = complete && context?.isFinal == true
            guard let self, !finished else { return }
            let bytes = data ?? Data(); record.receivedBytes += bytes.count
            if !bytes.isEmpty {
                refreshIdle(); sentControlResponse = true
                if !record.opaque {
                    record.responsePreview.append(bytes.prefix(max(0,ProxyWire.previewLimit-record.responsePreview.count)))
                    if let status = ProxyWire.responseStatus(record.responsePreview), status >= 200 || status == 101 { record.status = status }
                    if error == nil && record.status == 101 && wantsUpgrade && !readingClientStream {
                        record.state = .upgraded; emit(force:true)
                        let first = pendingUpgrade; pendingUpgrade = Data(); sendUpstream(first,eof:receivedClientEOF) { [weak self] in self?.startClientStream() }
                    }
                }
            }
            if let error { failTransfer(error, phase: "Empfang vom Ziel"); return }
            receivedUpstreamEOF = eof; emit()
            client.send(content:bytes.isEmpty ? nil : bytes,contentContext:eof ? .finalMessage : .defaultMessage,isComplete:true,completion:.contentProcessed { [weak self] error in
                guard let self, !finished else { return }; if let error { failTransfer(error, phase: "Senden an den Client"); return }
                if eof {
                    if record.opaque || record.state == .upgraded {
                        clientWriteClosed = true
                        if upstreamWriteClosed { finish(state:.completed) }
                    } else { finish(state:.completed) }
                } else { receiveUpstream() }
            })
        }
    }
    private func refreshIdle() {
        idleWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.reject(504,"Die Proxy-Verbindung hat innerhalb des Wartezeitlimits keine neuen Daten geliefert.") }
        idleWork = work; queue.asyncAfter(deadline:.now()+idleTimeout,execute:work)
    }
    private func reject(_ status:Int,_ message:String) {
        guard !finished, !rejecting else { return }
        rejecting = true
        idleWork?.cancel(); lifetimeWork?.cancel(); headerWork?.cancel()
        if sentControlResponse { finish(state:.failed,message:message); return }
        record.error = message; record.status = status; emit(force:true); sentControlResponse = true
        client.send(content:ProxyWire.errorResponse(status,message:message),completion:.contentProcessed { [weak self] _ in self?.finish(state:.failed,message:message) })
    }
    private func connectionStateFailed(_ error: NWError, phase: String) {
        guard !finished else { return }
        if [.forwarding, .tunnel, .upgraded].contains(record.state) {
            // A connected stream has outstanding receive/send callbacks. Let their
            // data/error/final-context completion decide the transfer outcome.
            var issues = record.connectionStateIssues ?? []
            if issues.count < 16 { issues.append(.init(phase: phase, errors: ErrorEvidence.capture(error))) }
            record.connectionStateIssues = issues
            emit(force: true)
        } else { failTransfer(error, phase: phase) }
    }
    private func failTransfer(_ error: NWError, phase: String) {
        guard !finished else { return }
        record.failurePhase = phase
        record.transportErrors = ErrorEvidence.capture(error)
        record.clientReadClosed = receivedClientEOF; record.clientWriteClosed = clientWriteClosed
        record.upstreamReadClosed = receivedUpstreamEOF; record.upstreamWriteClosed = upstreamWriteClosed
        finish(state: .failed, message: phase + ": " + error.localizedDescription)
    }
    private func finish(state:ProxyCapture.State,message:String? = nil) {
        guard !finished else { return }; finished = true
        record.state = state; record.error = message ?? record.error; emit(force:true)
        idleWork?.cancel(); lifetimeWork?.cancel(); headerWork?.cancel()
        client.stateUpdateHandler = nil; upstream?.stateUpdateHandler = nil
        client.cancel(); upstream?.cancel(); upstream = nil; input = Data(); pendingUpgrade = Data()
        closed(id)
    }
    private func emit(force:Bool = false) {
        let now = clock.now
        if !force, let lastProgress, lastProgress.duration(to:now) < .milliseconds(250) { return }
        lastProgress = now
        if let began { let duration = began.duration(to:now).components; record.duration = Double(duration.seconds)+Double(duration.attoseconds)/1e18 }
        record.revision += 1; event(.capture(record))
    }
}
