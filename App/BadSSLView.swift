import SwiftUI

struct BadSSLView: View {
    let store: DiagnosticStore
    @State private var suite = BadSSLSuite()
    var body: some View {
        List {
            Section { BadSSLRunControls(suite:suite) }
            Section("Ergebnisse · \(suite.results.count)/\(BadSSLCase.catalog.count)") {
                ForEach(suite.results) { result in NavigationLink { BadSSLResultView(result:result,store:store) } label: { BadSSLResultRow(result:result) } }
                if suite.results.isEmpty { Text("Der Durchlauf prüft alle aktuellen badssl-Ziele, einschließlich der als defunct markierten Fälle. Browser-Verhalten wird getrennt eingeordnet.").font(.subheadline).foregroundStyle(.secondary) }
            }
        }.navigationTitle("badssl-Testkatalog").navigationBarTitleDisplayMode(.inline)
        .toolbar { if !suite.results.isEmpty { ShareLink("Bericht teilen",item:suite.report) } }
        .task { suite.loadLastRun() }
    }
}
private struct BadSSLRunControls: View {
    let suite: BadSSLSuite
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            HStack(alignment:.top,spacing:12) { SupportingIllustration(kind:.certificate);Text("Kontrollierter Test mit \(BadSSLCase.catalog.count) Zielen").font(.headline) }
            Text("Die Ziele enthalten absichtlich fehlerhafte Zertifikate und alte Verfahren. Die App behält Systemvertrauen und ATS bei. Eine empfangene HTTP-Antwort ist kein pauschales Sicherheitsurteil.").font(.subheadline).foregroundStyle(.secondary)
            if suite.running {
                ProgressView(value:Double(suite.results.count),total:Double(BadSSLCase.catalog.count))
                Text(suite.current).font(.caption).foregroundStyle(.secondary)
                Button("Nach laufenden Anfragen stoppen",role:.destructive) { suite.cancelled = true }
            } else {
                Button("Alle Fälle prüfen",systemImage:"play") { Task { await suite.run() } }.buttonStyle(.borderedProminent).controlSize(.large)
                if let finished = suite.finished { Text("Letzter Durchlauf: \(finished.formatted(date:.abbreviated,time:.shortened))").font(.caption).foregroundStyle(.secondary) }
            }
        }.padding(.vertical,6)
    }
}
private struct BadSSLResultRow: View {
    let result: BadSSLResult
    var body: some View {
        HStack(alignment:.top,spacing:12) {
            Image(systemName:DiagnosticFailure.explain(result.record) == nil ? "arrow.down.doc" : "exclamationmark.shield").foregroundStyle(DiagnosticFailure.explain(result.record) == nil ? Color.diagnosticAccent : Color.orange)
            VStack(alignment:.leading,spacing:6) { Text(result.test.name).font(.subheadline.weight(.semibold));Text(result.summary).font(.subheadline).foregroundStyle(Color(uiColor:.secondaryLabel));Text(result.test.category).font(.caption).foregroundStyle(Color(uiColor:.secondaryLabel)) }
        }.padding(.vertical,4)
    }
}
private struct BadSSLResultView: View {
    let result: BadSSLResult
    let store: DiagnosticStore
    var body: some View {
        List {
            Section("Beobachtetes Ergebnis") {
                Text(result.test.url).font(.callout.monospaced()).textSelection(.enabled)
                Text(result.verdict).font(.headline)
                LabeledContent("HTTP-Status",value:result.record.status.map(String.init) ?? "Keine HTTP-Antwort")
                if DiagnosticFailure.explain(result.record) != nil { DiagnosticIssueView(record:result.record) }
                else { LabeledContent("TLS",value:TLSDisplay.version(result.record.tlsVersion));Text("Die Anfrage wurde vom System akzeptiert. Das bestätigt nur diesen Verbindungsversuch.").font(.subheadline).foregroundStyle(.secondary) }
            }
            Section("Grenzen und Einordnung") { ForEach(result.observations,id:\.self) { Text($0).font(.subheadline).foregroundStyle(.secondary) } }
            Section { NavigationLink("Verbindung und Zertifikate öffnen") { RecordView(record:result.record,store:store) } }
        }.navigationTitle(result.test.name).navigationBarTitleDisplayMode(.inline)
    }
}
