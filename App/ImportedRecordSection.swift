import SwiftUI

struct ImportedRecordSection: View {
    let origin: DiagnosticRecordOrigin
    let requestBodyUnavailable: Bool
    let requestPreview: Data?
    let requestBytes: Int?
    var body: some View {
        Section {
            Label("Importierte Aufzeichnung", systemImage: "square.and.arrow.down").font(.headline)
            if origin == .developerSDK { Text("Vom Export gemeldete Quelle: ATSRecording.").font(.subheadline) }
            Text("Die Angaben stammen aus der importierten Datei. Diese Verbindung wurde durch den Import nicht erneut geprüft.").font(.footnote).foregroundStyle(.secondary)
            if requestBodyUnavailable {
                Text("Der ursprüngliche Anfragekörper ist nicht vollständig für eine Wiederholung verfügbar. Wiederholung und cURL-Ausgabe sind deaktiviert.").font(.footnote)
                LabeledContent("Ursprünglicher Anfragekörper", value: requestBytes.map { $0.formatted(.byteCount(style: .file)) } ?? "Nicht gemeldet")
                if let preview = requestPreview, !preview.isEmpty {
                    let text = String(data: preview, encoding: .utf8) ?? preview.base64EncodedString()
                    NavigationLink("Importierte Anfragevorschau") { TextValueView(title: "Anfragevorschau aus dem Import", value: text) }
                }
            }
        }
    }
}
