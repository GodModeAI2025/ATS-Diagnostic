import Foundation
import Observation

@MainActor @Observable final class DiagnosticStore {
    var records: [DiagnosticRecord] = []
    var running = false
    var error: String?
    private var file: URL {
        URL.documentsDirectory.appendingPathComponent("diagnostics.json")
    }
    init() {
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
            records.insert(record, at: 0)
            records = Array(records.prefix(200))
            save()
            running = false
        } catch { self.error = error.localizedDescription }
    }
    func importHAR(_ data: Data) throws {
        guard data.count <= 20 * 1024 * 1024 else { throw CocoaError(.fileReadTooLarge) }
        let archive = try JSONDecoder().decode(HARArchive.self, from: data)
        records = Array((archive.records() + records).prefix(200))
        save()
    }
    func clear() { records = []; save() }
    private func save() {
        do { try JSONEncoder().encode(records).write(to: file, options: [.atomic, .completeFileProtection]) }
        catch { self.error = error.localizedDescription }
    }
    enum HeaderError: LocalizedError { case invalid; var errorDescription: String? { "Enter headers as Name: Value, one per line." } }
}
