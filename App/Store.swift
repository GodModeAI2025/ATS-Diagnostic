import Foundation
import Observation

@MainActor @Observable final class DiagnosticStore {
    var records: [DiagnosticRecord] = []
    var latest: DiagnosticRecord?
    var settings = RecordingSettings()
    var running = false
    var error: String?
    private var file: URL {
        URL.documentsDirectory.appendingPathComponent("diagnostics.json")
    }
    private var settingsFile: URL { URL.documentsDirectory.appendingPathComponent("recording-settings.json") }
    init() {
        if let data = try? Data(contentsOf: settingsFile), let decoded = try? JSONDecoder().decode(RecordingSettings.self, from: data) { settings = decoded }
        do { records = try JSONDecoder().decode([DiagnosticRecord].self, from: Data(contentsOf: file)) }
        catch { records = [] }
    }
    func execute(url: String, method: String = "GET", headers: String = "", body: String = "") async {
        guard !running else { return }
        do {
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
            let record = await DiagnosticEngine(request: request).run(request)
            latest = record
            if settings.enabled && settings.accepts(record.url) {
                records.insert(record, at: 0)
                records = Array(records.prefix(settings.recordLimit))
                save()
            }
            running = false
        } catch { self.error = error.localizedDescription }
    }
    func importHAR(_ data: Data) throws {
        guard data.count <= 20 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
        let archive = try JSONDecoder().decode(HARArchive.self, from: data)
        records = Array((archive.records() + records).prefix(200))
        save()
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
        do { try JSONEncoder().encode(records).write(to: file, options: [.atomic, .completeFileProtection]) }
        catch { self.error = error.localizedDescription }
    }
    enum HeaderError: LocalizedError { case invalid; var errorDescription: String? { "Enter headers as Name: Value, one per line." } }
}
