import Foundation
import Network
import Observation

@MainActor @Observable final class ProxyMonitor {
    private let rulePersistence: ProxyRulePersistence
    private var rulesLoadTask: Task<Void, Never>?
    private var rulesSaveTask: Task<Void, Never>?
    private var pendingRules: (revision: UInt64, rules: [ProxyRuleConfiguration])?
    private var rulesRevision: UInt64 = 0
    private(set) var rulesLoading = true
    private(set) var rulesLoadFailed = false
    private(set) var rulesPersistenceError: String?
    init(persistence: ProxyRulePersistence? = nil) {
        rulePersistence = persistence ?? ProxyRulePersistence(file: URL.applicationSupportDirectory.appendingPathComponent("ATS-Proxy-Rules.json"))
        rulesLoadTask = Task { [weak self] in await self?.readRules() }
    }
    func loadRules() async { await rulesLoadTask?.value }
    func retryLoadingRules() {
        guard !running, !rulesLoading else { return }
        rulesLoading = true
        rulesLoadTask = Task { [weak self] in await self?.readRules() }
    }
    private func readRules() async {
        defer { rulesLoading = false }
        do {
            rewriteConfigurations = try await rulePersistence.load()
            rulesLoadFailed = false; rulesPersistenceError = nil
        } catch {
            rulesLoadFailed = true; rulesPersistenceError = "Proxy-Regeln konnten nicht geladen werden: " + error.localizedDescription
        }
    }
    private func persistRules() {
        rulesRevision &+= 1
        pendingRules = (rulesRevision, rewriteConfigurations)
        guard rulesSaveTask == nil else { return }
        let lease = BackgroundWriteLease(); lease.begin(name: "Save proxy rules")
        rulesSaveTask = Task { [self] in
            defer { lease.end(); rulesSaveTask = nil }
            while let snapshot = pendingRules {
                pendingRules = nil
                do {
                    _ = try await rulePersistence.save(snapshot.rules, revision: snapshot.revision)
                    if snapshot.revision == rulesRevision { rulesPersistenceError = nil }
                } catch {
                    if snapshot.revision == rulesRevision { rulesPersistenceError = "Proxy-Regeln konnten nicht gespeichert werden: " + error.localizedDescription }
                }
            }
        }
    }
    func flushRules() async { await rulesLoadTask?.value; await rulesSaveTask?.value }
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
        case running, limit, loading
        var errorDescription: String? {
            switch self {
            case .loading: "Die Proxy-Regeln sind noch nicht verfügbar. Warte auf das Laden oder versuche es erneut."
            case .running: "Stoppe den Proxy, bevor du Regeln änderst."
            case .limit: "Es können höchstens 64 Regeln konfiguriert werden."
            }
        }
    }
    func saveRewriteConfiguration(_ value: ProxyRuleConfiguration) throws {
        guard !rulesLoading, !rulesLoadFailed else { throw RuleEditError.loading }
        guard !running else { throw RuleEditError.running }
        _ = try value.rule()
        if let index = rewriteConfigurations.firstIndex(where: { $0.id == value.id }) { rewriteConfigurations[index] = value }
        else {
            guard rewriteConfigurations.count < 64 else { throw RuleEditError.limit }
            rewriteConfigurations.append(value)
        }
        persistRules()
    }
    func removeRewriteConfigurations(at offsets: IndexSet) {
        guard !running, !rulesLoading, !rulesLoadFailed else { return }
        for index in offsets.sorted(by: >) where rewriteConfigurations.indices.contains(index) { rewriteConfigurations.remove(at: index) }
        persistRules()
    }
    func moveRewriteConfigurations(from offsets: IndexSet, to destination: Int) {
        guard !running, !rulesLoading, !rulesLoadFailed, (0...rewriteConfigurations.count).contains(destination), offsets.allSatisfy({ rewriteConfigurations.indices.contains($0) }) else { return }
        let selected = offsets.sorted().map { rewriteConfigurations[$0] }
        let remaining = rewriteConfigurations.enumerated().filter { !offsets.contains($0.offset) }.map(\.element)
        let insertion = destination - offsets.filter { $0 < destination }.count
        rewriteConfigurations = Array(remaining.prefix(insertion)) + selected + Array(remaining.dropFirst(insertion))
        persistRules()
    }
    func start(port: UInt16) {
        guard !running else { return }
        guard !rulesLoading, !rulesLoadFailed else { error = RuleEditError.loading.localizedDescription; return }
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
