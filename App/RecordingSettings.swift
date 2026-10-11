import Foundation

struct RecordingSettings: Codable, Equatable {
    var enabled = true
    var recordLimit = 200
    var excludedURLPatterns = ""
    var favorites: Set<UUID> = []
    func accepts(_ url: String) -> Bool {
        excludedURLPatterns.split(separator: "\n").allSatisfy { pattern in
            url.range(of: String(pattern), options: .regularExpression) == nil
        }
    }
    func validate() throws {
        for pattern in excludedURLPatterns.split(separator: "\n") { _ = try NSRegularExpression(pattern: String(pattern)) }
    }
}
enum ResponseCategory: String, CaseIterable, Identifiable {
    case all = "All", json = "JSON", xml = "XML", html = "HTML", image = "Image", other = "Other"
    var id: String { rawValue }
    func matches(_ record: DiagnosticRecord) -> Bool {
        if self == .all { return true }
        let mime = record.responseHeaders.first { $0.key.lowercased() == "content-type" }?.value.lowercased() ?? ""
        let type: ResponseCategory = mime.contains("json") ? .json : mime.contains("xml") ? .xml : mime.contains("html") ? .html : mime.hasPrefix("image/") ? .image : .other
        return self == type
    }
}
struct TrafficStatistics {
    let count: Int
    let bytes: Int
    let averageDuration: Double
    let failures: Int
    init(_ records: [DiagnosticRecord]) {
        count = records.count
        bytes = records.reduce(0) { $0 + $1.bytes }
        averageDuration = records.isEmpty ? 0 : records.reduce(0) { $0 + $1.duration } / Double(records.count)
        failures = records.filter { $0.error != nil || ($0.status ?? 0) >= 400 }.count
    }
}

import SwiftUI
struct RecordingSettingsView: View {
    let store: DiagnosticStore
    @Environment(\.dismiss) private var dismiss
    @State private var value = RecordingSettings()
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Local recording") {
                    Toggle("Save request history", isOn: $value.enabled)
                    Stepper("Keep up to \(value.recordLimit) requests", value: $value.recordLimit, in: 10...1000, step: 10)
                    Text("Turning recording off keeps existing history. New requests remain visible until the app closes, without being saved.").font(.footnote)
                }
                Section("Exclude URLs · regular expressions") {
                    TextEditor(text: $value.excludedURLPatterns).font(.body.monospaced()).frame(minHeight: 120).accessibilityLabel("Excluded URL patterns")
                    Text("One pattern per line. Matching URLs are excluded from saved history.").font(.footnote)
                }
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("Recording settings").onAppear { value = store.settings }
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { do { try store.updateSettings(value); dismiss() } catch { self.error = error.localizedDescription } } } }
        }
    }
}
