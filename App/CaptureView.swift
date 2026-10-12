import SwiftUI
import UniformTypeIdentifiers

private struct ProxyCaptureExport: Transferable {
    let captures: [ProxyCapture]
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType:.json) { value in
            let encoder = JSONEncoder();encoder.dateEncodingStrategy = .iso8601;encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
            return try encoder.encode(value.captures)
        }.suggestedFileName("ATS-Proxy-Captures.json")
    }
}

struct CaptureView: View {
    let monitor: ProxyMonitor
    let store: DiagnosticStore
    @State private var port = "0"
    @State private var target = "https://example.com"
    @State private var inputError: String?
    private enum Field: Hashable { case port, target }
    @FocusState private var editing: Field?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(alignment:.top,spacing:12) { SupportingIllustration(kind:.traffic);Text("Lokaler HTTP-Proxy").font(.headline) }
                    Text("Erfasst HTTP-Anfragen und leitet CONNECT-Verbindungen als TCP-Tunnel weiter. Der Proxy ist nur auf diesem Gerät erreichbar und läuft, solange ATS Diagnostic im Vordergrund ist.").font(.subheadline).foregroundStyle(.secondary)
                    VStack(alignment:.leading,spacing:6) { Text("Port · 0 wählt einen freien Port").font(.caption).foregroundStyle(.secondary);TextField("Port",text:$port).keyboardType(.numberPad).focused($editing,equals:.port).disabled(monitor.running) }
                    if let port = monitor.port { LabeledContent("Adresse",value:"127.0.0.1:\(port)").textSelection(.enabled) }
                    if monitor.running {
                        Button("Proxy stoppen",systemImage:"stop.circle",role:.destructive) { monitor.stop() }
                        if monitor.starting { ProgressView("Proxy starten…") }
                    } else {
                        Button("Proxy starten",systemImage:"play.circle") {
                            guard let value = UInt16(port) else { inputError = "Der Port muss zwischen 0 und 65.535 liegen."; return }
                            editing = nil; inputError = nil; monitor.start(port:value)
                        }.buttonStyle(.borderedProminent).controlSize(.large)
                    }
                    if let message = inputError ?? monitor.error { Text(message).foregroundStyle(.red) }
                }
                Section {
                    NavigationLink { ProxyRulesView(monitor: monitor) } label: {
                        Label("Proxy-Regeln · \(monitor.rewriteConfigurations.filter(\.enabled).count) aktiv", systemImage: "arrow.triangle.branch")
                    }
                }
                ProxyScopeSection()
                Section("Prüfanfrage durch den Proxy") {
                    TextField("HTTPS-Ziel",text:$target).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled().focused($editing,equals:.target)
                    Button("Über Proxy prüfen",systemImage:"arrow.triangle.branch") { editing = nil; Task { await monitor.check(target,options:store.diagnosticOptions) } }.disabled(monitor.port == nil || monitor.testing || target.isEmpty)
                    if monitor.testing { ProgressView("Prüfanfrage läuft…") }
                    if let result = monitor.testRecord {
                        DiagnosticIssueView(record:result)
                        NavigationLink("Ergebnis der Prüfanfrage") { RecordView(record:result,store:store) }
                        LabeledContent("HTTP-Status",value:result.status.map(String.init) ?? "Keine Antwort")
                    }
                }
                Section("Verbindungen · \(monitor.captures.count)") {
                    ForEach(monitor.captures) { capture in NavigationLink { ProxyCaptureDetail(id:capture.id,monitor:monitor) } label: { ProxyCaptureRow(capture:capture) } }
                    if monitor.captures.isEmpty { Text("Starte den Proxy und sende eine Anfrage mit einem Client, der diese Proxy-Adresse verwendet.").foregroundStyle(.secondary) }
                }
            }.navigationTitle("Erfassen").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement:.topBarTrailing) { if !monitor.captures.isEmpty { ShareLink(item:ProxyCaptureExport(captures:monitor.captures),preview:SharePreview("ATS Proxy-Erfassungen")) { Label("Erfassungen teilen",systemImage:"square.and.arrow.up") } } }
                    ToolbarItemGroup(placement:.keyboard) { if editing != nil { Spacer();Button("Fertig") { editing = nil } } }
                }
        }
    }
}
private struct ProxyScopeSection: View {
    var body: some View {
        Section("Was sichtbar ist") {
            Label("HTTP: Anfrage, Antwortstatus und begrenzte Rohdatenvorschau",systemImage:"doc.text").font(.subheadline)
            Label("CONNECT: Ziel und übertragene Bytezahlen",systemImage:"lock.shield").font(.subheadline)
            Text("Bei CONNECT prüft der Client seine TLS-Verbindung selbst. HTTPS-Inhalte und Zertifikate werden in diesem Tunnelmodus nicht entschlüsselt. Die separate Prüfanfrage zeigt die TLS-Ergebnisse ihres eigenen Clients.").font(.footnote).foregroundStyle(.secondary)
            Text("HTTP ist unverschlüsselt. Die Rohdatenvorschau kann Zugangsdaten enthalten. Bis zu acht aktive Verbindungen, 16 MiB Anfragekörper und 64 KiB Vorschau je Richtung. Der Proxy beendet Verbindungen nach 60 Sekunden ohne neue Daten oder nach einer Stunde. Erfasste Verbindungen bleiben nur in dieser App-Sitzung; ein Export wird von dir ausgelöst.").font(.footnote).foregroundStyle(.secondary)
        }
    }
}
private struct ProxyCaptureRow: View {
    let capture: ProxyCapture
    var body: some View {
        HStack(alignment:.top,spacing:12) {
            Image(systemName:capture.opaque ? "lock.shield" : "doc.text").foregroundStyle(capture.error == nil ? Color.diagnosticAccent : .orange)
            VStack(alignment:.leading,spacing:6) {
                Text(capture.target.isEmpty ? "Anfrage wird empfangen" : capture.target).font(.subheadline.weight(.semibold)).lineLimit(2)
                Text("\(capture.method) · \(capture.stateText)").font(.caption).foregroundStyle(.secondary)
                Text("↑ \(capture.sentBytes.formatted(.byteCount(style:.file))) · ↓ \(capture.receivedBytes.formatted(.byteCount(style:.file)))").font(.caption.monospaced()).foregroundStyle(.secondary)
            }
        }
    }
}
private struct ProxyCaptureDetail: View {
    let id: UUID
    let monitor: ProxyMonitor
    var body: some View {
        if let capture = monitor.captures.first(where: { $0.id == id }) { ProxyCaptureDetails(capture:capture) }
        else { ContentUnavailableView("Aufzeichnung nicht mehr vorhanden",systemImage:"network") }
    }
}
private struct ProxyCaptureDetails: View {
    let capture: ProxyCapture
    var body: some View {
        List {
            Section("Verbindung") {
                Text(capture.target).textSelection(.enabled)
                if capture.rewriteRuleApplied == true {
                    Label("Umschreibungsregel angewendet", systemImage: "arrow.triangle.branch")
                    if let original = capture.originalTarget { Text("Ursprüngliches Ziel").font(.caption).foregroundStyle(.secondary); Text(original).textSelection(.enabled) }
                }
                LabeledContent("Methode",value:capture.method)
                LabeledContent("Status",value:capture.stateText)
                if let status = capture.status { LabeledContent(capture.opaque ? "Proxy-Antwort" : "HTTP-Antwort",value:String(status)) }
                LabeledContent("An Ziel übergeben",value:capture.sentBytes.formatted(.byteCount(style:.file)))
                LabeledContent("Vom Ziel empfangen",value:capture.receivedBytes.formatted(.byteCount(style:.file)))
                LabeledContent("Dauer",value:"\(capture.duration.formatted(.number.precision(.fractionLength(2)))) s")
                if let error = capture.error { Label(error,systemImage:"exclamationmark.circle").foregroundStyle(.orange) }
            }
            if capture.opaque { Section { Text("Die Bytezahlen beziehen sich auf den weitergeleiteten TCP-Datenstrom. Sie sind keine HTTP-Inhaltsgrößen und belegen weder den Inhalt noch die Zertifikatsprüfung des Clients.").foregroundStyle(.secondary) } }
            else {
                if let errors = capture.upstreamTrustErrors { Section("Server-Zertifikatsprüfung") { DiagnosticIssueView(record:DiagnosticRecord(url:capture.target,method:capture.method,trustValid:false,trustErrors:errors)) } }
                if let tls = capture.upstreamTLS { Section("Proxy → Server") { LabeledContent("TLS",value:TLSDisplay.version(tls));LabeledContent("Cipher",value:TLSDisplay.cipher(capture.upstreamCipher)) } }
                ProxyPreviewSection(title:"Weitergeleitete Anfrage · Rohdaten",bytes:capture.requestPreview)
                ProxyPreviewSection(title:"Empfangene Antwort · Rohdaten",bytes:capture.responsePreview)
            }
        }.navigationTitle("Erfasste Verbindung").navigationBarTitleDisplayMode(.inline)
    }
}
private struct ProxyPreviewSection: View {
    let title: LocalizedStringKey
    let bytes: Data
    var body: some View {
        Section(title) {
            if bytes.isEmpty { Text("Keine Vorschau verfügbar.").foregroundStyle(.secondary) }
            else {
                let text = String(data:bytes,encoding:.utf8) ?? bytes.base64EncodedString()
                Text(String(text.prefix(600))).font(.footnote.monospaced()).lineLimit(8).textSelection(.enabled)
                NavigationLink("Ganze Vorschau öffnen") { TextValueView(title:"Rohdatenvorschau",value:text) }
                Text("Maximal 64 KiB. Die Vorschau enthält die empfangene Drahtdarstellung; HTTP-Komprimierung und Chunk-Rahmen können darin enthalten sein.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
