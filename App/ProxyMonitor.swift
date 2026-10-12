import Foundation
import Network
import Observation

@MainActor @Observable final class ProxyMonitor {
    var port: UInt16?
    var starting = false
    var error: String?
    private(set) var rewriteConfigurations: [ProxyRuleConfiguration] = []
    var captures: [ProxyCapture] = []
    var testing = false
    var testRecord: DiagnosticRecord?
    private var engine: LocalHTTPProxy?
    private var generation = UUID()
    var running: Bool { starting || port != nil }
    enum RuleEditError: LocalizedError {
        case running, limit
        var errorDescription: String? {
            switch self {
            case .running: "Stoppe den Proxy, bevor du Regeln änderst."
            case .limit: "Es können höchstens 64 Regeln konfiguriert werden."
            }
        }
    }
    func saveRewriteConfiguration(_ value: ProxyRuleConfiguration) throws {
        guard !running else { throw RuleEditError.running }
        _ = try value.rule()
        if let index = rewriteConfigurations.firstIndex(where: { $0.id == value.id }) { rewriteConfigurations[index] = value }
        else {
            guard rewriteConfigurations.count < 64 else { throw RuleEditError.limit }
            rewriteConfigurations.append(value)
        }
    }
    func removeRewriteConfigurations(at offsets: IndexSet) {
        guard !running else { return }
        for index in offsets.sorted(by: >) where rewriteConfigurations.indices.contains(index) { rewriteConfigurations.remove(at: index) }
    }
    func moveRewriteConfigurations(from offsets: IndexSet, to destination: Int) {
        guard !running, (0...rewriteConfigurations.count).contains(destination), offsets.allSatisfy({ rewriteConfigurations.indices.contains($0) }) else { return }
        let selected = offsets.sorted().map { rewriteConfigurations[$0] }
        let remaining = rewriteConfigurations.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
        let insertion = destination - offsets.filter { $0 < destination }.count
        rewriteConfigurations = Array(remaining.prefix(insertion)) + selected + Array(remaining.dropFirst(insertion))
    }
    func start(port: UInt16) {
        guard !running else { return }
        let rules: [HTTPProxyRewriteRule]
        do { rules = try rewriteConfigurations.filter(\.enabled).map { try $0.rule() } }
        catch { self.error = error.localizedDescription; return }
        let generation = UUID(); self.generation = generation
        starting = true; error = nil
        let engine = LocalHTTPProxy(rewriteRules: rules) { [weak self] event in
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
