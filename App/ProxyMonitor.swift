import Foundation
import Network
import Observation

@MainActor @Observable final class ProxyMonitor {
    var port: UInt16?
    var starting = false
    var error: String?
    var captures: [ProxyCapture] = []
    var testing = false
    var testRecord: DiagnosticRecord?
    private var engine: LocalHTTPProxy?
    private var generation = UUID()
    var running: Bool { starting || port != nil }
    func start(port: UInt16) {
        guard !running else { return }
        let generation = UUID(); self.generation = generation
        starting = true; error = nil
        let engine = LocalHTTPProxy { [weak self] event in
            Task { @MainActor [weak self] in
                guard let self, self.generation == generation else { return }
                switch event {
                case .listening(let port): self.port = port; self.starting = false
                case .failed(let message): self.error = message; self.port = nil; self.starting = false
                case .stopped: self.port = nil; self.starting = false
                case .capture(let capture):
                    if let index = self.captures.firstIndex(where: { $0.id == capture.id }) {
                        if capture.revision >= self.captures[index].revision { self.captures[index] = capture }
                    } else { self.captures.insert(capture,at:0) }
                    let active = self.captures.filter(\.active)
                    self.captures = (active + self.captures.filter { !$0.active }.prefix(200)).sorted { $0.date > $1.date }
                }
            }
        }
        self.engine = engine; engine.start(port:port)
    }
    func stop(reason: String = "Proxy gestoppt") { engine?.stop(reason:reason); engine = nil }
    func check(_ target: String, options: DiagnosticOptions) async {
        guard let port, !testing else { return }
        testing = true; defer { testing = false }
        do {
            let url = try Endpoint.parse(target)
            let request = URLRequest(url:url)
            let configuration = URLSessionConfiguration.ephemeral
            var proxy = ProxyConfiguration(httpCONNECTProxy:.hostPort(host:"127.0.0.1",port:NWEndpoint.Port(rawValue:port)!))
            proxy.allowFailover = false
            configuration.proxyConfigurations = [proxy]
            testRecord = await DiagnosticEngine(request:request,options:options).run(request,configuration:configuration)
        } catch { self.error = error.localizedDescription }
    }
}
