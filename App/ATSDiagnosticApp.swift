import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

@main struct ATSDiagnosticApp: App {
    @State private var store = DiagnosticStore()
    @State private var proxy = ProxyMonitor()
    @Environment(\.scenePhase) private var scenePhase
    private let notificationDelegate = CertificateNotificationDelegate()
    init() { UNUserNotificationCenter.current().delegate = notificationDelegate }
    var body: some Scene {
        WindowGroup { RootView(store: store,proxy:proxy).onChange(of:scenePhase) { if scenePhase == .background { proxy.stop(reason:"Der Proxy wurde beim Wechsel in den Hintergrund gestoppt."); Task { await store.flushHistory(); await proxy.flushRules() } } } }
    }
}
struct RootView: View {
    let store: DiagnosticStore
    let proxy: ProxyMonitor
    var body: some View {
        TabView {
            Tab("Inspect", systemImage: "checkmark.shield") { InspectView(store: store) }
            Tab("Requests", systemImage: "arrow.up.arrow.down") { RequestView(store: store) }
            Tab("Erfassen", systemImage: "network") { CaptureView(monitor:proxy,store:store) }
            Tab("History", systemImage: "clock") { HistoryView(store: store) }
            Tab("Tools", systemImage: "wrench.and.screwdriver") { ToolsView(store:store) }
        }.tint(Color.diagnosticAccent).background(KeyboardDismissSurface())
    }
}
struct InspectView: View {
    let store: DiagnosticStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var host = ""
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if geometry.size.width >= 900 && !dynamicTypeSize.isAccessibilitySize {
                    ScrollView {
                        HStack(alignment: .top, spacing: 24) {
                            VStack(spacing: 20) {
                                DiagnosticPanel(title: "Inspect a connection", illustration: .server) { InspectionHero(record: store.latest ?? store.records.first); inspectionInput }
                            }.frame(width: 340)
                            VStack(spacing: 20) {
                                if let record = store.latest ?? store.records.first {
                                    DiagnosticPanel(title: "Latest inspection", illustration: .traffic) {
                                        ConnectionOverview(record: record)
                                        DiagnosticIssueView(record:record)
                                        ConnectionTimingChart(record: record)
                                        NavigationLink { RecordView(record: record, store: store) } label: { RecordRow(record: record) }
                                    }
                                } else {
                                    DiagnosticPanel(title: "Connection overview", illustration: .traffic) { ContentUnavailableView("Ready to inspect", systemImage: "network", description: Text("Enter a hostname to see certificates, security and timings.")) }
                                }
                                DiagnosticPanel(title: "System trust", illustration: .certificate) { trustExplanation }
                            }.frame(maxWidth: 760)
                        }.padding(24).frame(maxWidth: .infinity)
                    }.background(Color(uiColor: .systemGroupedBackground))
                } else {
                    List {
                        Section { InspectionHero(record: store.latest ?? store.records.first) }
                        Section("Host or URL") { inspectionInput }
                        if let record = store.latest ?? store.records.first { Section("Latest inspection") { ConnectionOverview(record: record); DiagnosticIssueView(record:record); NavigationLink { RecordView(record: record, store: store) } label: { RecordRow(record: record) } } }
                        Section { trustExplanation }
                    }
                }
            }.navigationTitle("ATS Diagnostic").navigationBarTitleDisplayMode(.inline)
        }
    }
    private var inspectionInput: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("example.com", text: $host).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL).onSubmit { run() }.textFieldStyle(.roundedBorder)
            Button(action: run) { Label(store.running ? "Inspecting…" : "Inspect connection", systemImage: "magnifyingglass").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).controlSize(.large).disabled(store.running || host.isEmpty)
            if store.running { ProgressView("Connecting…") }
            if let error = store.error { Text(error).foregroundStyle(.red) }
        }
    }
    private var trustExplanation: some View { Text("Systemvertrauen wird weiterhin geprüft. Für die Diagnose fremder Server sind HTTP und ältere TLS-Konfigurationen zugelassen. Ein erfolgreicher Aufruf bestätigt deshalb keine ATS-Konformität.").font(.footnote).foregroundStyle(.secondary) }
    private func run() { Task { await store.execute(url: host) } }
}
struct RequestDraft {
    let url: String
    let method: String
    let headers: String
    let body: String
    init(record: DiagnosticRecord) {
        url = record.url; method = record.method
        headers = record.requestHeaders.keys.sorted().map { "\($0): \(record.requestHeaders[$0] ?? "")" }.joined(separator: "\n")
        body = record.requestBody
    }
}
struct RequestView: View {
    let store: DiagnosticStore
    private let isEditedCopy: Bool
    @Environment(\.dismiss) private var dismiss
    init(store: DiagnosticStore, draft: RequestDraft? = nil) {
        self.store = store; isEditedCopy = draft != nil
        _url = State(initialValue: draft?.url ?? "")
        _method = State(initialValue: draft?.method ?? "GET")
        _headers = State(initialValue: draft?.headers ?? "")
        _bodyText = State(initialValue: draft?.body ?? "")
        _headerExpanded = State(initialValue: !(draft?.headers.isEmpty ?? true))
        _bodyExpanded = State(initialValue: !(draft?.body.isEmpty ?? true))
    }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var url = ""
    @State private var method = "GET"
    @State private var headers = ""
    @State private var importCURL = false
    @State private var curlText = ""
    @State private var importError: String?
    @FocusState private var editing: Bool
    @State private var bodyText = ""
    @State private var expectedSHA256 = ""
    @State private var headerExpanded = false
    @State private var bodyExpanded = false
    @State private var integrityExpanded = false
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if geometry.size.width >= 900 && !dynamicTypeSize.isAccessibilitySize {
                    HStack(alignment: .top, spacing: 24) {
                        requestForm(showLatest: false).frame(width: 460)
                        ScrollView {
                            if let record = store.latest ?? store.records.first {
                                DiagnosticPanel(title: "Latest response", illustration: .traffic) {
                                    RecordRow(record: record)
                                    ConnectionOverview(record: record)
                                    Text(String(record.responseBody.prefix(1200))).font(.callout.monospaced()).textSelection(.enabled)
                                    NavigationLink("Open full response") { RecordView(record: record, store: store) }
                                }
                            } else {
                                DiagnosticPanel(title: "Response workspace", illustration: .traffic) { Text("Send a request to inspect headers, body, certificates and timings.").foregroundStyle(.secondary) }
                            }
                        }.frame(maxWidth: 660)
                    }.padding(24).frame(maxWidth: .infinity).background(Color(uiColor: .systemGroupedBackground))
                } else { requestForm(showLatest: true) }
            }.scrollDismissesKeyboard(.interactively).navigationTitle("Requests").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $importCURL) {
                NavigationStack { Form {
                    Section("Paste cURL") { TextEditor(text: $curlText).font(.body.monospaced()).frame(minHeight: 180).accessibilityLabel("cURL command") }
                    if let importError { Text(importError).foregroundStyle(.red) }
                    Button("Import request") { do { let request = try CURLImport.parse(curlText); url = request.url; method = request.method; headers = request.headers; bodyText = request.body; importError = nil; importCURL = false } catch { importError = error.localizedDescription } }
                }.navigationTitle("Import cURL").toolbar { Button("Cancel") { importCURL = false } } }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { if isEditedCopy { Button("Schließen") { dismiss() } } }; ToolbarItem(placement: .topBarTrailing) { Button("Import cURL", systemImage: "square.and.arrow.down") { importCURL = true } }; ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editing = false } } }
        }
    }
    private func requestForm(showLatest: Bool) -> some View {
        Form {
                if isEditedCopy { Text("Du bearbeitest eine Kopie. Erst „Send request“ sendet sie; die ursprüngliche Aufzeichnung bleibt erhalten.").font(.footnote).foregroundStyle(.secondary) }
                Section("Request") {
                    TextField("https://example.com/api", text: $url).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Picker("Method", selection: $method) { ForEach(["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"], id: \.self) { Text($0) } }
                }
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        SupportingIllustration(kind: .traffic)
                        Text("Send an HTTP request and inspect the server’s response. For a simple GET request, the URL is enough.").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Section("Optional request fields") {
                    DisclosureGroup(isExpanded: $headerExpanded) {
                        Text("One header per line, for example Accept: application/json.").font(.footnote).foregroundStyle(.secondary)
                        TextEditor(text: $headers).focused($editing).font(.callout.monospaced()).frame(height: 110).accessibilityLabel("Request headers")
                    } label: { Label(headers.isEmpty ? "Headers" : "Headers · configured", systemImage: "list.bullet.rectangle") }
                    DisclosureGroup(isExpanded: $bodyExpanded) {
                        Text("The payload sent with this request, usually for POST, PUT or PATCH.").font(.footnote).foregroundStyle(.secondary)
                        TextEditor(text: $bodyText).focused($editing).font(.callout.monospaced()).frame(height: 150).accessibilityLabel("Request body")
                    } label: { Label(bodyText.isEmpty ? "Body" : "Body · configured", systemImage: "doc.text") }
                    DisclosureGroup(isExpanded: $integrityExpanded) {
                        Text("Paste a known SHA-256 checksum to compare it with the complete downloaded response.").font(.footnote).foregroundStyle(.secondary)
                        TextField("Expected SHA-256 checksum", text: $expectedSHA256).textInputAutocapitalization(.never).autocorrectionDisabled().font(.callout.monospaced())
                    } label: { Label(expectedSHA256.isEmpty ? "Verify download checksum" : "Checksum · configured", systemImage: "checkmark.shield") }
                }
                Button { Task { await store.execute(url: url, method: method, headers: headers, body: bodyText, expectedSHA256: expectedSHA256) } } label: { Label("Send request", systemImage: "paperplane").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).controlSize(.large).disabled(store.running || url.isEmpty)
                if store.running { ProgressView("Sending…") }
                if let error = store.error { Text(error).foregroundStyle(.red) }
                if showLatest, let record = store.latest ?? store.records.first { NavigationLink("Open latest response") { RecordView(record: record, store: store) } }

        }.scrollContentBackground(.hidden).background(Color(uiColor: .systemGroupedBackground))
    }

}
struct HistoryView: View {
    let store: DiagnosticStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var query = ""
    @State private var filtered: [DiagnosticRecord] = []
    @State private var confirmClear = false
    @State private var importHAR = false
    @State private var category = ResponseCategory.all
    @State private var favoritesOnly = false
    @State private var showSettings = false
    private var emptyHistory: some View {
        ContentUnavailableView("No connections yet", systemImage: "network", description: Text("Inspect a host or send a request to begin."))
    }
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if geometry.size.width >= 900 && !dynamicTypeSize.isAccessibilitySize {
                    HStack(alignment: .top, spacing: 24) {
                        ScrollView {
                            DiagnosticPanel(title: "Traffic overview", illustration: .traffic) { filters; TrafficOverview(statistics: TrafficStatistics(filtered)) }
                        }.frame(width: 340)
                        List {
                            ForEach(filtered) { record in NavigationLink { RecordView(record: record, store: store) } label: { RecordRow(record: record) } }
                            if store.loadingHistory { ProgressView("Verlauf wird geladen…") }
                            else if store.records.isEmpty { emptyHistory.listRowBackground(Color.clear).listRowSeparator(.hidden) }
                        }.scrollContentBackground(.hidden).background(Color(uiColor: .systemGroupedBackground)).frame(maxWidth: 760)
                    }.padding(24).frame(maxWidth: .infinity).background(Color(uiColor: .systemGroupedBackground))
                } else {
                    List {
                        Section { filters; TrafficOverview(statistics: TrafficStatistics(filtered)) }
                        if store.loadingHistory { Section { ProgressView("Verlauf wird geladen…") } }
                        else if store.records.isEmpty { Section { emptyHistory }.listRowBackground(Color.clear) }
                        ForEach(filtered) { record in NavigationLink { RecordView(record: record, store: store) } label: { RecordRow(record: record) } }
                    }
                }
            }

                .searchable(text: $query, prompt: "URL, method or status")
                .navigationTitle("History")
                .sheet(isPresented: $showSettings) { RecordingSettingsView(store: store) }
                .toolbar { ShareLink(item: DiagnosticLogExport(records: store.records), preview: SharePreview("Diagnostic log")) { Label("Export log", systemImage: "doc.text") }; Button("Recording settings", systemImage: "gearshape") { showSettings = true }; ShareLink(item: HARArchive(records: store.records), preview: SharePreview("Diagnostics archive")) { Label("Export HAR", systemImage: "square.and.arrow.up") }; Button("Import HAR", systemImage: "square.and.arrow.down") { importHAR = true }; Button("Clear", systemImage: "trash") { confirmClear = true }.disabled(store.records.isEmpty) }
                .confirmationDialog("Delete all local diagnostics?", isPresented: $confirmClear) { Button("Delete history", role: .destructive) { Task { await store.clear() } } }
                .fileImporter(isPresented: $importHAR, allowedContentTypes: [.json, .data]) { result in Task { do { let url = try result.get(); let accessed = url.startAccessingSecurityScopedResource(); defer { if accessed { url.stopAccessingSecurityScopedResource() } }; try await store.importHAR(Data(contentsOf: url)) } catch { store.error = error.localizedDescription } } }
                .onChange(of: query, initial: true) { refresh() }
                .onChange(of: store.records.map(\.id)) { refresh() }
                .onChange(of: category) { refresh() }
                .onChange(of: favoritesOnly) { refresh() }
                .onChange(of: store.settings.favorites) { refresh() }
        }
    }
    private var filters: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Response type", selection: $category) { ForEach(ResponseCategory.allCases) { Text($0.rawValue).tag($0) } }
            Toggle("Favorites only", isOn: $favoritesOnly)
        }
    }
    private func refresh() { filtered = store.records.filter { (query.isEmpty || "\($0.url) \($0.method) \($0.status ?? 0)".localizedCaseInsensitiveContains(query)) && category.matches($0) && (!favoritesOnly || store.settings.favorites.contains($0.id)) } }
}
struct RecordRow: View {
    let record: DiagnosticRecord
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SupportingIllustration(kind: .traffic)
            VStack(alignment: .leading, spacing: 6) {
            Text(record.url).font(.headline).lineLimit(2)
            Label("\(record.method) · \(record.status.map(String.init) ?? "Failed")", systemImage: record.error == nil ? "checkmark.circle" : "exclamationmark.triangle").foregroundStyle(record.error == nil ? Color.secondary : Color.red)
            if record.importedResponseComplete == false && (record.status != nil || record.importedObservedResponseBytes != nil) { Label("Teilaufnahme", systemImage: "doc.text").font(.caption).foregroundStyle(.secondary) }
            Text(record.date, format: .dateTime.month().day().hour().minute()).font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 4)
    }
}
struct RecordView: View {
    @State private var editRequest = false
    @State private var additionalRevocation: RevocationAssessment?
    private var displayedRecord: DiagnosticRecord { var value = record;if let additionalRevocation { value.revocationAssessment = additionalRevocation };return value }
        let record: DiagnosticRecord
    let store: DiagnosticStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width >= 900 && !dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .top, spacing: 24) {
                    ScrollView {
                        VStack(spacing: 20) {
                            DiagnosticPanel(title: "Connection overview", illustration: .traffic) { ConnectionOverview(record: record); DiagnosticIssueView(record:displayedRecord) }
                            DiagnosticPanel(title: "Measured timings", illustration: .timing) { ConnectionTimingChart(record: record) }
                        }
                    }.frame(width: 360)
                    detailList(includeOverview: false).frame(maxWidth: 760)
                }.padding(24).frame(maxWidth: .infinity).background(Color(uiColor: .systemGroupedBackground))
            } else { detailList(includeOverview: true) }
        }.sheet(isPresented: $editRequest) { RequestView(store: store, draft: RequestDraft(record: record)) }
        .navigationTitle("Connection details").navigationBarTitleDisplayMode(.inline).toolbar { Button("Favorite", systemImage: store.settings.favorites.contains(record.id) ? "star.fill" : "star") { store.toggleFavorite(record.id) } }
    }
    private var checksumExplanation: LocalizedStringKey { record.origin == nil ? "SHA-256 of the complete received response" : "SHA-256 laut importierter Aufzeichnung · nicht neu geprüft" }
    private func detailList(includeOverview: Bool) -> some View {
        List {
            if let origin = record.origin { ImportedRecordSection(origin: origin, requestBodyUnavailable: record.requestBodyUnavailable == true, requestPreview: record.importedRequestBodyPreview, requestBytes: record.importedRequestBodyBytes, requestFormatError: record.requestFormatError) }
            if includeOverview { Section { ConnectionOverview(record: record); DiagnosticIssueView(record:displayedRecord) } }
            Section { NavigationLink { ConnectionMapView(record: record) } label: { Label("Connection map", systemImage: "point.3.connected.trianglepath.dotted") } }
            Section("Connection") {
                Text(record.url).textSelection(.enabled)
                if let finalURL = record.finalURL, finalURL != record.url { LabeledContent("Final destination", value: finalURL).textSelection(.enabled) }
                LabeledContent("Status", value: record.status.map(String.init) ?? "Failed")
                LabeledContent("Protocol", value: record.protocolName.flatMap { $0.isEmpty ? nil : $0 } ?? "Not reported")
                LabeledContent("TLS version", value: TLSDisplay.version(record.tlsVersion))
                LabeledContent("Cipher suite", value: TLSDisplay.cipher(record.cipher))
                LabeledContent("Remote address", value: record.remoteAddress ?? "Not reported")
                if let error = record.error { Text(error).foregroundStyle(.red) }
            }
            QueryParameterLinks(requestedURL: record.url, finalURL: record.finalURL)
            if let options = record.diagnosticOptions { DiagnosticOptionsSummary(options:options) }
            if let checksum = record.responseSHA256 {
                Section("Download integrity") {
                    Text(checksumExplanation).font(.caption).foregroundStyle(.secondary)
                    Text(Integrity.groupedDigest(checksum)).font(.body.monospaced()).textSelection(.enabled)
                    if let matches = record.integrityMatches { Label(matches ? "Checksum matches" : "Checksum mismatch", systemImage: matches ? "checkmark.shield" : "exclamationmark.shield").foregroundStyle(matches ? Color.diagnosticAccent : Color.red) }
                }
            }
            if record.connectionMetrics != nil { Section { NavigationLink { ConnectionMetricsView(record:record) } label: { Label("Weiterleitungen und Verbindungsweg",systemImage:"point.3.connected.trianglepath.dotted") } } }
            Section("Timings") {
                if includeOverview { ConnectionTimingChart(record: record) }
                LabeledContent("Total", value: record.duration.formatted(.number.precision(.fractionLength(3))) + " s")
                if let d = record.dnsDuration { LabeledContent("DNS", value: d.formatted() + " s") }
                if let d = record.connectDuration { LabeledContent("Connect", value: d.formatted() + " s") }
                if let d = record.tlsDuration { LabeledContent("TLS handshake", value: d.formatted() + " s") }
                LabeledContent("Response size", value: record.responseByteCountKnown == false ? "Unbekannt" : record.bytes.formatted(.byteCount(style: .file)))
            }
            Section {
                ConnectionSecuritySummary(record: record)
                ForEach(record.certificates) { certificate in
                    NavigationLink { CertificateDetailView(certificate: certificate, isLeaf: certificate.id == record.certificates.first?.id, systemCT: record.certificateTransparency, issuerCertificate: record.certificates.nextIssuer(after:certificate)) } label: {
                        HStack(alignment: .top, spacing: 12) {
                            SupportingIllustration(kind: .certificate)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(certificate.subject).font(.subheadline.weight(.semibold)).lineLimit(2)
                                Text(certificate.id == record.certificates.first?.id ? "Server certificate" : "Certificate authority").font(.caption).foregroundStyle(.secondary)
                                if let expiry = certificate.expiryDate { Text("Expires \(expiry.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary) }
                            }
                        }.padding(.vertical, 4)
                    }
                }
                if !record.certificates.isEmpty { ShareLink("Export complete chain as PEM", item: CertificateChainExport(certificates: record.certificates), preview: SharePreview("Certificate chain")) }
            } header: { Text("Certificates & trust") }
            Section { NavigationLink("TLS-Versionen dieses Servers prüfen") { TLSVersionProbeView(host: record.finalURL ?? record.url) } }
            RevocationView(record:record,assessment:$additionalRevocation)
            Section("Response headers · \(record.responseHeaders.count)") {
                ForEach(record.responseHeaders.keys.sorted().prefix(3), id: \.self) { key in HeaderRow(item: HeaderItem(name: key, value: record.responseHeaders[key] ?? "")) }
                NavigationLink("All headers") { HeadersView(headers: record.responseHeaders) }
                NavigationLink { HSTSPolicyView(record: record) } label: { Label("HSTS verstehen", systemImage: "shield.lefthalf.filled") }
            }
            ResponseBodySection(body: record.responseBody, encoding: record.responseEncoding, bytes: record.bytes, previewLimit: record.diagnosticOptions?.bodyPreviewBytes, hasCompleteHash: record.origin == nil && record.responseSHA256 != nil, byteCountKnown: record.responseByteCountKnown != false, incomplete: record.importedResponseComplete == false && (record.status != nil || record.importedObservedResponseBytes != nil), observedBytes: record.importedObservedResponseBytes)
            Section {
                ShareLink("Copy or share as cURL", item: record.curl).disabled(!record.canReplay)
                Button("Kopie vor dem Senden bearbeiten", systemImage: "square.and.pencil") { editRequest = true }.disabled(!record.canReplay)
                Button("Replay request") { Task { await store.execute(url: record.url, method: record.method, headers: record.requestHeaders.map { "\($0.key): \($0.value)" }.joined(separator: "\n"), body: record.requestBody) } }.disabled(store.running || !record.canReplay)
            }
        }.scrollContentBackground(.hidden).background(Color(uiColor: .systemGroupedBackground))
    }
}

private struct ResponseBodySection: View {
    let bodyText: String
    let encoding: String?
    let bytes: Int
    let previewLimit: Int?
    let hasCompleteHash: Bool
    let byteCountKnown: Bool
    let incomplete: Bool
    let observedBytes: Int?
    init(body: String, encoding: String?, bytes: Int, previewLimit: Int?, hasCompleteHash: Bool, byteCountKnown: Bool, incomplete: Bool, observedBytes: Int?) {
        bodyText = body; self.encoding = encoding; self.bytes = bytes; self.previewLimit = previewLimit; self.hasCompleteHash = hasCompleteHash; self.byteCountKnown = byteCountKnown; self.incomplete = incomplete; self.observedBytes = observedBytes
    }
    var body: some View {
        Section("Antwortdaten") {
            if incomplete {
                Label("Unvollständige Antwortaufzeichnung", systemImage: "doc.text").font(.headline)
                LabeledContent("Gesamtgröße", value: "Unbekannt")
                if let observedBytes { LabeledContent("Laut Export aufgezeichnet", value: observedBytes.formatted(.byteCount(style: .file))) }
                Text("Die Aufzeichnung endete vor dem vollständigen Lesen der Antwort. Der HTTP-Status allein bestätigt keine vollständige Antwort; ein vollständiger Hash wird nicht ausgewiesen.").font(.footnote).foregroundStyle(.secondary)
            } else {
                LabeledContent("Empfangen", value: byteCountKnown ? bytes.formatted(.byteCount(style: .file)) : "Nicht gemeldet")
            }
            if bodyText.isEmpty {
                Text(!byteCountKnown ? "Der Import enthält keine verlässlich gemeldete Antwortgröße." : bytes > 0 ? "Antwortdaten empfangen; keine Textvorschau gespeichert." : "Keine Antwortdaten empfangen.").foregroundStyle(.secondary)
            } else {
                Text(String(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(600))).font(.footnote.monospaced()).lineLimit(8).foregroundStyle(.secondary)
                NavigationLink(encoding == "base64" ? "Base64-Vorschau öffnen" : "Antwortvorschau öffnen") { TextValueView(title: "Antwortvorschau", value: bodyText) }
            }
            if let previewLimit { Text("Vorschau bis zu \(previewLimit.formatted(.byteCount(style: .memory))).").font(.caption).foregroundStyle(.secondary) }
            if hasCompleteHash { Text("SHA-256 bezieht sich auf die vollständig empfangene Antwort.").font(.caption).foregroundStyle(.secondary) }
        }
    }
}
