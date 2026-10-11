import SwiftUI
import UniformTypeIdentifiers

@main struct ATSDiagnosticApp: App {
    @State private var store = DiagnosticStore()
    var body: some Scene {
        WindowGroup { RootView(store: store) }
    }
}
struct RootView: View {
    let store: DiagnosticStore
    var body: some View {
        TabView {
            Tab("Inspect", systemImage: "checkmark.shield") { InspectView(store: store) }
            Tab("Requests", systemImage: "arrow.up.arrow.down") { RequestView(store: store) }
            Tab("History", systemImage: "clock") { HistoryView(store: store) }
            Tab("Tools", systemImage: "wrench.and.screwdriver") { ToolsView() }
        }.tint(.teal)
    }
}
struct InspectView: View {
    let store: DiagnosticStore
    @State private var host = ""
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "checkmark.shield.fill").font(.largeTitle).foregroundStyle(.teal).accessibilityHidden(true)
                        Text("Understand your connection").font(.title2.bold())
                        Text("Inspect TLS, the certificate chain and connection timings directly from your device.").foregroundStyle(.secondary)
                    }.padding(.vertical, 12)
                }
                Section("Host or URL") {
                    TextField("example.com", text: $host).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL).onSubmit { run() }
                    Button(action: run) { Label(store.running ? "Inspecting…" : "Inspect connection", systemImage: "magnifyingglass") }.disabled(store.running || host.isEmpty)
                }
                if store.running { ProgressView("Connecting…") }
                if let error = store.error { Text(error).foregroundStyle(.red) }
                if let record = store.latest ?? store.records.first { Section("Latest inspection") { NavigationLink { RecordView(record: record, store: store) } label: { RecordRow(record: record) } } }
                Section { Text("System trust validation stays enabled. A successful request describes this connection; it does not certify every ATS requirement of another app.").font(.footnote).foregroundStyle(.secondary) }
            }.navigationTitle("ATS Diagnostic")
        }
    }
    private func run() { Task { await store.execute(url: host) } }
}
struct RequestView: View {
    let store: DiagnosticStore
    @State private var url = ""
    @State private var method = "GET"
    @State private var headers = ""
    @State private var importCURL = false
    @State private var curlText = ""
    @State private var importError: String?
    @FocusState private var editing: Bool
    @State private var bodyText = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Request") {
                    TextField("https://example.com/api", text: $url).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Picker("Method", selection: $method) { ForEach(["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"], id: \.self) { Text($0) } }
                }
                Section("Headers · Name: Value") { TextEditor(text: $headers).focused($editing).font(.body.monospaced()).frame(minHeight: 100).accessibilityLabel("Request headers") }
                Section("Body") { TextEditor(text: $bodyText).focused($editing).font(.body.monospaced()).frame(minHeight: 150).accessibilityLabel("Request body") }
                Button { Task { await store.execute(url: url, method: method, headers: headers, body: bodyText) } } label: { Label("Send request", systemImage: "paperplane") }.disabled(store.running || url.isEmpty)
                if store.running { ProgressView("Sending…") }
                if let error = store.error { Text(error).foregroundStyle(.red) }
                if let record = store.latest ?? store.records.first { NavigationLink("Open latest response") { RecordView(record: record, store: store) } }
            }.scrollDismissesKeyboard(.interactively).navigationTitle("Request workspace")
            .sheet(isPresented: $importCURL) {
                NavigationStack { Form {
                    Section("Paste cURL") { TextEditor(text: $curlText).font(.body.monospaced()).frame(minHeight: 180).accessibilityLabel("cURL command") }
                    if let importError { Text(importError).foregroundStyle(.red) }
                    Button("Import request") { do { let request = try CURLImport.parse(curlText); url = request.url; method = request.method; headers = request.headers; bodyText = request.body; importError = nil; importCURL = false } catch { importError = error.localizedDescription } }
                }.navigationTitle("Import cURL").toolbar { Button("Cancel") { importCURL = false } } }
            }
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Import cURL", systemImage: "square.and.arrow.down") { importCURL = true } }; ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { editing = false } } }
        }
    }
}
struct HistoryView: View {
    let store: DiagnosticStore
    @State private var query = ""
    @State private var filtered: [DiagnosticRecord] = []
    @State private var confirmClear = false
    @State private var importHAR = false
    @State private var category = ResponseCategory.all
    @State private var favoritesOnly = false
    @State private var showSettings = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Response type", selection: $category) { ForEach(ResponseCategory.allCases) { Text($0.rawValue).tag($0) } }
                    Toggle("Favorites only", isOn: $favoritesOnly)
                    let statistics = TrafficStatistics(filtered)
                    LabeledContent("Requests", value: statistics.count.formatted())
                    LabeledContent("Response data", value: statistics.bytes.formatted(.byteCount(style: .file)))
                    LabeledContent("Average duration", value: statistics.averageDuration.formatted(.number.precision(.fractionLength(3))) + " s")
                    LabeledContent("Failures", value: statistics.failures.formatted())
                }
                ForEach(filtered) { record in NavigationLink { RecordView(record: record, store: store) } label: { RecordRow(record: record) } }
            }
                .overlay { if store.records.isEmpty { ContentUnavailableView("No connections yet", systemImage: "network", description: Text("Inspect a host or send a request to begin.")) } }
                .searchable(text: $query, prompt: "URL, method or status")
                .navigationTitle("History")
                .sheet(isPresented: $showSettings) { RecordingSettingsView(store: store) }
                .toolbar { Button("Recording settings", systemImage: "gearshape") { showSettings = true }; ShareLink(item: HARArchive(records: store.records), preview: SharePreview("Diagnostics archive")) { Label("Export HAR", systemImage: "square.and.arrow.up") }; Button("Import HAR", systemImage: "square.and.arrow.down") { importHAR = true }; Button("Clear", systemImage: "trash") { confirmClear = true }.disabled(store.records.isEmpty) }
                .confirmationDialog("Delete all local diagnostics?", isPresented: $confirmClear) { Button("Delete history", role: .destructive) { store.clear() } }
                .fileImporter(isPresented: $importHAR, allowedContentTypes: [.json, .data]) { result in do { let url = try result.get(); let accessed = url.startAccessingSecurityScopedResource(); defer { if accessed { url.stopAccessingSecurityScopedResource() } }; try store.importHAR(Data(contentsOf: url)) } catch { store.error = error.localizedDescription } }
                .onChange(of: query, initial: true) { refresh() }
                .onChange(of: store.records.count) { refresh() }
                .onChange(of: category) { refresh() }
                .onChange(of: favoritesOnly) { refresh() }
                .onChange(of: store.settings.favorites) { refresh() }
        }
    }
    private func refresh() { filtered = store.records.filter { (query.isEmpty || "\($0.url) \($0.method) \($0.status ?? 0)".localizedCaseInsensitiveContains(query)) && category.matches($0) && (!favoritesOnly || store.settings.favorites.contains($0.id)) } }
}
struct RecordRow: View {
    let record: DiagnosticRecord
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(record.url).font(.headline).lineLimit(2)
            Label("\(record.method) · \(record.status.map(String.init) ?? "Failed")", systemImage: record.error == nil ? "checkmark.circle" : "exclamationmark.triangle").foregroundStyle(record.error == nil ? Color.secondary : Color.red)
            Text(record.date, format: .dateTime.month().day().hour().minute()).font(.caption).foregroundStyle(.secondary)
        }.padding(.vertical, 4)
    }
}
struct RecordView: View {
    let record: DiagnosticRecord
    let store: DiagnosticStore
    var body: some View {
        List {
            Section("Connection") {
                Text(record.url).textSelection(.enabled)
                LabeledContent("Status", value: record.status.map(String.init) ?? "Failed")
                LabeledContent("Protocol", value: record.protocolName ?? "Not reported")
                LabeledContent("TLS version", value: record.tlsVersion ?? "Not reported")
                LabeledContent("Cipher suite", value: record.cipher ?? "Not reported")
                LabeledContent("Remote address", value: record.remoteAddress ?? "Not reported")
                if let error = record.error { Text(error).foregroundStyle(.red) }
            }
            Section("Timings") {
                LabeledContent("Total", value: record.duration.formatted(.number.precision(.fractionLength(3))) + " s")
                if let d = record.dnsDuration { LabeledContent("DNS", value: d.formatted() + " s") }
                if let d = record.connectDuration { LabeledContent("Connect", value: d.formatted() + " s") }
                if let d = record.tlsDuration { LabeledContent("TLS handshake", value: d.formatted() + " s") }
                LabeledContent("Response size", value: record.bytes.formatted(.byteCount(style: .file)))
            }
            Section("Certificate chain") {
                if let valid = record.trustValid { Label(valid ? "Trusted by the system" : "Trust validation failed", systemImage: valid ? "checkmark.shield" : "exclamationmark.shield") }
                if let message = record.trustMessage { Text(message) }
                ForEach(record.certificates) { certificate in
                    DisclosureGroup(certificate.subject) { Text("SHA-256").font(.caption); Text(certificate.id).font(.body.monospaced()).textSelection(.enabled); if let keyDetails = CertificateAnalysis.publicKeyDetails(certificate.der) { Text(keyDetails) }; ForEach(CertificateAnalysis.findings(certificate)) { finding in VStack(alignment: .leading) { Label(finding.title, systemImage: "exclamationmark.triangle").foregroundStyle(.orange); Text(finding.detail) } }; ForEach((try? X509.fields(certificate.der)) ?? []) { field in VStack(alignment: .leading) { Text(field.name).font(.caption).foregroundStyle(.secondary); Text(field.value).textSelection(.enabled) } }; ShareLink("Export DER", item: CertificateExport(certificate: certificate), preview: SharePreview(certificate.subject)) }
                }
            }
            Section("Response headers") { Text(record.responseHeaders.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: "\n")).font(.body.monospaced()).textSelection(.enabled) }
            Section("Response body · up to 2 MB") { Text(record.responseBody).font(.body.monospaced()).textSelection(.enabled) }
            Section {
                ShareLink("Copy or share as cURL", item: record.curl)
                Button("Replay request") { Task { await store.execute(url: record.url, method: record.method, headers: record.requestHeaders.map { "\($0.key): \($0.value)" }.joined(separator: "\n"), body: record.requestBody) } }.disabled(store.running)
            }
        }.navigationTitle("Connection details").navigationBarTitleDisplayMode(.inline).toolbar { Button("Favorite", systemImage: store.settings.favorites.contains(record.id) ? "star.fill" : "star") { store.toggleFavorite(record.id) } }
    }
}
