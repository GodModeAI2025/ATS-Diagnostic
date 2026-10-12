import SwiftUI
import UIKit

struct QueryParameterLinks: View {
    let requestedURL: String
    let finalURL: String?
    var body: some View {
        Section {
            NavigationLink { QueryParametersView(url: requestedURL) } label: {
                Label("URL-Parameter", systemImage: "list.bullet.rectangle")
            }
            if let finalURL, finalURL != requestedURL {
                NavigationLink { QueryParametersView(url: finalURL) } label: {
                    Label("Parameter des endgültigen Ziels", systemImage: "arrow.turn.down.right")
                }
            }
        }
    }
}

struct QueryParametersView: View {
    let url: String
    private let displayURL: String
    private let truncatedURL: Bool
    private let details: URLQueryDetails
    init(url: String) {
        self.url = url
        let prefix = url.prefix(4096)
        displayURL = String(prefix); truncatedURL = prefix.endIndex != url.endIndex
        details = URLQueryDetails(url: url)
    }
    var body: some View {
        List {
            Section("URL") {
                Text(displayURL).font(.footnote.monospaced()).textSelection(.enabled)
                if truncatedURL { Text("Die Anzeige ist gekürzt. Kopieren enthält die vollständige Original-URL.").font(.footnote).foregroundStyle(.secondary) }
                Button("Original-URL kopieren", systemImage: "doc.on.doc") { UIPasteboard.general.string = url }
            }
            if details.oversized {
                Section {
                    Label("Abfrage zu groß für die Detailansicht", systemImage: "text.badge.xmark")
                    Text("Die Abfrage enthält \(details.queryBytes.formatted(.byteCount(style: .file))). Bis 64 KiB werden einzeln dargestellt. Die Original-URL bleibt vollständig erhalten.").font(.footnote).foregroundStyle(.secondary)
                }
            } else if details.parameters.isEmpty {
                Section {
                    Label("Keine Query-Parameter", systemImage: "list.bullet.rectangle")
                    if details.hasQuery { Text("Die Abfrage nach dem Fragezeichen ist leer.").foregroundStyle(.secondary) }
                    else { Text("Diese URL enthält keine Abfrage.").foregroundStyle(.secondary) }
                }
            } else {
                Section("Parameter") {
                    ForEach(details.parameters) { QueryParameterRow(parameter: $0) }
                }
                if let count = details.parameterCount, count > details.parameters.count {
                    Section { Text("\(details.parameters.count) von \(count) Parametern dargestellt. Die vollständige Abfrage steht in der Original-URL.").font(.footnote).foregroundStyle(.secondary) }
                }
            }
            Section {
                Text("Gleiche Namen bleiben als einzelne Parameter erhalten. Pluszeichen bleiben „+“. Prozent-Codierung wird einmal dekodiert; Steuerzeichen werden sichtbar maskiert; Backslashes erscheinen verdoppelt.").font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle("URL-Parameter").navigationBarTitleDisplayMode(.inline)
    }
}

private struct QueryParameterRow: View {
    let parameter: URLQueryParameter
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if parameter.rawName.isEmpty { Text("Leerer Name").font(.headline).foregroundStyle(.secondary) }
            else { Text(URLQueryDetails.visibleText(parameter.name ?? parameter.rawName)).font(.headline).textSelection(.enabled) }
            if parameter.rawValue == nil { Text("Kein Wert zugewiesen").foregroundStyle(.secondary) }
            else if parameter.rawValue == "" { Text("Leerer Wert").foregroundStyle(.secondary) }
            else { Text(URLQueryDetails.visibleText(parameter.value ?? parameter.rawValue ?? "")).textSelection(.enabled) }
            if parameter.name == nil || (parameter.rawValue != nil && parameter.value == nil) {
                Label("Ungültige Prozent-Codierung oder UTF-8", systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(.secondary)
            }
            DisclosureGroup("Originale Codierung") {
                Text(parameter.id.rawSegment.isEmpty ? "(leerer Abschnitt)" : URLQueryDetails.visibleText(parameter.id.rawSegment))
                    .font(.footnote.monospaced()).textSelection(.enabled)
            }.font(.footnote)
        }.padding(.vertical, 4)
    }
}
