import SwiftUI

struct HSTSPolicyView: View {
    let record: DiagnosticRecord
    private var fields: [String] { record.responseHeaders.filter { $0.key.lowercased() == "strict-transport-security" }.map(\.value) }
    var body: some View {
        List {
            Section {
                Label("HTTPS für zukünftige Besuche", systemImage: "shield.lefthalf.filled").font(.headline).foregroundStyle(Color.diagnosticAccent)
                Text("HSTS fordert unterstützende Browser auf, diesen Host nur über HTTPS zu besuchen. Die Auswertung betrifft die beobachtete Antwort, nicht den gespeicherten Browserzustand.").font(.subheadline)
                Text(record.finalURL ?? record.url).font(.footnote.monospaced()).textSelection(.enabled)
            }
            Section("Beobachtete Richtlinie") {
                if record.status == nil {
                    Text("Keine HTTP-Antwort erfasst. HSTS kann nicht bewertet werden.")
                } else if fields.count > 1 {
                    Text("Mehrere HSTS-Felder erfasst. Ihre Reihenfolge ist in diesem Bericht nicht erhalten; keine eindeutige Auswertung möglich.")
                } else {
                    switch HSTSPolicy.parse(fields.first) {
                    case .missing:
                        Label("Kein HSTS-Header beobachtet", systemImage: "questionmark.circle")
                        Text("Das beweist weder einen TLS-Fehler noch das Fehlen einer früher gespeicherten oder vorgeladenen Richtlinie.")
                    case .invalid:
                        Label("HSTS-Angabe ungültig", systemImage: "exclamationmark.triangle")
                        Text("max-age muss eine nicht negative Ganzzahl sein. Doppelte Direktiven oder fehlerhafte Werte verhindern eine gültige Auswertung. Serverkonfiguration prüfen.")
                    case .policy(let policy):
                        Label(policy.disablesPolicy ? "Löschung der gespeicherten Richtlinie angefordert" : "HSTS-Richtlinie angegeben", systemImage: "doc.text")
                        LabeledContent("max-age · Sekunden", value: policy.maxAgeSeconds)
                        LabeledContent("Subdomains einbezogen", value: policy.includesSubdomains ? "Ja" : "Nein")
                        if policy.preloadRequested { Text("preload-Direktive vorhanden. Ein tatsächlicher Eintrag in Browser-Preload-Listen wurde nicht geprüft.") }
                    }
                }
                if URL(string: record.finalURL ?? record.url)?.scheme?.lowercased() != "https" {
                    Text("Über HTTP empfangene HSTS-Angaben dürfen keine HSTS-Richtlinie setzen.").foregroundStyle(.secondary)
                } else if record.origin != nil {
                    Text("Importierter Bericht: Transportvertrauen und Browserwirkung sind hier nicht unabhängig bestätigt.").foregroundStyle(.secondary)
                }
            }
            if let raw = fields.first { Section("Originalwert") { Text(raw).font(.callout.monospaced()).textSelection(.enabled) } }
            Section { Link("HSTS-Spezifikation · RFC 6797", destination: URL(string: "https://www.rfc-editor.org/rfc/rfc6797.html")!) }
        }.navigationTitle("HSTS").navigationBarTitleDisplayMode(.inline)
    }
}
