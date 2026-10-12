import Foundation
import Observation

@MainActor @Observable final class DiagnosticStore {
    var records: [DiagnosticRecord] = []
    var latest: DiagnosticRecord?
    var settings = RecordingSettings()
    var diagnosticOptions = DiagnosticOptions.standard
    private(set) var loadingHistory = true
    var running = false
    var error: String?
    @ObservationIgnored private let persistence: HistoryPersistence
    @ObservationIgnored private var persistenceRevision: UInt64 = 0
    @ObservationIgnored private var pendingPersistence: (records: [DiagnosticRecord], revision: UInt64)?
    @ObservationIgnored private var persistenceTask: Task<Void, Never>?
    @ObservationIgnored private var loadingTask: Task<Void, Never>?
    private var settingsFile: URL { URL.documentsDirectory.appendingPathComponent("recording-settings.json") }
    private var optionsFile: URL { URL.documentsDirectory.appendingPathComponent("diagnostic-options.json") }
    init(historyFile: URL = URL.documentsDirectory.appendingPathComponent("diagnostics.json")) {
        persistence = HistoryPersistence(file: historyFile)
        if let data = try? Data(contentsOf: optionsFile), let value = try? JSONDecoder().decode(DiagnosticOptions.self, from: data) { diagnosticOptions = value.validated }
        if let data = try? Data(contentsOf: settingsFile), let decoded = try? JSONDecoder().decode(RecordingSettings.self, from: data) { settings = decoded }
        let countLimit = settings.recordLimit
        loadingTask = Task { [weak self, persistence] in
            let loaded = (try? await persistence.load(countLimit: countLimit)) ?? []
            guard let self else { return }
            self.records = loaded
            self.loadingHistory = false
            self.loadingTask = nil
        }
    }
    func loadHistory() async { await loadingTask?.value }
    func execute(url: String, method: String = "GET", headers: String = "", body: String = "", expectedSHA256: String = "") async {
        await loadHistory()
        guard !running else { return }
        do {
            let checksum = try Integrity.normalizeSHA256(expectedSHA256)
            let endpoint = try Endpoint.parse(url)
            var request = URLRequest(url: endpoint)
            request.httpMethod = method
            if !body.isEmpty { request.httpBody = Data(body.utf8) }
            for line in headers.split(separator: "\n") {
                guard let colon = line.firstIndex(of: ":") else { throw HeaderError.invalid }
                let name = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { throw HeaderError.invalid }
                request.setValue(String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces), forHTTPHeaderField: name)
            }
            running = true
            error = nil
            let record = await DiagnosticEngine(request: request, expectedSHA256: checksum, options: diagnosticOptions).run(request)
            latest = record
            if settings.enabled && settings.accepts(record.url) {
                records = try HistoryRetention.retain([record] + records, countLimit: settings.recordLimit)
                save()
            }
            running = false
        } catch { running = false; self.error = error.localizedDescription }
    }
    func importHAR(_ data: Data) async throws {
        await loadHistory()
        guard data.count <= 20 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
        let imported = try HARArchive.importRecords(data)
        records = try HistoryRetention.retain(imported + records, countLimit: settings.recordLimit)
        save()
    }
    func updateDiagnosticOptions(_ value: DiagnosticOptions) throws {
        try value.validate()
        try JSONEncoder().encode(value).write(to: optionsFile, options: [.atomic, .completeFileProtection])
        diagnosticOptions = value
    }
    func updateSettings(_ value: RecordingSettings) throws {
        try value.validate()
        settings = value
        try JSONEncoder().encode(value).write(to: settingsFile, options: [.atomic, .completeFileProtection])
    }
    func toggleFavorite(_ id: UUID) {
        var value = settings
        if value.favorites.contains(id) { value.favorites.remove(id) } else { value.favorites.insert(id) }
        do { try updateSettings(value) } catch { self.error = error.localizedDescription }
    }
    func clear() async { await loadHistory(); records = []; save() }
    func flushHistory() async { await loadHistory(); await persistenceTask?.value }
    private func save() {
        persistenceRevision += 1
        pendingPersistence = (records, persistenceRevision)
        guard persistenceTask == nil else { return }
        let lease = BackgroundWriteLease()
        lease.begin()
        persistenceTask = Task { [weak self, persistence] in
            defer { lease.end() }
            while let self, let pending = self.pendingPersistence {
                self.pendingPersistence = nil
                do { try await persistence.save(pending.records, revision: pending.revision) }
                catch {
                    if self.persistenceRevision == pending.revision { self.error = error.localizedDescription }
                }
            }
            self?.persistenceTask = nil
        }
    }
    enum HeaderError: LocalizedError { case invalid; var errorDescription: String? { "Enter headers as Name: Value, one per line." } }
}
