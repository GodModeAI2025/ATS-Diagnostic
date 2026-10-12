import Foundation
import Observation

@MainActor @Observable final class DiagnosticStore {
    var records: [DiagnosticRecord] = []
    var latest: DiagnosticRecord?
    var settings = RecordingSettings()
    var diagnosticOptions = DiagnosticOptions.standard
    var running = false
    var error: String?
    private let persistence = HistoryPersistence(file: URL.documentsDirectory.appendingPathComponent("diagnostics.json"))
    private var persistenceRevision: UInt64 = 0
    private var file: URL {
        URL.documentsDirectory.appendingPathComponent("diagnostics.json")
    }
    private var settingsFile: URL { URL.documentsDirectory.appendingPathComponent("recording-settings.json") }
    private var optionsFile: URL { URL.documentsDirectory.appendingPathComponent("diagnostic-options.json") }
    init() {
        if let data = try? Data(contentsOf: optionsFile), let value = try? JSONDecoder().decode(DiagnosticOptions.self, from: data) { diagnosticOptions = value.validated }
        if let data = try? Data(contentsOf: settingsFile), let decoded = try? JSONDecoder().decode(RecordingSettings.self, from: data) { settings = decoded }
        do { records = try HistoryRetention.retain(JSONDecoder().decode([DiagnosticRecord].self, from: Data(contentsOf: file)), countLimit: settings.recordLimit) }
        catch { records = [] }
    }
    func execute(url: String, method: String = "GET", headers: String = "", body: String = "", expectedSHA256: String = "") async {
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
    func importHAR(_ data: Data) throws {
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
    func clear() { records = []; save() }
    private func save() {
        persistenceRevision += 1
        let revision = persistenceRevision
        let snapshot = records
        Task { [weak self, persistence] in
            do { try await persistence.save(snapshot, revision: revision) }
            catch {
                guard let self, self.persistenceRevision == revision else { return }
                self.error = error.localizedDescription
            }
        }
    }
    enum HeaderError: LocalizedError { case invalid; var errorDescription: String? { "Enter headers as Name: Value, one per line." } }
}
