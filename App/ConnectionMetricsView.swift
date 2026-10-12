import SwiftUI

struct ConnectionMetricsView: View {
    private struct Step: Identifiable {
        let id: String
        let ordinal: Int
        let value: ConnectionMetrics.Transaction
    }
    let record: DiagnosticRecord
    private let steps: [Step]
    init(record: DiagnosticRecord) {
        self.record = record
        steps = (record.connectionMetrics?.transactions ?? []).enumerated().map { Step(id:"\(record.id)-\($0.offset)",ordinal:$0.offset+1,value:$0.element) }
    }
    var body: some View {
        List {
            if let metrics = record.connectionMetrics {
                Section {
                    Label("Verbindungsweg",systemImage:"point.3.connected.trianglepath.dotted").font(.headline).foregroundStyle(Color.diagnosticAccent)
                    LabeledContent("Weiterleitungen",value:metrics.redirectCount.formatted())
                    LabeledContent("Gemeldete Transaktionen",value:metrics.transactionCount.formatted())
                    LabeledContent("Transportdauer",value:seconds(metrics.duration))
                    if record.origin != nil { Text("Aus dem importierten Bericht übernommen; keine neue Messung auf diesem Gerät.").font(.footnote).foregroundStyle(.secondary) }
                    if metrics.transactionsTruncated { Text("Die Anzeige enthält höchstens 128 Transaktionen. Weitere Schritte wurden nicht gespeichert.").font(.footnote).foregroundStyle(.secondary) }
                }
                ForEach(steps) { step in
                    Section("Verbindung \(step.ordinal)") {
                        Text(step.value.url ?? "Ziel nicht gemeldet").font(.callout.monospaced()).textSelection(.enabled)
                        if let status = step.value.status { LabeledContent("HTTP",value:status.formatted(.number.grouping(.never))) }
                        if let protocolName = step.value.protocolName { LabeledContent("Protokoll",value:protocolName) }
                        if let address = step.value.remoteAddress { LabeledContent("Serveradresse",value:address).textSelection(.enabled) }
                        if let tls = step.value.tlsProtocol { LabeledContent("TLS",value:TLSDisplay.version(tls)) }
                        if let cipher = step.value.tlsCipher { LabeledContent("Cipher",value:TLSDisplay.cipher(cipher)) }
                        if step.value.reusedConnection { Label("Bestehende Verbindung wiederverwendet",systemImage:"arrow.triangle.2.circlepath") }
                        if step.value.proxyConnection { Label("Über einen Proxy",systemImage:"network") }
                        phase("DNS",step.value.dnsDuration)
                        phase("TCP-Verbindung",step.value.connectDuration)
                        phase("TLS-Handshake",step.value.tlsDuration)
                        phase("Senden",step.value.sendDuration)
                        phase("Warten auf Antwort",step.value.waitDuration)
                        phase("Empfangen",step.value.receiveDuration)
                    }
                }
                Section {
                    Text("Fehlende Phasen bleiben unbekannt, etwa bei wiederverwendeten Verbindungen. TCP- und TLS-Zeiten können sich überlappen und werden nicht addiert.").font(.footnote).foregroundStyle(.secondary)
                    Text("Die Zertifikatsansicht gehört zur zuletzt ausgewerteten Kette. Für Zwischenziele ist hier keine eigenständige Vertrauensentscheidung ausgewiesen.").font(.footnote).foregroundStyle(.secondary)
                }
            } else { Text("Keine einzelnen Verbindungsmetriken in diesem Bericht vorhanden.") }
        }.navigationTitle("Verbindungsweg").navigationBarTitleDisplayMode(.inline)
    }
    @ViewBuilder private func phase(_ title: String, _ value: Double?) -> some View {
        if let value, value >= 0, value.isFinite { LabeledContent(title,value:seconds(value)) }
    }
    private func seconds(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(3))) + " s" }
}
