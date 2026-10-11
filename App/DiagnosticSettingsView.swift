import SwiftUI

struct DiagnosticSettingsView: View {
    let store: DiagnosticStore
    @Environment(\.dismiss) private var dismiss
    @State private var value = DiagnosticOptions.standard
    @State private var error: String?
    @FocusState private var editing: DiagnosticTimeoutField?
    var body: some View {
        Form {
            if let error { Section { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.red) } }
            DiagnosticTimeoutFields(requestTimeout: $value.requestTimeout, resourceTimeout: $value.resourceTimeout, focusedField: $editing)
            DiagnosticPreviewField(bytes: $value.bodyPreviewBytes)
            Section {
                Button("Standardwerte wiederherstellen", systemImage: "arrow.counterclockwise") { value = .standard; error = nil }
                Text("Die Werte gelten nach dem Speichern für neue Anfragen in Inspect und Requests. Die laufende Anfrage, der feste badssl-Referenztest und TLS-Versions-Probes verwenden ihre bisherigen Limits.").font(.footnote).foregroundStyle(.secondary)
                Text("Die Zertifikatsprüfung und Apples ATS-Schutz bleiben aktiv. Gespeicherte Verbindungen und Favoriten werden durch diesen Reset nicht gelöscht.").font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle("Diagnoseeinstellungen")
            .onAppear { value = store.diagnosticOptions }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Speichern") { editing = nil; do { try store.updateDiagnosticOptions(value); dismiss() } catch { self.error = error.localizedDescription } } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Fertig") { editing = nil } }
            }
    }
}
private enum DiagnosticTimeoutField: Hashable { case request, resource }
private struct DiagnosticTimeoutFields: View {
    @Binding var requestTimeout: Double
    @Binding var resourceTimeout: Double
    var focusedField: FocusState<DiagnosticTimeoutField?>.Binding
    var body: some View {
        Section("Zeitlimits · Sekunden") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Wartezeit ohne neue Daten").font(.subheadline)
                TextField("Sekunden", value: $requestTimeout, format: .number).keyboardType(.decimalPad).focused(focusedField, equals: .request).accessibilityLabel("Wartezeit ohne neue Daten · Sekunden")
            }
            Text("Maximal 300 Sekunden. Das System startet dieses Wartezeitlimit neu, wenn weitere Daten eintreffen.").font(.footnote).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                Text("Gesamte Anfrage").font(.subheadline)
                TextField("Sekunden", value: $resourceTimeout, format: .number).keyboardType(.decimalPad).focused(focusedField, equals: .resource).accessibilityLabel("Gesamte Anfrage · Sekunden")
            }
            Text("Maximal 3.600 Sekunden für die vollständige Übertragung, auch wenn laufend Daten eintreffen.").font(.footnote).foregroundStyle(.secondary)
        }
    }
}

struct DiagnosticOptionsSummary: View {
    let options: DiagnosticOptions
    var body: some View {
        Section("Verwendete Diagnoseeinstellungen") {
            LabeledContent("Wartezeitlimit", value: "\(options.requestTimeout.formatted()) s")
            LabeledContent("Gesamtzeitlimit", value: "\(options.resourceTimeout.formatted()) s")
            LabeledContent("Antwortvorschau", value: options.bodyPreviewBytes.formatted(.byteCount(style: .memory)))
        }
    }
}
private struct DiagnosticPreviewField: View {
    @Binding var bytes: Int
    var body: some View {
        Section("Antwortvorschau") {
            Picker("Gespeicherter Antworttext", selection: $bytes) {
                Text("Keine Vorschau").tag(0)
                Text("64 KiB").tag(64 * 1024)
                Text("256 KiB").tag(256 * 1024)
                Text("1 MiB").tag(1024 * 1024)
                Text("2 MiB · Standard").tag(2 * 1024 * 1024)
                Text("8 MiB").tag(8 * 1024 * 1024)
                Text("16 MiB").tag(16 * 1024 * 1024)
            }
            Text("Nur die Vorschau wird begrenzt. Bytezahl und SHA-256 beziehen sich weiterhin auf die vollständige empfangene Antwort. Eine kleinere Vorschau reduziert den gespeicherten Inhalt.").font(.footnote).foregroundStyle(.secondary)
        }
    }
}
